from __future__ import annotations

import asyncio
import re

from fastapi import APIRouter, HTTPException, Request

router = APIRouter()

_ZIP_RE = re.compile(r"^\d{5}$")

_DISTRICTS_SQL = """
    SELECT state_abbr, cd
    FROM zip_districts
    WHERE zcta = $1
    ORDER BY state_abbr, cd
"""

_MEMBERS_FOR_DISTRICT_SQL = """
    SELECT DISTINCT ON (vm.bioguide_id)
        vm.bioguide_id,
        vm.display_name AS name,
        vm.party,
        vm.state,
        v.chamber
    FROM vote_members vm
    JOIN votes v ON vm.voteid = v.voteid
    WHERE vm.state = $1
      AND v.chamber = 'h'
      AND v.congress = (SELECT MAX(congress) FROM votes WHERE chamber = 'h')
      AND EXISTS (
          SELECT 1 FROM bills
          WHERE sponsor_bioguide_id = vm.bioguide_id
            AND sponsor_state = $1
            AND congress = (SELECT MAX(congress) FROM votes WHERE chamber = 'h')
        )
    ORDER BY vm.bioguide_id, v.votedate DESC
"""

# Simpler: get house members for a state+district from vote_members.
# vote_members doesn't store district, so we get all house members for the state
# and rely on the zip_districts table to narrow it down on the client side.
# For senators, we just get both senators for the state.
_SENATORS_SQL = """
    SELECT DISTINCT ON (vm.bioguide_id)
        vm.bioguide_id,
        vm.display_name AS name,
        vm.party,
        vm.state
    FROM vote_members vm
    JOIN votes v ON vm.voteid = v.voteid
    WHERE vm.state = $1
      AND v.chamber = 's'
      AND v.congress = (SELECT MAX(congress) FROM votes WHERE chamber = 's')
    ORDER BY vm.bioguide_id, v.votedate DESC
"""

_HOUSE_MEMBERS_SQL = """
    SELECT DISTINCT ON (vm.bioguide_id)
        vm.bioguide_id,
        vm.display_name AS name,
        vm.party,
        vm.state
    FROM vote_members vm
    JOIN votes v ON vm.voteid = v.voteid
    WHERE vm.state = $1
      AND v.chamber = 'h'
      AND v.congress = (SELECT MAX(congress) FROM votes WHERE chamber = 'h')
    ORDER BY vm.bioguide_id, v.votedate DESC
"""


@router.get("/representatives/{zipcode}")
async def representatives_by_zip(request: Request, zipcode: str):
    """Return senators and house representatives for a given ZIP code."""
    if not _ZIP_RE.match(zipcode):
        raise HTTPException(status_code=400, detail={"error": "Invalid ZIP code — must be 5 digits"})

    districts = await request.app.state.db.fetch(_DISTRICTS_SQL, zipcode)
    if not districts:
        raise HTTPException(status_code=404, detail={"error": "ZIP code not found"})

    # Collect unique states from the zip lookup
    states = sorted(set(r["state_abbr"] for r in districts))
    district_numbers = [(r["state_abbr"], r["cd"]) for r in districts]

    # Fetch senators and house members for all matched states in parallel
    tasks = []
    for state in states:
        tasks.append(request.app.state.db.fetch(_SENATORS_SQL, state))
        tasks.append(request.app.state.db.fetch(_HOUSE_MEMBERS_SQL, state))

    results = await asyncio.gather(*tasks)

    senators = []
    representatives = []
    seen = set()

    for i, state in enumerate(states):
        for r in results[i * 2]:
            if r["bioguide_id"] not in seen:
                seen.add(r["bioguide_id"])
                senators.append(dict(r))
        for r in results[i * 2 + 1]:
            if r["bioguide_id"] not in seen:
                seen.add(r["bioguide_id"])
                representatives.append(dict(r))

    return {
        "zipcode": zipcode,
        "districts": [{"state": s, "district": d} for s, d in district_numbers],
        "senators": senators,
        "representatives": representatives,
    }
