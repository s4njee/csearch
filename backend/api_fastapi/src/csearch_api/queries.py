from __future__ import annotations

from .constants import MIN_FUZZY_QUERY_LENGTH

BILL_LIST_COLUMNS = """
    b.billid,
    b.shorttitle,
    b.officialtitle,
    b.introducedat,
    b.summary_text,
    b.billtype,
    b.congress::text AS congress,
    b.billnumber::text AS billnumber,
    b.sponsor_name,
    b.sponsor_party,
    b.sponsor_state,
    b.sponsor_bioguide_id,
    b.bill_status,
    b.statusat,
    b.policy_area,
    b.latest_action_date,
    b.origin_chamber
"""

BILL_COMMITTEE_CODES_SQL = """
    (
        SELECT COALESCE(
            array_agg(DISTINCT bc.committee_code ORDER BY bc.committee_code),
            '{}'
        )
        FROM bill_committees bc
        WHERE bc.billtype = b.billtype
          AND bc.billnumber = b.billnumber
          AND bc.congress = b.congress
    ) AS committee_codes
"""

COSPONSOR_COUNT_SQL = """
    (
        SELECT COUNT(*)::int
        FROM bill_cosponsors bc
        WHERE bc.billtype = b.billtype
          AND bc.billnumber = b.billnumber
          AND bc.congress = b.congress
    ) AS cosponsor_count
"""

BILL_FUZZY_SEARCH_EXPR = (
    "concat_ws(' ', coalesce(b.shorttitle, ''), coalesce(b.officialtitle, ''), "
    "coalesce(b.sponsor_name, ''), coalesce(b.policy_area, ''))"
)


def use_fuzzy_search(query: str) -> bool:
    return len(query) >= MIN_FUZZY_QUERY_LENGTH

