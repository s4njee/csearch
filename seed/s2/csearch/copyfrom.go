// Code generated by sqlc. DO NOT EDIT.
// versions:
//   sqlc v1.16.0
// source: copyfrom.go

package csearch

import (
	"context"
)

// iteratorForInsertBill implements pgx.CopyFromSource.
type iteratorForInsertBill struct {
	rows                 []InsertBillParams
	skippedFirstNextCall bool
}

func (r *iteratorForInsertBill) Next() bool {
	if len(r.rows) == 0 {
		return false
	}
	if !r.skippedFirstNextCall {
		r.skippedFirstNextCall = true
		return true
	}
	r.rows = r.rows[1:]
	return len(r.rows) > 0
}

func (r iteratorForInsertBill) Values() ([]interface{}, error) {
	return []interface{}{
		r.rows[0].Billid,
		r.rows[0].Billnumber,
		r.rows[0].Billtype,
		r.rows[0].Introducedat,
		r.rows[0].Congress,
		r.rows[0].Summary,
		r.rows[0].Actions,
		r.rows[0].Sponsors,
		r.rows[0].Cosponsors,
		r.rows[0].Statusat,
		r.rows[0].Shorttitle,
		r.rows[0].Officialtitle,
	}, nil
}

func (r iteratorForInsertBill) Err() error {
	return nil
}

func (q *Queries) InsertBill(ctx context.Context, arg []InsertBillParams) (int64, error) {
	return q.db.CopyFrom(ctx, []string{"bills"}, []string{"billid", "billnumber", "billtype", "introducedat", "congress", "summary", "actions", "sponsors", "cosponsors", "statusat", "shorttitle", "officialtitle"}, &iteratorForInsertBill{rows: arg})
}
