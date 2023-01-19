// Code generated by sqlc. DO NOT EDIT.
// versions:
//   sqlc v1.16.0

package csearch

import (
	"database/sql"

	"github.com/jackc/pgtype"
)

type Bill struct {
	Billid        sql.NullString
	Billnumber    string
	Billtype      string
	Introducedat  sql.NullString
	Congress      string
	Summary       pgtype.JSONB
	Actions       pgtype.JSONB
	Sponsors      pgtype.JSONB
	Cosponsors    pgtype.JSONB
	Statusat      sql.NullString
	Shorttitle    sql.NullString
	Officialtitle sql.NullString
	STs           interface{}
	HrTs          interface{}
	HconresTs     interface{}
	HjresTs       interface{}
	HresTs        interface{}
	SconresTs     interface{}
	SjresTs       interface{}
	SresTs        interface{}
}

type Bills struct {
	Billid        sql.NullString
	Billnumber    string
	Billtype      string
	Introducedat  sql.NullString
	Congress      string
	Summary       pgtype.JSONB
	Actions       pgtype.JSONB
	Sponsors      pgtype.JSONB
	Cosponsors    pgtype.JSONB
	Statusat      sql.NullString
	Shorttitle    sql.NullString
	Officialtitle sql.NullString
}

type BillsHconre struct {
	Billid        sql.NullString
	Billnumber    string
	Billtype      string
	Introducedat  sql.NullString
	Congress      string
	Summary       pgtype.JSONB
	Actions       pgtype.JSONB
	Sponsors      pgtype.JSONB
	Cosponsors    pgtype.JSONB
	Statusat      sql.NullString
	Shorttitle    sql.NullString
	Officialtitle sql.NullString
}

type BillsHjre struct {
	Billid        sql.NullString
	Billnumber    string
	Billtype      string
	Introducedat  sql.NullString
	Congress      string
	Summary       pgtype.JSONB
	Actions       pgtype.JSONB
	Sponsors      pgtype.JSONB
	Cosponsors    pgtype.JSONB
	Statusat      sql.NullString
	Shorttitle    sql.NullString
	Officialtitle sql.NullString
}

type BillsHr struct {
	Billid        sql.NullString
	Billnumber    string
	Billtype      string
	Introducedat  sql.NullString
	Congress      string
	Summary       pgtype.JSONB
	Actions       pgtype.JSONB
	Sponsors      pgtype.JSONB
	Cosponsors    pgtype.JSONB
	Statusat      sql.NullString
	Shorttitle    sql.NullString
	Officialtitle sql.NullString
}

type BillsHre struct {
	Billid        sql.NullString
	Billnumber    string
	Billtype      string
	Introducedat  sql.NullString
	Congress      string
	Summary       pgtype.JSONB
	Actions       pgtype.JSONB
	Sponsors      pgtype.JSONB
	Cosponsors    pgtype.JSONB
	Statusat      sql.NullString
	Shorttitle    sql.NullString
	Officialtitle sql.NullString
}

type BillsSconre struct {
	Billid        sql.NullString
	Billnumber    string
	Billtype      string
	Introducedat  sql.NullString
	Congress      string
	Summary       pgtype.JSONB
	Actions       pgtype.JSONB
	Sponsors      pgtype.JSONB
	Cosponsors    pgtype.JSONB
	Statusat      sql.NullString
	Shorttitle    sql.NullString
	Officialtitle sql.NullString
}

type BillsSjre struct {
	Billid        sql.NullString
	Billnumber    string
	Billtype      string
	Introducedat  sql.NullString
	Congress      string
	Summary       pgtype.JSONB
	Actions       pgtype.JSONB
	Sponsors      pgtype.JSONB
	Cosponsors    pgtype.JSONB
	Statusat      sql.NullString
	Shorttitle    sql.NullString
	Officialtitle sql.NullString
}

type BillsSre struct {
	Billid        sql.NullString
	Billnumber    string
	Billtype      string
	Introducedat  sql.NullString
	Congress      string
	Summary       pgtype.JSONB
	Actions       pgtype.JSONB
	Sponsors      pgtype.JSONB
	Cosponsors    pgtype.JSONB
	Statusat      sql.NullString
	Shorttitle    sql.NullString
	Officialtitle sql.NullString
}
