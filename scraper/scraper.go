package main

import (
	"bufio"
	"context"
	"database/sql"
	"encoding/json"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"os/exec"
	"runtime/debug"
	"strconv"
	"strings"
	"sync"

	"github.com/uptrace/bun"
)

var Tables = [8]string{"s", "hr", "hconres", "hjres", "hres", "sconres", "sjres", "sres"}

// ── XML structs ──────────────────────────────────────────────────────────────

type XMLSummaries struct {
	XMLName          xml.Name         `xml:"summaries"`
	XMLBillSummaries XMLBillSummaries `xml:"billSummaries"`
}

type XMLBillSummaries struct {
	XMLName      xml.Name               `xml:"billSummaries"`
	XMLBillItems []XMLBillSummariesItem `xml:"item"`
}

type XMLBillSummariesItem struct {
	XMLName xml.Name `xml:"item"`
	Date    string   `xml:"lastSummaryUpdateDate"`
	Text    string   `xml:"text"`
}

type SourceSystemXML struct {
	Code string `xml:"code"`
	Name string `xml:"name"`
}

type ItemXML struct {
	XMLName      xml.Name        `xml:"item"`
	ActedAt      string          `xml:"actionDate"`
	Text         string          `xml:"text"`
	Type         string          `xml:"type"`
	ActionCode   string          `xml:"actionCode"`
	SourceSystem SourceSystemXML `xml:"sourceSystem"`
}

type ActionsXML struct {
	XMLName xml.Name  `xml:"actions"`
	Actions []ItemXML `xml:"item"`
}

type SponsorXML struct {
	XMLName    xml.Name `xml:"item"`
	BioguideId string   `xml:"bioguideId"`
	FullName   string   `xml:"fullName"`
	State      string   `xml:"state"`
	Party      string   `xml:"party"`
}

type SponsorsXML struct {
	XMLName  xml.Name     `xml:"sponsors"`
	Sponsors []SponsorXML `xml:"item"`
}

type CosponsorXML struct {
	XMLName             xml.Name `xml:"item"`
	BioguideId          string   `xml:"bioguideId"`
	FullName            string   `xml:"fullName"`
	State               string   `xml:"state"`
	Party               string   `xml:"party"`
	SponsorshipDate     string   `xml:"sponsorshipDate"`
	IsOriginalCosponsor string   `xml:"isOriginalCosponsor"`
}

type CosponsorsXML struct {
	XMLName    xml.Name       `xml:"cosponsors"`
	Cosponsors []CosponsorXML `xml:"item"`
}

type TitleItemXML struct {
	XMLName   xml.Name `xml:"item"`
	TitleType string   `xml:"titleType"`
	Title     string   `xml:"title"`
}

type TitlesXML struct {
	XMLName xml.Name       `xml:"titles"`
	Items   []TitleItemXML `xml:"item"`
}

type CommitteeItemXML struct {
	XMLName    xml.Name `xml:"item"`
	SystemCode string   `xml:"systemCode"`
	Name       string   `xml:"name"`
	Chamber    string   `xml:"chamber"`
}

type BillCommitteesXML struct {
	XMLName xml.Name           `xml:"billCommittees"`
	Items   []CommitteeItemXML `xml:"item"`
}

type CommitteesXML struct {
	XMLName        xml.Name          `xml:"committees"`
	BillCommittees BillCommitteesXML `xml:"billCommittees"`
}

type SubjectItemXML struct {
	XMLName xml.Name `xml:"item"`
	Name    string   `xml:"name"`
}

type LegislativeSubjectsXML struct {
	XMLName xml.Name         `xml:"legislativeSubjects"`
	Items   []SubjectItemXML `xml:"item"`
}

type PolicyAreaXML struct {
	XMLName xml.Name `xml:"policyArea"`
	Name    string   `xml:"name"`
}

type BillSubjectsXML struct {
	XMLName             xml.Name               `xml:"billSubjects"`
	LegislativeSubjects LegislativeSubjectsXML `xml:"legislativeSubjects"`
	PolicyArea          PolicyAreaXML          `xml:"policyArea"`
}

type SubjectsXML struct {
	XMLName      xml.Name        `xml:"subjects"`
	BillSubjects BillSubjectsXML `xml:"billSubjects"`
}

