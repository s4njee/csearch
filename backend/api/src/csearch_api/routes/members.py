from __future__ import annotations

import asyncio

from fastapi import APIRouter, HTTPException, Request

from csearch_api import queries

router = APIRouter()

VALID_STATE_CODES = frozenset({
    'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
    'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
    'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
    'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
    'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY',
    'DC', 'AS', 'GU', 'MP', 'PR', 'VI',
})

MEMBER_SPONSORED_BILLS_LIMIT = 20
MEMBER_RECENT_VOTES_LIMIT = 50


def _validate_bioguide_id(bioguide_id: str) -> str:
    if not bioguide_id.isalnum():
        raise HTTPException(status_code=400, detail={"error": "Invalid bioguide ID format"})
    return bioguide_id.upper()


_MEMBERS_BY_STATE_SQL = """
    SELECT DISTINCT ON (vm.bioguide_id)
        vm.bioguide_id,
        vm.display_name AS name,
        vm.party
    FROM vote_members vm
    JOIN votes v ON vm.voteid = v.voteid
    WHERE vm.state = $1
      AND v.chamber = $2
      AND v.congress = (SELECT MAX(congress) FROM votes WHERE chamber = $2)
    ORDER BY vm.bioguide_id, v.votedate DESC
"""


# Must be registered before /members/{bioguide_id} to avoid the path segment being
# captured as a bioguide ID.
@router.get("/members/by-state/{state}")
async def members_by_state(request: Request, state: str):
    """Return senators and house representatives for a given US state from the most recent congress."""
    state_upper = state.upper()
    if state_upper not in VALID_STATE_CODES:
        raise HTTPException(status_code=400, detail={"error": "Invalid state code"})

    senators_task = request.app.state.db.fetch(_MEMBERS_BY_STATE_SQL, state_upper, 's')
    reps_task = request.app.state.db.fetch(_MEMBERS_BY_STATE_SQL, state_upper, 'h')
    senators, reps = await asyncio.gather(senators_task, reps_task)

    return {
        "state": state_upper,
        "senators": [dict(r) for r in senators],
        "representatives": [dict(r) for r in reps],
    }


@router.get("/members/{bioguide_id}")
async def member_detail(request: Request, bioguide_id: str):
    """Return a member's profile, sponsored bills, recent votes, and sponsorship counts."""
    upper_id = _validate_bioguide_id(bioguide_id)

    profile = await request.app.state.db.fetchrow(
        """
        SELECT display_name AS name, party, state
        FROM vote_members
        WHERE bioguide_id = $1
        LIMIT 1
        """,
        upper_id,
    )
    if not profile:
        profile = await request.app.state.db.fetchrow(
            """
            SELECT full_name AS name, party, state
            FROM bill_cosponsors
            WHERE bioguide_id = $1
            LIMIT 1
            """,
            upper_id,
        )
    if not profile:
        profile = await request.app.state.db.fetchrow(
            """
            SELECT sponsor_name AS name, sponsor_party AS party, sponsor_state AS state
            FROM bills
            WHERE sponsor_bioguide_id = $1
            LIMIT 1
            """,
            upper_id,
        )

    if not profile:
        raise HTTPException(status_code=404, detail={"error": "Member not found in recent records"})

    sponsored_bills_task = request.app.state.db.fetch(
        f"""
        SELECT
            b.billid,
            b.billnumber::text AS billnumber,
            b.billtype,
            b.congress::text AS congress,
            b.shorttitle,
            b.officialtitle,
            b.introducedat,
            b.statusat,
            b.bill_status,
            b.summary_text,
            b.policy_area,
            b.latest_action_date,
            {queries.COSPONSOR_COUNT_SQL}
        FROM bills AS b
        WHERE b.sponsor_bioguide_id = $1
        ORDER BY b.latest_action_date DESC NULLS LAST
        LIMIT {MEMBER_SPONSORED_BILLS_LIMIT}
        """,
        upper_id,
    )
    recent_votes_task = request.app.state.db.fetch(
        """
        SELECT
            votes.voteid,
            votes.congress::text AS congress,
            votes.chamber,
            votes.question,
            votes.result,
            votes.votedate,
            votes.votetype,
            votes.votenumber::text AS votenumber,
            vote_members.position
        FROM vote_members
        JOIN votes ON vote_members.voteid = votes.voteid
        WHERE vote_members.bioguide_id = $1
        ORDER BY votes.votedate DESC
        LIMIT {MEMBER_RECENT_VOTES_LIMIT}
        """,
        upper_id,
    )
    sponsored_count_task = request.app.state.db.fetchrow(
        """
        SELECT COUNT(*)::int AS total
        FROM bills
        WHERE sponsor_bioguide_id = $1
        """,
        upper_id,
    )
    cosponsored_count_task = request.app.state.db.fetchrow(
        """
        SELECT COUNT(*)::int AS total
        FROM bill_cosponsors
        WHERE bioguide_id = $1
        """,
        upper_id,
    )

    sponsored_bills, recent_votes, sponsored_count, cosponsored_count = await asyncio.gather(
        sponsored_bills_task,
        recent_votes_task,
        sponsored_count_task,
        cosponsored_count_task,
    )

    return {
        "bioguide_id": upper_id,
        "name": profile["name"],
        "party": profile["party"],
        "state": profile["state"],
        "counts": {
            "sponsored": sponsored_count["total"] if sponsored_count else 0,
            "cosponsored": cosponsored_count["total"] if cosponsored_count else 0,
        },
        "sponsoredBills": sponsored_bills,
        "recentVotes": recent_votes,
    }
