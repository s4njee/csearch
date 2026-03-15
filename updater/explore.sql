-- Exploratory queries for the normalized ingest model used by the Go updater.
--
-- These are intentionally read-only and are not part of the sqlc-generated API.
-- Use them when you want to inspect content quality, find interesting records,
-- or sanity-check ingest outcomes after a sync.

-- 1. Most recently updated bills with sponsor and taxonomy context.
SELECT
    b.congress,
    b.billtype,
    b.billnumber,
    b.shorttitle,
    b.officialtitle,
    b.statusat,
    b.update_date,
    b.origin_chamber,
    b.policy_area,
    b.sponsor_name,
    b.sponsor_party,
    b.sponsor_state
FROM bills b
ORDER BY b.statusat DESC, b.update_date DESC NULLS LAST
LIMIT 25;

-- 2. Bills with the largest cosponsor coalitions.
SELECT
    b.congress,
    b.billtype,
    b.billnumber,
    COALESCE(b.shorttitle, b.officialtitle) AS title,
    COUNT(*) AS cosponsor_count
FROM bills b
JOIN bill_cosponsors bc
    ON bc.billtype = b.billtype
   AND bc.billnumber = b.billnumber
   AND bc.congress = b.congress
GROUP BY
    b.congress,
    b.billtype,
    b.billnumber,
    COALESCE(b.shorttitle, b.officialtitle)
ORDER BY cosponsor_count DESC, b.congress DESC
LIMIT 25;

-- 3. Subject areas with the most bills in the dataset.
SELECT
    bs.subject,
    COUNT(*) AS bill_count,
    COUNT(DISTINCT bs.congress) AS congresses_covered
FROM bill_subjects bs
GROUP BY bs.subject
ORDER BY bill_count DESC, congresses_covered DESC, bs.subject
LIMIT 30;

-- 4. Most active committees by number of referred bills.
SELECT
    bc.committee_code,
    MAX(bc.committee_name) AS committee_name,
    COUNT(*) AS bill_count,
    COUNT(DISTINCT bc.congress) AS congresses_covered
FROM bill_committees bc
GROUP BY bc.committee_code
ORDER BY bill_count DESC, congresses_covered DESC, bc.committee_code
LIMIT 30;

-- 5. Bills with the deepest action history.
SELECT
    b.congress,
    b.billtype,
    b.billnumber,
    COALESCE(b.shorttitle, b.officialtitle) AS title,
    COUNT(*) AS action_count,
    MIN(ba.acted_at) AS first_action_at,
    MAX(ba.acted_at) AS latest_action_at
FROM bills b
JOIN bill_actions ba
    ON ba.billtype = b.billtype
   AND ba.billnumber = b.billnumber
   AND ba.congress = b.congress
GROUP BY
    b.congress,
    b.billtype,
    b.billnumber,
    COALESCE(b.shorttitle, b.officialtitle)
ORDER BY action_count DESC, latest_action_at DESC
LIMIT 25;

-- 6. Bills that appear to be missing common descriptive fields.
SELECT
    b.congress,
    b.billtype,
    b.billnumber,
    b.shorttitle,
    b.officialtitle,
    b.sponsor_name,
    b.policy_area,
    b.summary_date,
    b.update_date
FROM bills b
WHERE b.shorttitle IS NULL
   OR b.officialtitle IS NULL
   OR b.sponsor_name IS NULL
   OR b.summary_text IS NULL
   OR b.policy_area IS NULL
ORDER BY b.congress DESC, b.billtype, b.billnumber
LIMIT 50;

-- 7. Votes with the largest margins.
SELECT
    v.voteid,
    v.congress,
    v.chamber,
    v.votetype,
    v.question,
    v.result,
    SUM(CASE WHEN vm.position = 'yea' THEN 1 ELSE 0 END) AS yea_count,
    SUM(CASE WHEN vm.position = 'nay' THEN 1 ELSE 0 END) AS nay_count,
    ABS(
        SUM(CASE WHEN vm.position = 'yea' THEN 1 ELSE 0 END) -
        SUM(CASE WHEN vm.position = 'nay' THEN 1 ELSE 0 END)
    ) AS margin
FROM votes v
JOIN vote_members vm
    ON vm.voteid = v.voteid
GROUP BY
    v.voteid,
    v.congress,
    v.chamber,
    v.votetype,
    v.question,
    v.result
ORDER BY margin DESC, v.congress DESC, v.voteid DESC
LIMIT 25;

-- 8. Closest votes, useful for spotting contested measures.
SELECT
    v.voteid,
    v.congress,
    v.chamber,
    v.question,
    v.result,
    SUM(CASE WHEN vm.position = 'yea' THEN 1 ELSE 0 END) AS yea_count,
    SUM(CASE WHEN vm.position = 'nay' THEN 1 ELSE 0 END) AS nay_count,
    ABS(
        SUM(CASE WHEN vm.position = 'yea' THEN 1 ELSE 0 END) -
        SUM(CASE WHEN vm.position = 'nay' THEN 1 ELSE 0 END)
    ) AS margin
FROM votes v
JOIN vote_members vm
    ON vm.voteid = v.voteid
GROUP BY
    v.voteid,
    v.congress,
    v.chamber,
    v.question,
    v.result
HAVING SUM(CASE WHEN vm.position IN ('yea', 'nay') THEN 1 ELSE 0 END) > 0
ORDER BY margin ASC, v.congress DESC, v.voteid DESC
LIMIT 25;

-- 9. Members with the most "not voting" records in the dataset.
SELECT
    vm.bioguide_id,
    MAX(vm.display_name) AS display_name,
    MAX(vm.party) AS party,
    MAX(vm.state) AS state,
    COUNT(*) AS not_voting_count
FROM vote_members vm
WHERE vm.position = 'notvoting'
GROUP BY vm.bioguide_id
ORDER BY not_voting_count DESC, display_name
LIMIT 30;

-- 10. Bills that have both broad sponsorship and many procedural steps.
SELECT
    b.congress,
    b.billtype,
    b.billnumber,
    COALESCE(b.shorttitle, b.officialtitle) AS title,
    COUNT(DISTINCT bc.bioguide_id) AS cosponsor_count,
    COUNT(DISTINCT ba.acted_at) AS action_count
FROM bills b
LEFT JOIN bill_cosponsors bc
    ON bc.billtype = b.billtype
   AND bc.billnumber = b.billnumber
   AND bc.congress = b.congress
LEFT JOIN bill_actions ba
    ON ba.billtype = b.billtype
   AND ba.billnumber = b.billnumber
   AND ba.congress = b.congress
GROUP BY
    b.congress,
    b.billtype,
    b.billnumber,
    COALESCE(b.shorttitle, b.officialtitle)
HAVING COUNT(DISTINCT bc.bioguide_id) >= 25
   AND COUNT(DISTINCT ba.acted_at) >= 10
ORDER BY cosponsor_count DESC, action_count DESC, b.congress DESC
LIMIT 25;

-- 11. Example full-text bill search using the bootstrap helper function.
SELECT *
FROM search_bills('clean energy tax credit', NULL, NULL, 20);

-- 12. Example full-text vote search over question/result text.
SELECT *
FROM search_votes('cloture nomination', NULL, NULL, 20);