type LatestActionXML struct {
	XMLName    xml.Name `xml:"latestAction"`
	ActionDate string   `xml:"actionDate"`
	Text       string   `xml:"text"`
}

// BillXML covers congress < 114
type BillXML struct {
	XMLName       xml.Name        `xml:"bill"`
	Number        string          `xml:"billNumber"`
	BillType      string          `xml:"billType"`
	IntroducedAt  string          `xml:"introducedDate"`
	UpdateDate    string          `xml:"updateDate"`
	OriginChamber string          `xml:"originChamber"`
	Congress      string          `xml:"congress"`
	Summary       XMLSummaries    `xml:"summaries"`
	Actions       ActionsXML      `xml:"actions"`
	Sponsors      SponsorsXML     `xml:"sponsors"`
	Cosponsors    CosponsorsXML   `xml:"cosponsors"`
	Titles        TitlesXML       `xml:"titles"`
	Committees    CommitteesXML   `xml:"committees"`
	Subjects      SubjectsXML     `xml:"subjects"`
	LatestAction  LatestActionXML `xml:"latestAction"`
	ShortTitle    string          `xml:"title"`
}

// BillXMLnew covers congress >= 114
type BillXMLnew struct {
	XMLName       xml.Name        `xml:"bill"`
	Number        string          `xml:"number"`
	BillType      string          `xml:"billType"`
	Type          string          `xml:"type"`
	IntroducedAt  string          `xml:"introducedDate"`
	UpdateDate    string          `xml:"updateDate"`
	OriginChamber string          `xml:"originChamber"`
	Congress      string          `xml:"congress"`
	Summary       XMLSummaries    `xml:"summaries"`
	Actions       ActionsXML      `xml:"actions"`
	Sponsors      SponsorsXML     `xml:"sponsors"`
	Cosponsors    CosponsorsXML   `xml:"cosponsors"`
	Titles        TitlesXML       `xml:"titles"`
	Committees    CommitteesXML   `xml:"committees"`
	Subjects      SubjectsXML     `xml:"subjects"`
	LatestAction  LatestActionXML `xml:"latestAction"`
	ShortTitle    string          `xml:"title"`
}

type BillXMLRoot struct {
	XMLName xml.Name `xml:"billStatus"`
	BillXML BillXML  `xml:"bill"`
}

type BillXMLRootnew struct {
	XMLName xml.Name   `xml:"billStatus"`
	BillXML BillXMLnew `xml:"bill"`
}

// ── DB models ────────────────────────────────────────────────────────────────

type Bill struct {
	bun.BaseModel     `bun:"table:bills"`
	BillID            string `bun:",pk"`
	Number            string
	BillType          string `json:"bill_type" bun:",pk"`
	IntroducedAt      string `json:"introduced_at"`
	Congress          string
	UpdateDate        string `json:"update_date"`
	OriginChamber     string `json:"origin_chamber"`
	PolicyArea        string `json:"policy_area"`
	SummaryDate       string `json:"summary_date"`
	SummaryText       string `json:"summary_text"`
	SponsorBioguideId string `json:"sponsor_bioguide_id"`
	SponsorName       string `json:"sponsor_name"`
	SponsorState      string `json:"sponsor_state"`
	SponsorParty      string `json:"sponsor_party"`
	StatusAt          string `json:"status_at"`
	ShortTitle        string `json:"short_title"`
	OfficialTitle     string `json:"official_title"`
}

type BillAction struct {
	bun.BaseModel    `bun:"table:bill_actions"`
	Billtype         string
	Billnumber       string
	Congress         string
	ActedAt          string
	ActionText       string
	ActionType       string
	ActionCode       string
	SourceSystemCode string
}

type BillCosponsor struct {
	bun.BaseModel       `bun:"table:bill_cosponsors"`
	Billtype            string
	Billnumber          string
	Congress            string
	BioguideId          string
	FullName            string
	State               string
	Party               string
	SponsorshipDate     string
	IsOriginalCosponsor bool
}

type BillCommittee struct {
	bun.BaseModel `bun:"table:bill_committees"`
	Billtype      string
	Billnumber    string
	Congress      string
	CommitteeCode string
	CommitteeName string
	Chamber       string
}

