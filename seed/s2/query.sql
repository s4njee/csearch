-- name: InsertBill :copyfrom
INSERT INTO bills (billid, billnumber, billtype, introducedat, congress, summary, actions, sponsors, cosponsors, statusat, shorttitle, officialtitle
    ) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12
);

