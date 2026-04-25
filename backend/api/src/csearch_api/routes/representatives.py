from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request

router = APIRouter()


@router.get("/representatives/{zipcode}")
async def representatives_by_zip(request: Request, zipcode: str):
    return await _representatives_by_zip(request, zipcode)


@router.get("/representatives")
async def representatives_by_zip_query(request: Request, zip: str):
    return await _representatives_by_zip(request, zip)


async def _representatives_by_zip(request: Request, zipcode: str):
    """Return senators and house members for a given ZIP code."""
    if not zipcode.isdigit() or len(zipcode) != 5:
        raise HTTPException(status_code=400, detail={"error": "ZIP code must be exactly 5 digits"})

    cache_key = f"representatives_{zipcode}"
    cached = await request.app.state.cache.get(cache_key)
    if cached is not None:
        request.state.cache_header = "HIT"
        return cached

    districts = await request.app.state.db.fetch(
        """
        SELECT state_abbr, cd
        FROM zip_districts
        WHERE zcta = $1
        ORDER BY state_abbr, cd
        """,
        zipcode,
    )

    if not districts:
        raise HTTPException(status_code=404, detail={"error": "No congressional districts found for this ZIP code"})

    district_rows = [{"state": row["state_abbr"], "district": row["cd"]} for row in districts]

    current_congress = await request.app.state.db.fetchval(
        "SELECT MAX(congress) FROM bills"
    ) or 0

    senators = await request.app.state.db.fetch(
        """
        SELECT DISTINCT ON (b.sponsor_bioguide_id)
            b.sponsor_bioguide_id AS bioguide_id,
            b.sponsor_name AS name,
            b.sponsor_party AS party,
            b.sponsor_state AS state,
            'senate' AS chamber,
            NULL::int AS district
        FROM bills b
        JOIN (
            SELECT DISTINCT state_abbr
            FROM zip_districts
            WHERE zcta = $1
        ) zd ON zd.state_abbr = b.sponsor_state
        WHERE b.congress = $2
          AND b.origin_chamber = 'Senate'
          AND b.sponsor_bioguide_id IS NOT NULL
        ORDER BY b.sponsor_bioguide_id, b.latest_action_date DESC NULLS LAST, b.sponsor_name
        """,
        zipcode,
        current_congress,
    )

    house_members = await request.app.state.db.fetch(
        """
        WITH zip_districts_for_zip AS (
            SELECT DISTINCT state_abbr, cd
            FROM zip_districts
            WHERE zcta = $1
        ),
        current_house_sponsors AS (
            SELECT DISTINCT ON (b.sponsor_bioguide_id)
                b.sponsor_bioguide_id AS bioguide_id,
                b.sponsor_name AS name,
                b.sponsor_party AS party,
                b.sponsor_state AS state,
                ((regexp_match(b.sponsor_name, '\\[([A-Z])-([A-Z]{2})-([0-9]+)\\]'))[3])::int AS district,
                b.latest_action_date
            FROM bills b
            WHERE b.congress = $2
              AND b.origin_chamber = 'House'
              AND b.sponsor_bioguide_id IS NOT NULL
              AND b.sponsor_name ~ '\\[[A-Z]-[A-Z]{2}-[0-9]+\\]'
            ORDER BY b.sponsor_bioguide_id, b.latest_action_date DESC NULLS LAST, b.sponsor_name
        )
        SELECT
            chs.bioguide_id,
            chs.name,
            chs.party,
            chs.state,
            'house' AS chamber,
            chs.district
        FROM current_house_sponsors chs
        JOIN zip_districts_for_zip zd
          ON zd.state_abbr = chs.state
         AND zd.cd = chs.district
        ORDER BY chs.state, chs.district, chs.name
        """,
        zipcode,
        current_congress,
    )

    formatted_house_members = [_format_member(row) for row in house_members]

    response = {
        "zip": zipcode,
        "zipcode": zipcode,
        "districts": district_rows,
        "senators": [_format_member(row) for row in senators],
        "housemembers": formatted_house_members,
        "representatives": formatted_house_members,
    }
    await request.app.state.cache.set(cache_key, response)
    request.state.cache_header = "MISS"
    return response


def _format_member(row):
    member = dict(row)
    member["name"] = _format_member_name(member["name"])
    return member


def _format_member_name(name: str | None) -> str:
    if not name:
        return ""

    base = name.split("[", 1)[0].strip()
    for prefix in ("Rep. ", "Sen. "):
        if base.startswith(prefix):
            base = base[len(prefix):]
            break

    if "," not in base:
        return base

    last, first = [part.strip() for part in base.split(",", 1)]
    return f"{first} {last}".strip()