type BillSubject struct {
	bun.BaseModel `bun:"table:bill_subjects"`
	Billtype      string
	Billnumber    string
	Congress      string
	Subject       string
}

// BillJSON is the legacy data.json format (older congresses).
type BillJSON struct {
	bun.BaseModel `bun:"table:bills_temp"`
	Number        string
	BillType      string `json:"bill_type"`
	IntroducedAt  string `json:"introduced_at"`
	Congress      string
	Summary       struct {
		Date string
		Text string
	} `json:"summary,omitempty"`
	Actions []struct {
		ActedAt string `json:"acted_at"`
		Text    string
		Type    string
	} `json:"actions,omitempty"`
	Sponsor struct {
		Title    string `json:"title,omitempty"`
		Name     string
		State    string
		District string `json:"district,omitempty"`
		Party    string `json:"party,omitempty"`
	} `json:"sponsor,omitempty"`
	Cosponsors []struct {
		Title    string `json:"title,omitempty"`
		Name     string
		State    string
		District string `json:"district,omitempty"`
		Party    string `json:"party,omitempty"`
	} `json:"cosponsors,omitempty"`
	StatusAt      string `json:"status_at"`
	ShortTitle    string `json:"short_title"`
	OfficialTitle string `json:"official_title"`
}

// ── Helpers ──────────────────────────────────────────────────────────────────

func officialTitleFromList(titles TitlesXML) string {
	for _, t := range titles.Items {
		if strings.HasPrefix(t.TitleType, "Official Title") {
			return t.Title
		}
	}
	return ""
}

// ── Parsers ──────────────────────────────────────────────────────────────────

func parse_bill(path string, db *bun.DB) *Bill {
	jsonFile, err := os.Open(path)
	if err != nil {
		fmt.Println(err)
	}
	defer jsonFile.Close()

	byteValue, _ := ioutil.ReadAll(jsonFile)
	var billjs BillJSON
	json.Unmarshal(byteValue, &billjs)

	var sponsorName string
	if len(billjs.Sponsor.Title) > 0 {
		sponsorName = fmt.Sprintf("%s %s [%s]", billjs.Sponsor.Title, billjs.Sponsor.Name, billjs.Sponsor.State)
	} else {
		sponsorName = fmt.Sprintf("%s [%s]", billjs.Sponsor.Name, billjs.Sponsor.State)
	}

	billID := fmt.Sprintf("%s-%s-%s", billjs.Congress, billjs.BillType, billjs.Number)
	return &Bill{
		Number:        billjs.Number,
		BillID:        billID,
		BillType:      strings.ToLower(billjs.BillType),
		IntroducedAt:  billjs.IntroducedAt,
		Congress:      billjs.Congress,
		SummaryDate:   billjs.Summary.Date,
		SummaryText:   billjs.Summary.Text,
		SponsorName:   sponsorName,
		SponsorState:  billjs.Sponsor.State,
		SponsorParty:  billjs.Sponsor.Party,
		StatusAt:      billjs.StatusAt,
		ShortTitle:    billjs.ShortTitle,
		OfficialTitle: billjs.OfficialTitle,
	}
}

func parse_bill_xml(path string, db *bun.DB, congress int) *Bill {
	xmlFile, err := os.Open(path)
	if err != nil {
		fmt.Println(err)
	}
	defer xmlFile.Close()

	byteValue, _ := ioutil.ReadAll(xmlFile)

	if congress < 114 {
		var root BillXMLRoot
		xml.Unmarshal(byteValue, &root)
		b := root.BillXML
		return buildBill(b.Number, strings.ToLower(b.BillType), b.IntroducedAt, b.UpdateDate,
			b.OriginChamber, b.Congress, b.ShortTitle, b.LatestAction.ActionDate,
			b.Summary, b.Subjects)
	}

	var root BillXMLRootnew
	xml.Unmarshal(byteValue, &root)
	b := root.BillXML
	billtype := strings.ToLower(b.Type)
	if billtype == "" {
		billtype = strings.ToLower(b.BillType)
	}
	official := officialTitleFromList(b.Titles)
	if official == "" {
		official = b.ShortTitle
	}
	bill := buildBill(b.Number, billtype, b.IntroducedAt, b.UpdateDate,
		b.OriginChamber, b.Congress, b.ShortTitle, b.LatestAction.ActionDate,
		b.Summary, b.Subjects)
	bill.OfficialTitle = official
	return bill
}

