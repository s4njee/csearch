from __future__ import annotations

from .constants import MIN_FUZZY_QUERY_LENGTH

# --- Column helpers ---
# Reusable SELECT fragments and subqueries shared across multiple routes.

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

# --- Subquery constants ---
# Inline subqueries used in SELECT clauses across routes.
# Keep in sync with schema.sql if table structures change.

# Collect distinct committee codes as an array per bill.
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

# Count confirmed cosponsors per bill.
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


# --- Bill detail queries ---
# The five queries the bill-detail route runs (gathered concurrently). Kept here
# so the SQL lives alongside the other shared fragments. Bind order:
#   BILL_DETAIL_SQL / ACTIONS / COSPONSORS / COMMITTEES: $1=billtype, $2=congress, $3=billnumber
#   BILL_DETAIL_VOTES_SQL: $1=billtype(bill_type), $2=billnumber(bill_number), $3=congress

BILL_DETAIL_SQL = """
    SELECT
        billid,
        billnumber::text AS billnumber,
        billtype,
        congress::text AS congress,
        shorttitle,
        officialtitle,
        introducedat,
        statusat,
        bill_status,
        summary_text,
        summary_date,
        sponsor_name,
        sponsor_party,
        sponsor_state,
        sponsor_bioguide_id,
        origin_chamber,
        policy_area,
        update_date,
        latest_action_date
    FROM bills
    WHERE billtype = $1 AND congress = $2 AND billnumber = $3
"""

BILL_DETAIL_ACTIONS_SQL = """
    SELECT acted_at, action_text, action_type, action_code
    FROM bill_actions
    WHERE billtype = $1 AND congress = $2 AND billnumber = $3
    ORDER BY acted_at ASC
"""

BILL_DETAIL_COSPONSORS_SQL = """
    SELECT bioguide_id, full_name, state, party, sponsorship_date, is_original_cosponsor
    FROM bill_cosponsors
    WHERE billtype = $1 AND congress = $2 AND billnumber = $3
    ORDER BY sponsorship_date ASC
"""

BILL_DETAIL_VOTES_SQL = """
    SELECT voteid, congress, chamber, question, result, votedate, votetype
    FROM votes
    WHERE bill_type = $1 AND bill_number = $2 AND congress = $3
    ORDER BY votedate DESC
"""

BILL_DETAIL_COMMITTEES_SQL = """
    SELECT bc.committee_code, c.committee_name, c.chamber
    FROM bill_committees bc
    JOIN committees c ON bc.committee_code = c.committee_code
    WHERE bc.billtype = $1 AND bc.congress = $2 AND bc.billnumber = $3
"""


def use_fuzzy_search(query: str) -> bool:
    return len(query) >= MIN_FUZZY_QUERY_LENGTH

