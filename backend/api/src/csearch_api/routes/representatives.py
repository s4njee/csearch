from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request

router = APIRouter()


@router.get("/representatives")
async def representatives_by_zip(request: Request, zip: str):
    """Return senators and house members for a given ZIP code.

    Uses zip_districts to resolve state(s) and district(s), then looks up
    current members from vote_members joined against recent bill sponsorship
    to identify who is actively serving.
    """
    if not zip.isdigit() or len(zip) != 5:
        raise HTTPException(status_code=400, detail={"error": "ZIP code must be exactly 5 digits"})

    # Resolve congressional districts for this ZIP
    districts = await request.app.state.db.fetch(
        """
        SELECT state_abbr, cd
        FROM zip_districts
        WHERE zcta = $1
        ORDER BY state_abbr, cd
        """,
        zip,
    )

    if not districts:
        raise HTTPException(status_code=404, detail={"error": "No congressional districts found for this ZIP code"})

    states = list({d["state_abbr"] for d in districts})

    # Current congress floor: look back 2 congresses to catch recently elected members
    current_congress_floor = await request.app.state.db.fetchval(
        "SELECT MAX(congress) - 1 FROM bills"
    )

    # Senators: members who have sponsored Senate bills from this state recently
    senators = await request.app.state.db.fetch(
        """
        SELECT DISTINCT ON (vm.bioguide_id)
            vm.bioguide_id,
            vm.display_name AS name,
            vm.party,
            vm.state,
            'senate' AS chamber,
            NULL::int AS district
        FROM vote_members vm
        WHERE vm.state = ANY($1::text[])
          AND EXISTS (
              SELECT 1 FROM bills b
              WHERE b.sponsor_bioguide_id = vm.bioguide_id
                AND b.origin_chamber = 'Senate'
                AND b.congress >= $2
          )
        ORDER BY vm.bioguide_id, vm.display_name
        """,
        states,
        current_congress_floor,
    )

    # House members: members who have sponsored House bills from this state recently.
    # We don't store district numbers on members, so we return all house members
    # for the state(s) and let the client filter by the known districts.
    house_members = await request.app.state.db.fetch(
        """
        SELECT DISTINCT ON (vm.bioguide_id)
            vm.bioguide_id,
            vm.display_name AS name,
            vm.party,
            vm.state,
            'house' AS chamber,
            NULL::int AS district
        FROM vote_members vm
        WHERE vm.state = ANY($1::text[])
          AND EXISTS (
              SELECT 1 FROM bills b
              WHERE b.sponsor_bioguide_id = vm.bioguide_id
                AND b.origin_chamber = 'House'
                AND b.congress >= $2
          )
        ORDER BY vm.bioguide_id, vm.display_name
        """,
        states,
        current_congress_floor,
    )

    return {
        "zip": zip,
        "districts": districts,
        "senators": senators,
        "housemembers": house_members,
    }
