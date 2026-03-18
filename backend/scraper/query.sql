-- name: InsertBill :exec
INSERT INTO bills (
    billid, billnumber, billtype, introducedat, congress,
    summary_date, summary_text,
    sponsor_bioguide_id, sponsor_name, sponsor_state, sponsor_party,
    origin_chamber, policy_area, update_date,
    latest_action_date, bill_status, statusat, shorttitle, officialtitle
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19
) ON CONFLICT (billtype, billnumber, congress) DO UPDATE SET
    summary_date        = excluded.summary_date,
    summary_text        = excluded.summary_text,
    sponsor_bioguide_id = excluded.sponsor_bioguide_id,
    sponsor_name        = excluded.sponsor_name,
    sponsor_state       = excluded.sponsor_state,
    sponsor_party       = excluded.sponsor_party,
    origin_chamber      = excluded.origin_chamber,
    policy_area         = excluded.policy_area,
    update_date         = excluded.update_date,
    latest_action_date  = excluded.latest_action_date,
    bill_status         = excluded.bill_status,
    statusat            = excluded.statusat,
    shorttitle          = excluded.shorttitle,
    officialtitle       = excluded.officialtitle;

-- name: DeleteBillActions :exec
DELETE FROM bill_actions WHERE billtype = $1 AND billnumber = $2 AND congress = $3;

-- name: InsertBillAction :one
INSERT INTO bill_actions (billtype, billnumber, congress, acted_at, action_text, action_type, action_code, source_system_code)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
RETURNING id;

-- name: UpdateBillLatestAction :exec
UPDATE bills
SET latest_action_id = $4,
    latest_action_date = $5
WHERE billtype = $1
  AND billnumber = $2
  AND congress = $3;

-- name: ClearBillLatestAction :exec
UPDATE bills
SET latest_action_id = NULL,
    latest_action_date = $4
WHERE billtype = $1
  AND billnumber = $2
  AND congress = $3;

-- name: DeleteBillCosponsors :exec
DELETE FROM bill_cosponsors WHERE billtype = $1 AND billnumber = $2 AND congress = $3;

-- name: InsertBillCosponsor :exec
INSERT INTO bill_cosponsors (billtype, billnumber, congress, bioguide_id, full_name, state, party, sponsorship_date, is_original_cosponsor)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
ON CONFLICT ON CONSTRAINT bill_cosponsors_pkey DO NOTHING;

-- name: DeleteBillCommittees :exec
DELETE FROM bill_committees WHERE billtype = $1 AND billnumber = $2 AND congress = $3;

-- name: InsertCommittee :exec
INSERT INTO committees (committee_code, committee_name, chamber)
VALUES ($1, $2, $3)
ON CONFLICT (committee_code) DO UPDATE SET
    committee_name = excluded.committee_name,
    chamber = excluded.chamber;

-- name: InsertBillCommittee :exec
INSERT INTO bill_committees (billtype, billnumber, congress, committee_code)
VALUES ($1, $2, $3, $4)
ON CONFLICT ON CONSTRAINT bill_committees_pkey DO NOTHING;

-- name: DeleteBillSubjects :exec
DELETE FROM bill_subjects WHERE billtype = $1 AND billnumber = $2 AND congress = $3;

-- name: InsertBillSubject :exec
INSERT INTO bill_subjects (billtype, billnumber, congress, subject)
VALUES ($1, $2, $3, $4)
ON CONFLICT ON CONSTRAINT bill_subjects_pkey DO NOTHING;

-- name: InsertVote :exec
INSERT INTO votes (
    voteid, bill_type, bill_number, congress,
    votenumber, votedate, question, result,
    votesession, chamber, source_url, votetype
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12
) ON CONFLICT (voteid) DO UPDATE SET
    bill_type   = excluded.bill_type,
    bill_number = excluded.bill_number,
    congress    = excluded.congress,
    votenumber  = excluded.votenumber,
    votedate    = excluded.votedate,
    question    = excluded.question,
    result      = excluded.result,
    votesession = excluded.votesession,
    chamber     = excluded.chamber,
    source_url  = excluded.source_url,
    votetype    = excluded.votetype;

-- name: DeleteVoteMembers :exec
DELETE FROM vote_members WHERE voteid = $1;

-- name: InsertVoteMember :exec
INSERT INTO vote_members (voteid, bioguide_id, display_name, party, state, position)
VALUES ($1, $2, $3, $4, $5, $6)
ON CONFLICT ON CONSTRAINT vote_members_pkey DO NOTHING;
