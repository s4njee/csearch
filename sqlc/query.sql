-- name: InsertBill :one
INSERT INTO bills (billid, billnumber, billtype, introducedat, congress, summary, actions, sponsors, cosponsors, statusat, shorttitle, officialtitle
    ) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12
) ON CONFLICT DO UPDATE SET summary=excluded.summary, actions=excluded.actions, sponsors=excluded.sponsors, cosponsors=excluded.cosponsors, statusat=excluded.statusat, shorttitle=excluded.shorttitle, officialtitle=excluded.officialtitle
WHERE statusat IS DISTINCT FROM excluded.statusat
  RETURNING *;


