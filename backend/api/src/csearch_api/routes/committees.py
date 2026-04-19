from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request

from csearch_api import queries

router = APIRouter()


@router.get("/committees")
async def committees(request: Request):
    return await request.app.state.db.fetch(
        """
        SELECT
            c.committee_code,
            c.committee_name,
            c.chamber,
            COUNT(*) AS bill_count
        FROM committees AS c
        JOIN bill_committees AS bc ON bc.committee_code = c.committee_code
        GROUP BY c.committee_code, c.committee_name, c.chamber
        ORDER BY c.committee_name ASC
        """
    )


@router.get("/committees/{committee_code}")
async def committee_detail(request: Request, committee_code: str):
    committee = await request.app.state.db.fetchrow(
        """
        SELECT committee_code, committee_name, chamber
        FROM committees
        WHERE committee_code = $1
        LIMIT 1
        """,
        committee_code,
    )

    if not committee:
        raise HTTPException(status_code=404, detail={"error": "Committee not found"})

    bills = await request.app.state.db.fetch(
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
        FROM bill_committees AS bc
        JOIN bills AS b
          ON bc.billtype = b.billtype
         AND bc.billnumber = b.billnumber
         AND bc.congress = b.congress
        WHERE bc.committee_code = $1
        ORDER BY b.latest_action_date DESC NULLS LAST
        LIMIT 100
        """,
        committee_code,
    )

    committee["bills"] = bills
    return committee
