package main

import (
	"app/csearch/csearch"
	"bufio"
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/gob"
	"encoding/json"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"runtime/debug"
	"strconv"
	"strings"
	"sync"

	_ "github.com/lib/pq"
	"github.com/spf13/viper"
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

// BillXML covers congress < 114 (uses <billNumber>, <billType>)
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

// BillXMLnew covers congress >= 114 (uses <number>, <type>)
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

type BillXMLNN struct {
	Number string `xml:"number"`
}

// ── Parsed result ────────────────────────────────────────────────────────────

// ParsedBill holds the bill row plus all related rows extracted from one XML file.
type ParsedBill struct {
	Bill       csearch.InsertBillParams
	Actions    []csearch.InsertBillActionParams
	Cosponsors []csearch.InsertBillCosponsorParams
	Committees []csearch.InsertBillCommitteeParams
	Subjects   []csearch.InsertBillSubjectParams
}

// ── Legacy JSON format (data.json) ──────────────────────────────────────────

type BillJSON struct {
	Number       string
	BillType     string `json:"bill_type"`
	IntroducedAt string `json:"introduced_at"`
	Congress     string
	Summary      struct {
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

// ── Helper ───────────────────────────────────────────────────────────────────

// officialTitle extracts the official title from the <titles> list.
func officialTitle(titles TitlesXML) string {
	for _, t := range titles.Items {
		if strings.HasPrefix(t.TitleType, "Official Title") {
			return t.Title
		}
	}
	return ""
}

func nullStr(s string) sql.NullString {
	return sql.NullString{String: s, Valid: s != ""}
}

// ── Parsers ──────────────────────────────────────────────────────────────────

func parse_bill(path string) ParsedBill {
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
	bill := csearch.InsertBillParams{
		Billid:        nullStr(billID),
		Billnumber:    billjs.Number,
		Billtype:      strings.ToLower(billjs.BillType),
		Introducedat:  nullStr(billjs.IntroducedAt),
		Congress:      billjs.Congress,
		SummaryDate:   nullStr(billjs.Summary.Date),
		SummaryText:   nullStr(billjs.Summary.Text),
		SponsorName:   nullStr(sponsorName),
		SponsorState:  nullStr(billjs.Sponsor.State),
		SponsorParty:  nullStr(billjs.Sponsor.Party),
		Statusat:      billjs.StatusAt,
		Shorttitle:    nullStr(billjs.ShortTitle),
		Officialtitle: nullStr(billjs.OfficialTitle),
	}

	var actions []csearch.InsertBillActionParams
	for _, a := range billjs.Actions {
		actions = append(actions, csearch.InsertBillActionParams{
			Billtype:   strings.ToLower(billjs.BillType),
			Billnumber: billjs.Number,
			Congress:   billjs.Congress,
			ActedAt:    a.ActedAt,
			ActionText: nullStr(a.Text),
			ActionType: nullStr(a.Type),
		})
	}

	var cosponsors []csearch.InsertBillCosponsorParams
	for _, c := range billjs.Cosponsors {
		var name string
		if len(c.Title) > 0 {
			name = fmt.Sprintf("%s %s [%s]", c.Title, c.Name, c.State)
		} else {
			name = fmt.Sprintf("%s [%s]", c.Name, c.State)
		}
		// data.json has no bioguide_id; skip rows without a usable key
		if name == "" {
			continue
		}
		cosponsors = append(cosponsors, csearch.InsertBillCosponsorParams{
			Billtype:   strings.ToLower(billjs.BillType),
			Billnumber: billjs.Number,
			Congress:   billjs.Congress,
			BioguideId: name, // best available key in legacy format
			FullName:   nullStr(name),
			State:      nullStr(c.State),
			Party:      nullStr(c.Party),
		})
	}

	return ParsedBill{Bill: bill, Actions: actions, Cosponsors: cosponsors}
}

func parse_bill_xml(path string, congress int) ParsedBill {
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
		billtype := strings.ToLower(b.BillType)
		return buildParsedBill(
			b.Number, billtype, b.IntroducedAt, b.UpdateDate, b.OriginChamber,
			b.Congress, b.ShortTitle, b.LatestAction.ActionDate,
			b.Summary, b.Actions, b.Sponsors, b.Cosponsors,
			b.Titles, b.Committees, b.Subjects,
		)
	}

	var root BillXMLRootnew
	xml.Unmarshal(byteValue, &root)
	b := root.BillXML
	// <type> is the canonical field for congress >= 114; fall back to <billType>
	billtype := strings.ToLower(b.Type)
	if billtype == "" {
		billtype = strings.ToLower(b.BillType)
	}
	return buildParsedBill(
		b.Number, billtype, b.IntroducedAt, b.UpdateDate, b.OriginChamber,
		b.Congress, b.ShortTitle, b.LatestAction.ActionDate,
		b.Summary, b.Actions, b.Sponsors, b.Cosponsors,
		b.Titles, b.Committees, b.Subjects,
	)
}

func buildParsedBill(
	number, billtype, introducedAt, updateDate, originChamber, congress, shortTitle, latestActionDate string,
	summary XMLSummaries,
	actions ActionsXML,
	sponsors SponsorsXML,
	cosponsors CosponsorsXML,
	titles TitlesXML,
	committees CommitteesXML,
	subjects SubjectsXML,
) ParsedBill {
	billID := fmt.Sprintf("%s-%s-%s", congress, strings.ToUpper(billtype), number)

	// Summary — use first item
	var summaryDate, summaryText string
	if len(summary.XMLBillSummaries.XMLBillItems) > 0 {
		summaryDate = summary.XMLBillSummaries.XMLBillItems[0].Date
		summaryText = summary.XMLBillSummaries.XMLBillItems[0].Text
	}

	// Sponsor — always exactly one
	var sponsorBioguideId, sponsorName, sponsorState, sponsorParty string
	if len(sponsors.Sponsors) > 0 {
		s := sponsors.Sponsors[0]
		sponsorBioguideId = s.BioguideId
		sponsorName = s.FullName
		sponsorState = s.State
		sponsorParty = s.Party
	}

	// Official title from <titles> list
	official := officialTitle(titles)
	if official == "" {
		official = shortTitle
	}

	// statusat: use latestAction date; fall back to introducedAt
	statusAt := latestActionDate
	if statusAt == "" {
		statusAt = introducedAt
	}

	// Policy area (also stored at bill level, subjects table gets legislativeSubjects)
	policyArea := subjects.BillSubjects.PolicyArea.Name

	bill := csearch.InsertBillParams{
		Billid:             nullStr(billID),
		Billnumber:         number,
		Billtype:           billtype,
		Introducedat:       nullStr(introducedAt),
		Congress:           congress,
		SummaryDate:        nullStr(summaryDate),
		SummaryText:        nullStr(summaryText),
		SponsorBioguideId:  nullStr(sponsorBioguideId),
		SponsorName:        nullStr(sponsorName),
		SponsorState:       nullStr(sponsorState),
		SponsorParty:       nullStr(sponsorParty),
		OriginChamber:      nullStr(originChamber),
		PolicyArea:         nullStr(policyArea),
		UpdateDate:         nullStr(updateDate),
		Statusat:           statusAt,
		Shorttitle:         nullStr(shortTitle),
		Officialtitle:      nullStr(official),
	}

	// Actions
	var parsedActions []csearch.InsertBillActionParams
	for _, a := range actions.Actions {
		if a.ActedAt == "" {
			continue
		}
		parsedActions = append(parsedActions, csearch.InsertBillActionParams{
			Billtype:         billtype,
			Billnumber:       number,
			Congress:         congress,
			ActedAt:          a.ActedAt,
			ActionText:       nullStr(a.Text),
			ActionType:       nullStr(a.Type),
			ActionCode:       nullStr(a.ActionCode),
			SourceSystemCode: nullStr(a.SourceSystem.Code),
		})
	}

	// Cosponsors
	var parsedCosponsors []csearch.InsertBillCosponsorParams
	for _, c := range cosponsors.Cosponsors {
		if c.BioguideId == "" {
			continue
		}
		isOriginal := sql.NullBool{Bool: strings.EqualFold(c.IsOriginalCosponsor, "true"), Valid: c.IsOriginalCosponsor != ""}
		parsedCosponsors = append(parsedCosponsors, csearch.InsertBillCosponsorParams{
			Billtype:            billtype,
			Billnumber:          number,
			Congress:            congress,
			BioguideId:          c.BioguideId,
			FullName:            nullStr(c.FullName),
			State:               nullStr(c.State),
			Party:               nullStr(c.Party),
			SponsorshipDate:     nullStr(c.SponsorshipDate),
			IsOriginalCosponsor: isOriginal,
		})
	}

	// Committees
	var parsedCommittees []csearch.InsertBillCommitteeParams
	for _, c := range committees.BillCommittees.Items {
		if c.SystemCode == "" {
			continue
		}
		parsedCommittees = append(parsedCommittees, csearch.InsertBillCommitteeParams{
			Billtype:      billtype,
			Billnumber:    number,
			Congress:      congress,
			CommitteeCode: c.SystemCode,
			CommitteeName: nullStr(c.Name),
			Chamber:       nullStr(c.Chamber),
		})
	}

	// Subjects
	var parsedSubjects []csearch.InsertBillSubjectParams
	for _, s := range subjects.BillSubjects.LegislativeSubjects.Items {
		if s.Name == "" {
			continue
		}
		parsedSubjects = append(parsedSubjects, csearch.InsertBillSubjectParams{
			Billtype:   billtype,
			Billnumber: number,
			Congress:   congress,
			Subject:    s.Name,
		})
	}

	return ParsedBill{
		Bill:       bill,
		Actions:    parsedActions,
		Cosponsors: parsedCosponsors,
		Committees: parsedCommittees,
		Subjects:   parsedSubjects,
	}
}

// ── DB insertion ─────────────────────────────────────────────────────────────

func insertParsedBill(ctx context.Context, queries *csearch.Queries, pb ParsedBill) {
	err := queries.InsertBill(ctx, pb.Bill)
	if err != nil {
		fmt.Printf("InsertBill error: %v\n", err)
		return
	}

	key := csearch.DeleteBillActionsParams{
		Billtype:   pb.Bill.Billtype,
		Billnumber: pb.Bill.Billnumber,
		Congress:   pb.Bill.Congress,
	}
	queries.DeleteBillActions(ctx, key)
	for _, a := range pb.Actions {
		queries.InsertBillAction(ctx, a)
	}

	queries.DeleteBillCosponsors(ctx, csearch.DeleteBillCosponsorsParams(key))
	for _, c := range pb.Cosponsors {
		queries.InsertBillCosponsor(ctx, c)
	}

	queries.DeleteBillCommittees(ctx, csearch.DeleteBillCommitteesParams(key))
	for _, c := range pb.Committees {
		queries.InsertBillCommittee(ctx, c)
	}

	queries.DeleteBillSubjects(ctx, csearch.DeleteBillSubjectsParams(key))
	for _, s := range pb.Subjects {
		queries.InsertBillSubject(ctx, s)
	}
}

// ── Main ─────────────────────────────────────────────────────────────────────

func main() {
	viper.SetConfigFile(".env")
	err := viper.ReadInConfig()
	if err != nil {
		return
	}

	congressdir := viper.GetString("CONGRESSDIR")
	postgresURI := viper.GetString("POSTGRESURI")
	fileHashes := make(map[string]string)
	fileHashesMutex := sync.RWMutex{}
	fileHashesPath := congressdir + "./fileHashes.gob"
	processVotes()
	if _, err := os.Stat(fileHashesPath); err == nil {
		decodeFile, err := os.Open(fileHashesPath)
		if err != nil {
			panic(err)
		}
		defer decodeFile.Close()
		decoder := gob.NewDecoder(decodeFile)
		fileHashes = make(map[string]string)
		decoder.Decode(&fileHashes)
		println("Hashes Loaded")
	}
	updateBills()

	ctx := context.Background()
	db, err := sql.Open("postgres", "host="+postgresURI+" user=postgres password=postgres dbname=csearch sslmode=disable")
	if err != nil {
		panic(err)
	}
	queries := csearch.New(db)

	var wg sync.WaitGroup
	sem := make(chan struct{}, 64)
	for i := 93; i <= 118; i++ {
		for _, table := range Tables {
			var directory = fmt.Sprintf(congressdir+"data/%s/bills/%s", strconv.Itoa(i), table)
			files, err := os.ReadDir(directory)
			if err != nil {
				debug.PrintStack()
				continue
			}
			var parsedBills []ParsedBill
			var mu sync.Mutex
			wg.Add(len(files))
			fmt.Printf("Processing Congress %d; Type: %s, Number of Bills: %d \n", i, table, len(files))
			for _, f := range files {
				path := fmt.Sprintf(congressdir+"data/%s/bills/%s/", strconv.Itoa(i), table) + f.Name()
				jcheck := path + "/data.json"
				if _, err := os.Stat(jcheck); err == nil {
					go func() {
						defer wg.Done()
						defer func() { <-sem }()
						sem <- struct{}{}
						f, err := os.Open(jcheck)
						if err != nil {
							log.Fatal(err)
						}
						fileHash := sha256.New()
						io.Copy(fileHash, f)
						hashStr := fmt.Sprintf("%x", fileHash.Sum(nil))
						f.Close()
						fileHashesMutex.Lock()
						prev := fileHashes[jcheck]
						fileHashesMutex.Unlock()
						if prev != hashStr {
							fileHashesMutex.Lock()
							fileHashes[jcheck] = hashStr
							fileHashesMutex.Unlock()
							pb := parse_bill(jcheck)
							mu.Lock()
							parsedBills = append(parsedBills, pb)
							mu.Unlock()
						}
					}()
				} else if errors.Is(err, os.ErrNotExist) {
					xmlpath := path + "/fdsys_billstatus.xml"
					go func() {
						defer wg.Done()
						defer func() { <-sem }()
						sem <- struct{}{}
						f, err := os.Open(xmlpath)
						if err != nil {
							log.Fatal(err)
						}
						fileHash := sha256.New()
						io.Copy(fileHash, f)
						hashStr := fmt.Sprintf("%x", fileHash.Sum(nil))
						f.Close()
						fileHashesMutex.Lock()
						prev := fileHashes[xmlpath]
						fileHashesMutex.Unlock()
						if prev != hashStr {
							fileHashesMutex.Lock()
							fileHashes[xmlpath] = hashStr
							fileHashesMutex.Unlock()
							pb := parse_bill_xml(xmlpath, i)
							mu.Lock()
							parsedBills = append(parsedBills, pb)
							mu.Unlock()
						}
					}()
				} else {
					wg.Done()
				}
			}
			wg.Wait()

			for _, pb := range parsedBills {
				insertParsedBill(ctx, queries, pb)
			}
		}
	}

	encodeFile, err := os.Create(fileHashesPath)
	if err != nil {
		panic(err)
	}
	encoder := gob.NewEncoder(encodeFile)
	if err := encoder.Encode(fileHashes); err != nil {
		panic(err)
	}
	encodeFile.Close()
	close(sem)
}

func updateBills() {
	var congressdir = viper.GetString("CONGRESSDIR")
	os.Chdir(congressdir)

	cmd := exec.Command(congressdir+"congress/run.py", "govinfo", "--bulkdata=BILLSTATUS")
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

	cmd = exec.Command("./congress/run.py", "govinfo", "--bulkdata=BILLSTATUS", "--congress=118")
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

	cmd = exec.Command("./congress/run.py", "bills")
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