func buildBill(number, billtype, introducedAt, updateDate, originChamber, congress, shortTitle, latestActionDate string,
	summary XMLSummaries, subjects SubjectsXML) *Bill {

	var summaryDate, summaryText string
	if len(summary.XMLBillSummaries.XMLBillItems) > 0 {
		summaryDate = summary.XMLBillSummaries.XMLBillItems[0].Date
		summaryText = summary.XMLBillSummaries.XMLBillItems[0].Text
	}

	statusAt := latestActionDate
	if statusAt == "" {
		statusAt = introducedAt
	}

	billID := fmt.Sprintf("%s-%s-%s", congress, strings.ToUpper(billtype), number)
	return &Bill{
		Number:        number,
		BillID:        billID,
		BillType:      billtype,
		IntroducedAt:  introducedAt,
		UpdateDate:    updateDate,
		OriginChamber: originChamber,
		Congress:      congress,
		SummaryDate:   summaryDate,
		SummaryText:   summaryText,
		PolicyArea:    subjects.BillSubjects.PolicyArea.Name,
		StatusAt:      statusAt,
		ShortTitle:    shortTitle,
		OfficialTitle: shortTitle, // caller overrides for congress >= 114
	}
}

func main() {
	update_bills()

	ctx := context.Background()
	db, err := sql.Open("postgres", "host=localhost user=postgres password=postgres dbname=temp sslmode=disable")
	if err != nil {
		panic(err)
	}
	var wg sync.WaitGroup
	sem := make(chan struct{}, 64)
	for i := 93; i <= 117; i++ {
		for _, table := range Tables {
			files, err := ioutil.ReadDir(fmt.Sprintf("/congress/data/%s/bills/%s", strconv.Itoa(i), table))
			if err != nil {
				debug.PrintStack()
				continue
			}
			var bills = make([]*Bill, len(files))
			wg.Add(len(files))
			println(len(files))
			for z, f := range files {
				path := fmt.Sprintf("/congress/data/%s/bills/%s/", strconv.Itoa(i), table) + f.Name()
				var xmlcheck = path + "/fdsys_billstatus.xml"
				if _, err := os.Stat(xmlcheck); err == nil {
					go func(z int) {
						sem <- struct{}{}
						bills[z] = parse_bill_xml(xmlcheck, nil, i)
						defer func() { <-sem }()
						defer wg.Done()
					}(z)
				} else if errors.Is(err, os.ErrNotExist) {
					path += "/data.json"
					go func(z int) {
						sem <- struct{}{}
						bills[z] = parse_bill(path, nil)
						defer func() { <-sem }()
						defer wg.Done()
					}(z)
				}
			}
			wg.Wait()

			if len(bills) > 0 {
				res, err := db.NewInsert().Model(&bills).Exec(ctx)
				fmt.Printf("Congress: %s Type: %s Inserted %s rows", strconv.Itoa(i), table, strconv.Itoa(len(bills)))
				if err != nil {
					panic(err)
				} else {
					fmt.Println(res)
				}
			}
		}
	}
	close(sem)
}

func update_bills() {
	os.Chdir("/congress")
	cmd := exec.Command("./congress/run.py", "govinfo", "--bulkdata=BILLSTATUS")
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		panic(err)
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		panic(err)
	}
	err = cmd.Start()
	if err != nil {
		panic(err)
	}
	go copyOutput(stdout)
	go copyOutput(stderr)
	cmd.Wait()

	cmd = exec.Command("./congress/run.py", "govinfo", "--bulkdata=BILLSTATUS", "--congress=117")
	stdout, err = cmd.StdoutPipe()
	if err != nil {
		panic(err)
	}
	stderr, err = cmd.StderrPipe()
	if err != nil {
		panic(err)
	}
	err = cmd.Start()
	if err != nil {
		panic(err)
	}
	go copyOutput(stdout)
	go copyOutput(stderr)
	cmd.Wait()
}

func copyOutput(r io.Reader) {
	scanner := bufio.NewScanner(r)
	for scanner.Scan() {
		fmt.Println(scanner.Text())
	}
}
