-- name: InsertBill :exec
INSERT INTO bills (billid, billnumber, billtype, introducedat, congress, summary, actions, sponsors, cosponsors, statusat, shorttitle, officialtitle
) VALUES (
             $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12
         ) ON CONFLICT ON CONSTRAINT bill_pkey DO UPDATE SET summary=excluded.summary, actions=excluded.actions, sponsors=excluded.sponsors, cosponsors=excluded.cosponsors, statusat=excluded.statusat, shorttitle=excluded.shorttitle, officialtitle=excluded.officialtitle
WHERE bills.statusat IS DISTINCT FROM excluded.statusat;

-- name: InsertVote :exec
INSERT INTO votes (
    bill,
    congress,
    chamber,
    votenumber,
    votedate,
    votesession,
    question,
    result,
    yea,
    nay,
    present,
    notvoting,
    source_url,
    votetype,
    voteid) VALUES (
             $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15 
         ) ON CONFLICT DO NOTHING;