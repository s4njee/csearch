package main

import (
	"app/csearch/csearch"
	"context"
	"database/sql"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"
)

var billTables = []string{"s", "hr", "hconres", "hjres", "hres", "sconres", "sjres", "sres"}

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

type CommitteesXML struct {
	XMLName xml.Name           `xml:"committees"`
	Items   []CommitteeItemXML `xml:"item"`
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

type SubjectsXML struct {
	XMLName             xml.Name               `xml:"subjects"`
	LegislativeSubjects LegislativeSubjectsXML `xml:"legislativeSubjects"`
	PolicyArea          PolicyAreaXML          `xml:"policyArea"`
}

type LatestActionXML struct {
	XMLName    xml.Name `xml:"latestAction"`
	ActionDate string   `xml:"actionDate"`
	Text       string   `xml:"text"`
}

// BillXML covers congresses prior to 114 where the XML payload uses
// <billNumber> plus <billType>.
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

// BillXMLNew covers congress 114+ where <type> is the canonical bill type.
type BillXMLNew struct {
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

type BillXMLRootNew struct {
	XMLName xml.Name   `xml:"billStatus"`
	BillXML BillXMLNew `xml:"bill"`
}

// ParsedBill groups the parent bill row with all normalized child rows so the
// insert path can stay transactional at the bill level.
type ParsedBill struct {
	Bill             csearch.InsertBillParams
	Actions          []csearch.InsertBillActionParams
	Cosponsors       []csearch.InsertBillCosponsorParams
	Committees       []ParsedCommittee
	Subjects         []csearch.InsertBillSubjectParams
	LatestActionDate time.Time
	LatestActionText string
}

type ParsedCommittee struct {
	CommitteeCode string
	CommitteeName string
	Chamber       string
}

// BillJSON is the legacy data.json shape emitted by the older scraper path.
// We still support it because some congress folders have not been normalized to
// XML yet, so agents should preserve this fallback unless the source data
// migration is handled separately.
type BillJSON struct {
	Number       string
	BillType     string `json:"bill_type"`
	IntroducedAt string `json:"introduced_at"`
	Congress     string
	Status       string `json:"status"`
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

type billJob struct {
	Path    string
	Parse   func(string) (ParsedBill, error)
	Display string
}

func nullStr(value string) sql.NullString {
	return sql.NullString{String: value, Valid: value != ""}
}

func nullTime(value time.Time) sql.NullTime {
	if value.IsZero() {
		return sql.NullTime{}
	}
	return sql.NullTime{Time: value, Valid: true}
}

func nullInt32(value int32) sql.NullInt32 {
	if value == 0 {
		return sql.NullInt32{}
	}
	return sql.NullInt32{Int32: value, Valid: true}
}

func parseDateValue(value string) (time.Time, error) {
	if value == "" {
		return time.Time{}, nil
	}

	layouts := []string{
		"2006-01-02",
		time.RFC3339,
		"2006-01-02 15:04:05",
	}
	for _, layout := range layouts {
		if parsed, err := time.Parse(layout, value); err == nil {
			return parsed.UTC(), nil
		}
	}

	return time.Time{}, fmt.Errorf("invalid date %q", value)
}

func mustParseDateValue(value string) time.Time {
	parsed, err := parseDateValue(value)
	if err != nil {
		return time.Time{}
	}
	return parsed
}

func parseInt32Value(value string) (int32, error) {
	parsed, err := strconv.ParseInt(value, 10, 32)
	if err != nil {
		return 0, err
	}
	return int32(parsed), nil
}

func mustParseInt32Value(value string) int32 {
	parsed, err := parseInt32Value(value)
	if err != nil {
		return 0
	}
	return parsed
}

func officialTitle(titles TitlesXML) string {
	for _, title := range titles.Items {
		if strings.HasPrefix(title.TitleType, "Official Title") {
			return title.Title
		}
	}
	return ""
}

func latestJSONAction(actions []struct {
	ActedAt string `json:"acted_at"`
	Text    string
	Type    string
}) (string, string) {
	var latestDate string
	var latestText string
	for _, action := range actions {
		if action.ActedAt == "" {
			continue
		}
		if latestDate == "" || action.ActedAt > latestDate {
			latestDate = action.ActedAt
			latestText = action.Text
		}
	}
	return latestDate, latestText
}

func deriveBillStatus(latestActionText string) string {
	text := strings.ToLower(latestActionText)
	switch {
	case text == "":
		return "introduced"
	case strings.Contains(text, "enact"):
		return "enacted"
	case strings.Contains(text, "veto"):
		return "vetoed"
	case strings.Contains(text, "pass"):
		return "passed"
	case strings.Contains(text, "report"):
		return "reported"
	case strings.Contains(text, "refer"):
		return "referred"
	case strings.Contains(text, "introduc"):
		return "introduced"
	default:
		return "active"
	}
}

func normalizeBillStatus(rawStatus, latestActionText string) string {
	status := strings.ToLower(strings.TrimSpace(rawStatus))
	switch {
	case status == "":
		return deriveBillStatus(latestActionText)
	case strings.Contains(status, "enact"):
		return "enacted"
	case strings.Contains(status, "veto"):
		return "vetoed"
	case strings.Contains(status, "pass"):
		return "passed"
	case strings.Contains(status, "report"):
		return "reported"
	case strings.Contains(status, "refer"):
		return "referred"
	case strings.Contains(status, "introduc"):
		return "introduced"
	case strings.Contains(status, "active"):
		return "active"
	default:
		return deriveBillStatus(latestActionText)
	}
}

func billStatusFromSidecar(path string) string {
	sidecarPath := filepath.Join(filepath.Dir(path), "data.json")
	if !fileExists(sidecarPath) {
		return ""
	}

	data, err := os.ReadFile(sidecarPath)
	if err != nil {
		return ""
	}

	var billJSON BillJSON
	if err := json.Unmarshal(data, &billJSON); err != nil {
		return ""
	}

	return billJSON.Status
}

func latestXMLAction(actions ActionsXML) (string, string) {
	var latestDate string
	var latestText string
	for _, action := range actions.Actions {
		if action.ActedAt == "" {
			continue
		}
		if latestDate == "" || action.ActedAt > latestDate {
			latestDate = action.ActedAt
			latestText = action.Text
		}
	}
	return latestDate, latestText
}

// parseBillJSON converts a legacy data.json file into a ParsedBill.
func parseBillJSON(path string) (ParsedBill, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return ParsedBill{}, err
	}

	var billJSON BillJSON
	if err := json.Unmarshal(data, &billJSON); err != nil {
		return ParsedBill{}, err
	}

	sponsorName := fmt.Sprintf("%s [%s]", billJSON.Sponsor.Name, billJSON.Sponsor.State)
	if billJSON.Sponsor.Title != "" {
		sponsorName = fmt.Sprintf("%s %s [%s]", billJSON.Sponsor.Title, billJSON.Sponsor.Name, billJSON.Sponsor.State)
	}

	latestActionDate, latestActionText := latestJSONAction(billJSON.Actions)
	parsedIntroducedAt, err := parseDateValue(billJSON.IntroducedAt)
	if err != nil {
		return ParsedBill{}, fmt.Errorf("parse introduced date for %s: %w", path, err)
	}
	parsedStatusAt, err := parseDateValue(billJSON.StatusAt)
	if err != nil {
		return ParsedBill{}, fmt.Errorf("parse status date for %s: %w", path, err)
	}
	parsedLatestActionDate, err := parseDateValue(latestActionDate)
	if err != nil {
		return ParsedBill{}, fmt.Errorf("parse latest action date for %s: %w", path, err)
	}
	statusAt := parsedStatusAt
	if statusAt.IsZero() {
		statusAt = parsedLatestActionDate
	}
	if statusAt.IsZero() {
		statusAt = parsedIntroducedAt
	}
	if statusAt.IsZero() {
		return ParsedBill{}, fmt.Errorf("missing status date for %s", path)
	}

	billNumber, err := parseInt32Value(billJSON.Number)
	if err != nil {
		return ParsedBill{}, fmt.Errorf("parse bill number for %s: %w", path, err)
	}
	congress, err := parseInt32Value(billJSON.Congress)
	if err != nil {
		return ParsedBill{}, fmt.Errorf("parse congress for %s: %w", path, err)
	}

	billID := fmt.Sprintf("%d-%s-%d", congress, billJSON.BillType, billNumber)
	bill := csearch.InsertBillParams{
		Billid:        nullStr(billID),
		Billnumber:    billNumber,
		Billtype:      strings.ToLower(billJSON.BillType),
		Introducedat:  nullTime(parsedIntroducedAt),
		Congress:      congress,
		SummaryDate:   nullStr(billJSON.Summary.Date),
		SummaryText:   nullStr(billJSON.Summary.Text),
		SponsorName:   nullStr(sponsorName),
		SponsorState:  nullStr(billJSON.Sponsor.State),
		SponsorParty:  nullStr(billJSON.Sponsor.Party),
		BillStatus:    normalizeBillStatus(billJSON.Status, latestActionText),
		Statusat:      statusAt,
		Shorttitle:    nullStr(billJSON.ShortTitle),
		Officialtitle: nullStr(billJSON.OfficialTitle),
	}

	actions := make([]csearch.InsertBillActionParams, 0, len(billJSON.Actions))
	for _, action := range billJSON.Actions {
		actedAt, err := parseDateValue(action.ActedAt)
		if err != nil {
			return ParsedBill{}, fmt.Errorf("parse action date for %s: %w", path, err)
		}
		actions = append(actions, csearch.InsertBillActionParams{
			Billtype:   strings.ToLower(billJSON.BillType),
			Billnumber: billNumber,
			Congress:   congress,
			ActedAt:    actedAt,
			ActionText: nullStr(action.Text),
			ActionType: nullStr(action.Type),
		})
	}

	cosponsors := make([]csearch.InsertBillCosponsorParams, 0, len(billJSON.Cosponsors))
	for _, cosponsor := range billJSON.Cosponsors {
		name := fmt.Sprintf("%s [%s]", cosponsor.Name, cosponsor.State)
		if cosponsor.Title != "" {
			name = fmt.Sprintf("%s %s [%s]", cosponsor.Title, cosponsor.Name, cosponsor.State)
		}
		if name == "" {
			continue
		}

		cosponsors = append(cosponsors, csearch.InsertBillCosponsorParams{
			Billtype:   strings.ToLower(billJSON.BillType),
			Billnumber: billNumber,
			Congress:   congress,
			// Legacy JSON payloads do not include a real Bioguide ID, so leave this
			// empty rather than populating a broken member link target.
			BioguideID: "",
			FullName:   nullStr(name),
			State:      nullStr(cosponsor.State),
			Party:      nullStr(cosponsor.Party),
		})
	}

	return ParsedBill{
		Bill:             bill,
		Actions:          actions,
		Cosponsors:       cosponsors,
		LatestActionDate: parsedLatestActionDate,
		LatestActionText: latestActionText,
	}, nil
}

// parseBillXML reads an fdsys_billstatus.xml file and translates it into a
// ParsedBill, normalizing differences between old and new XML schemas.
//
// We always try the new schema first (which uses <number> and <type>) since
// GovInfo has republished some pre-113 bulk data using the newer format.
// We fall back to the legacy schema (<billNumber> and <billType>) only when
// the new schema yields no usable bill number.
func parseBillXML(path string) (ParsedBill, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return ParsedBill{}, err
	}

	// Always try the new schema first — GovInfo uses it for all congresses
	// in recent bulk-data publications, including pre-113 re-publications.
	var rootNew BillXMLRootNew
	if err := xml.Unmarshal(data, &rootNew); err != nil {
		return ParsedBill{}, err
	}

	bill := rootNew.BillXML
	billType := strings.ToLower(bill.Type)
	if billType == "" {
		billType = strings.ToLower(bill.BillType)
	}
	billStatus := billStatusFromSidecar(path)

	if bill.Number != "" {
		billNumber, err := parseInt32Value(bill.Number)
		if err != nil {
			return ParsedBill{}, fmt.Errorf("parse bill number for %s: %w", path, err)
		}
		congress, err := parseInt32Value(bill.Congress)
		if err != nil {
			return ParsedBill{}, fmt.Errorf("parse congress for %s: %w", path, err)
		}
		return buildParsedBill(
			billNumber,
			billType,
			bill.IntroducedAt,
			bill.UpdateDate,
			bill.OriginChamber,
			congress,
			bill.ShortTitle,
			bill.LatestAction.ActionDate,
			bill.LatestAction.Text,
			bill.Summary,
			bill.Actions,
			bill.Sponsors,
			bill.Cosponsors,
			bill.Titles,
			bill.Committees,
			bill.Subjects,
			billStatus,
		), nil
	}

	// Fall back to the legacy schema (<billNumber> / <billType>).
	var rootLegacy BillXMLRoot
	if err := xml.Unmarshal(data, &rootLegacy); err != nil {
		return ParsedBill{}, err
	}

	legacyBill := rootLegacy.BillXML
	legacyNumber, err := parseInt32Value(legacyBill.Number)
	if err != nil {
		return ParsedBill{}, fmt.Errorf("parse bill number for %s: %w", path, err)
	}
	legacyCongress, err := parseInt32Value(legacyBill.Congress)
	if err != nil {
		return ParsedBill{}, fmt.Errorf("parse congress for %s: %w", path, err)
	}
	return buildParsedBill(
		legacyNumber,
		strings.ToLower(legacyBill.BillType),
		legacyBill.IntroducedAt,
		legacyBill.UpdateDate,
		legacyBill.OriginChamber,
		legacyCongress,
		legacyBill.ShortTitle,
		legacyBill.LatestAction.ActionDate,
		legacyBill.LatestAction.Text,
		legacyBill.Summary,
		legacyBill.Actions,
		legacyBill.Sponsors,
		legacyBill.Cosponsors,
		legacyBill.Titles,
		legacyBill.Committees,
		legacyBill.Subjects,
		billStatus,
	), nil
}

func buildParsedBill(
	number int32,
	billType string,
	introducedAt string,
	updateDate string,
	originChamber string,
	congress int32,
	shortTitle string,
	latestActionDate string,
	latestActionText string,
	summary XMLSummaries,
	actions ActionsXML,
	sponsors SponsorsXML,
	cosponsors CosponsorsXML,
	titles TitlesXML,
	committees CommitteesXML,
	subjects SubjectsXML,
	billStatus string,
) ParsedBill {
	billID := fmt.Sprintf("%d-%s-%d", congress, strings.ToUpper(billType), number)

	derivedLatestActionDate, derivedLatestActionText := latestXMLAction(actions)
	if latestActionDate == "" {
		latestActionDate = derivedLatestActionDate
	}
	if latestActionText == "" {
		latestActionText = derivedLatestActionText
	}

	parsedIntroducedAt, err := parseDateValue(introducedAt)
	if err != nil {
		parsedIntroducedAt = time.Time{}
	}
	parsedUpdateDate, err := parseDateValue(updateDate)
	if err != nil {
		parsedUpdateDate = time.Time{}
	}
	parsedLatestActionDate, err := parseDateValue(latestActionDate)
	if err != nil {
		parsedLatestActionDate = time.Time{}
	}

	var summaryDate string
	var summaryText string
	if len(summary.XMLBillSummaries.XMLBillItems) > 0 {
		summaryDate = summary.XMLBillSummaries.XMLBillItems[0].Date
		summaryText = summary.XMLBillSummaries.XMLBillItems[0].Text
	}

	var sponsorBioguideID string
	var sponsorName string
	var sponsorState string
	var sponsorParty string
	if len(sponsors.Sponsors) > 0 {
		sponsor := sponsors.Sponsors[0]
		sponsorBioguideID = sponsor.BioguideId
		sponsorName = sponsor.FullName
		sponsorState = sponsor.State
		sponsorParty = sponsor.Party
	}

	official := officialTitle(titles)
	if official == "" {
		official = shortTitle
	}

	statusAt := parsedLatestActionDate
	if statusAt.IsZero() {
		statusAt = parsedIntroducedAt
	}
	if statusAt.IsZero() {
		statusAt = mustParseDateValue(introducedAt)
	}

	bill := csearch.InsertBillParams{
		Billid:            nullStr(billID),
		Billnumber:        number,
		Billtype:          billType,
		Introducedat:      nullTime(parsedIntroducedAt),
		Congress:          congress,
		SummaryDate:       nullStr(summaryDate),
		SummaryText:       nullStr(summaryText),
		SponsorBioguideID: nullStr(sponsorBioguideID),
		SponsorName:       nullStr(sponsorName),
		SponsorState:      nullStr(sponsorState),
		SponsorParty:      nullStr(sponsorParty),
		BillStatus:        normalizeBillStatus(billStatus, latestActionText),
		OriginChamber:     nullStr(originChamber),
		PolicyArea:        nullStr(subjects.PolicyArea.Name),
		UpdateDate:        nullTime(parsedUpdateDate),
		LatestActionDate:  nullTime(parsedLatestActionDate),
		Statusat:          statusAt,
		Shorttitle:        nullStr(shortTitle),
		Officialtitle:     nullStr(official),
	}

	parsedActions := make([]csearch.InsertBillActionParams, 0, len(actions.Actions))
	for _, action := range actions.Actions {
		if action.ActedAt == "" {
			continue
		}
		actedAt, err := parseDateValue(action.ActedAt)
		if err != nil {
			continue
		}

		parsedActions = append(parsedActions, csearch.InsertBillActionParams{
			Billtype:         billType,
			Billnumber:       number,
			Congress:         congress,
			ActedAt:          actedAt,
			ActionText:       nullStr(action.Text),
			ActionType:       nullStr(action.Type),
			ActionCode:       nullStr(action.ActionCode),
			SourceSystemCode: nullStr(action.SourceSystem.Code),
		})
	}

	parsedCosponsors := make([]csearch.InsertBillCosponsorParams, 0, len(cosponsors.Cosponsors))
	for _, cosponsor := range cosponsors.Cosponsors {
		if cosponsor.BioguideId == "" {
			continue
		}

		parsedCosponsors = append(parsedCosponsors, csearch.InsertBillCosponsorParams{
			Billtype:            billType,
			Billnumber:          number,
			Congress:            congress,
			BioguideID:          cosponsor.BioguideId,
			FullName:            nullStr(cosponsor.FullName),
			State:               nullStr(cosponsor.State),
			Party:               nullStr(cosponsor.Party),
			SponsorshipDate:     nullTime(mustParseDateValue(cosponsor.SponsorshipDate)),
			IsOriginalCosponsor: sql.NullBool{Bool: strings.EqualFold(cosponsor.IsOriginalCosponsor, "true"), Valid: cosponsor.IsOriginalCosponsor != ""},
		})
	}

	parsedCommittees := make([]ParsedCommittee, 0, len(committees.Items))
	for _, committee := range committees.Items {
		if committee.SystemCode == "" {
			continue
		}

		parsedCommittees = append(parsedCommittees, ParsedCommittee{
			CommitteeCode: committee.SystemCode,
			CommitteeName: committee.Name,
			Chamber:       committee.Chamber,
		})
	}

	parsedSubjects := make([]csearch.InsertBillSubjectParams, 0, len(subjects.LegislativeSubjects.Items))
	for _, subject := range subjects.LegislativeSubjects.Items {
		if subject.Name == "" {
			continue
		}

		parsedSubjects = append(parsedSubjects, csearch.InsertBillSubjectParams{
			Billtype:   billType,
			Billnumber: number,
			Congress:   congress,
			Subject:    subject.Name,
		})
	}

	return ParsedBill{
		Bill:             bill,
		Actions:          parsedActions,
		Cosponsors:       parsedCosponsors,
		Committees:       parsedCommittees,
		Subjects:         parsedSubjects,
		LatestActionDate: parsedLatestActionDate,
		LatestActionText: latestActionText,
	}
}

// processBills handles the discovery, parsing, and database insertion of all
// bills for all supported congresses.
func processBills(ctx context.Context, db *sql.DB, queries *csearch.Queries, cfg appConfig, hashes *fileHashStore) error {
	for congress := 93; congress <= currentCongress(); congress++ {
		for _, table := range billTables {
			jobs, err := billJobsForTable(cfg, congress, table)
			if err != nil {
				log.Printf("skipping congress %d %s: %v", congress, table, err)
				continue
			}

			log.Printf("processing congress %d bill type %s (%d candidates)", congress, table, len(jobs))
			var wg sync.WaitGroup
			sem := make(chan struct{}, dbWriteConcurrency)
			for _, job := range jobs {
				job := job
				wg.Add(1)
				go func() {
					defer wg.Done()

					sem <- struct{}{}
					defer func() { <-sem }()

					hash, changed, err := hashes.NeedsProcessing(job.Path)
					if err != nil {
						log.Printf("unable to hash %s: %v", job.Path, err)
						return
					}
					if !changed {
						return
					}

					parsedBill, err := job.Parse(job.Path)
					if err != nil {
						log.Printf("unable to parse bill %s: %v", job.Display, err)
						return
					}

					if err := insertParsedBill(ctx, db, queries, parsedBill); err != nil {
						log.Printf("unable to insert bill %s: %v", job.Display, err)
						return
					}
					hashes.MarkProcessed(job.Path, hash)
				}()
			}
			wg.Wait()
		}
	}

	return nil
}

// billJobsForTable scans the given congress and bill type directory to
// find parseable bill payloads (either XML or legacy JSON).
func billJobsForTable(cfg appConfig, congress int, table string) ([]billJob, error) {
	directory := filepath.Join(cfg.CongressDir, "congress", "data", fmt.Sprintf("%d", congress), "bills", table)
	entries, err := os.ReadDir(directory)
	if err != nil {
		return nil, err
	}

	jobs := make([]billJob, 0, len(entries))
	for _, entry := range entries {
		base := filepath.Join(directory, entry.Name())

		// Prefer XML when available — it carries richer fields (bioguide IDs,
		// committees, subjects, policy area). Fall back to JSON for older
		// congresses that were never published in GovInfo bulk-data XML.
		xmlPath := filepath.Join(base, "fdsys_billstatus.xml")
		if fileExists(xmlPath) {
			jobs = append(jobs, billJob{
				Path:    xmlPath,
				Parse:   parseBillXML,
				Display: filepath.Base(base),
			})
			continue
		}

		jsonPath := filepath.Join(base, "data.json")
		if !fileExists(jsonPath) {
			continue
		}

		jobs = append(jobs, billJob{
			Path:    jsonPath,
			Parse:   parseBillJSON,
			Display: filepath.Base(base),
		})
	}

	return jobs, nil
}

// insertParsedBill transactionally inserts a parsed bill and its child records.
// It upserts the parent bill and replaces all child records.
func insertParsedBill(ctx context.Context, db *sql.DB, queries *csearch.Queries, parsedBill ParsedBill) error {
	b := parsedBill.Bill
	if b.Billnumber == 0 || b.Billtype == "" {
		return fmt.Errorf("skipping bill with empty number/type (congress=%d, id=%s) — likely XML schema mismatch", b.Congress, b.Billid.String)
	}
	if b.BillStatus == "" {
		return fmt.Errorf("skipping bill %d-%s-%d: bill_status is empty", b.Congress, b.Billtype, b.Billnumber)
	}
	if b.Statusat.IsZero() {
		return fmt.Errorf("skipping bill %d-%s-%d: statusat is empty", b.Congress, b.Billtype, b.Billnumber)
	}

	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("BeginTx failed for %d-%s-%d: %w", parsedBill.Bill.Congress, parsedBill.Bill.Billtype, parsedBill.Bill.Billnumber, err)
	}
	defer tx.Rollback()

	q := queries.WithTx(tx)

	if err := q.InsertBill(ctx, parsedBill.Bill); err != nil {
		return fmt.Errorf("InsertBill failed for %d-%s-%d: %w", parsedBill.Bill.Congress, parsedBill.Bill.Billtype, parsedBill.Bill.Billnumber, err)
	}

	key := csearch.DeleteBillActionsParams{
		Billtype:   parsedBill.Bill.Billtype,
		Billnumber: parsedBill.Bill.Billnumber,
		Congress:   parsedBill.Bill.Congress,
	}

	// Clear latest_action_id before deleting actions to avoid the FK ON DELETE SET NULL
	// cascade failing on the partitioned bills table in PostgreSQL 15.
	if err := q.ClearBillLatestAction(ctx, csearch.ClearBillLatestActionParams{
		Billtype:         key.Billtype,
		Billnumber:       key.Billnumber,
		Congress:         key.Congress,
		LatestActionDate: nullTime(parsedBill.LatestActionDate),
	}); err != nil {
		return fmt.Errorf("ClearBillLatestAction failed: %w", err)
	}

	if err := q.DeleteBillActions(ctx, key); err != nil {
		return fmt.Errorf("DeleteBillActions failed: %w", err)
	}
	var latestActionID int64
	for _, action := range parsedBill.Actions {
		actionID, err := q.InsertBillAction(ctx, action)
		if err != nil {
			return fmt.Errorf("InsertBillAction failed: %w", err)
		}
		if !parsedBill.LatestActionDate.IsZero() && action.ActedAt.Equal(parsedBill.LatestActionDate) {
			if latestActionID == 0 || action.ActionText.String == parsedBill.LatestActionText {
				latestActionID = actionID
			}
		}
	}
	if latestActionID != 0 {
		if err := q.UpdateBillLatestAction(ctx, csearch.UpdateBillLatestActionParams{
			Billtype:         key.Billtype,
			Billnumber:       key.Billnumber,
			Congress:         key.Congress,
			LatestActionID:   sql.NullInt64{Int64: latestActionID, Valid: true},
			LatestActionDate: nullTime(parsedBill.LatestActionDate),
		}); err != nil {
			return fmt.Errorf("UpdateBillLatestAction failed: %w", err)
		}
	}

	cosponsorKey := csearch.DeleteBillCosponsorsParams(key)
	if err := q.DeleteBillCosponsors(ctx, cosponsorKey); err != nil {
		return fmt.Errorf("DeleteBillCosponsors failed: %w", err)
	}
	for _, cosponsor := range parsedBill.Cosponsors {
		if err := q.InsertBillCosponsor(ctx, cosponsor); err != nil {
			return fmt.Errorf("InsertBillCosponsor failed: %w", err)
		}
	}

	for _, committee := range parsedBill.Committees {
		if err := q.InsertCommittee(ctx, csearch.InsertCommitteeParams{
			CommitteeCode: committee.CommitteeCode,
			CommitteeName: nullStr(committee.CommitteeName),
			Chamber:       nullStr(committee.Chamber),
		}); err != nil {
			return fmt.Errorf("InsertCommittee failed: %w", err)
		}
	}

	committeeKey := csearch.DeleteBillCommitteesParams(key)
	if err := q.DeleteBillCommittees(ctx, committeeKey); err != nil {
		return fmt.Errorf("DeleteBillCommittees failed: %w", err)
	}
	for _, committee := range parsedBill.Committees {
		if err := q.InsertBillCommittee(ctx, csearch.InsertBillCommitteeParams{
			Billtype:      parsedBill.Bill.Billtype,
			Billnumber:    parsedBill.Bill.Billnumber,
			Congress:      parsedBill.Bill.Congress,
			CommitteeCode: committee.CommitteeCode,
		}); err != nil {
			return fmt.Errorf("InsertBillCommittee failed: %w", err)
		}
	}

	subjectKey := csearch.DeleteBillSubjectsParams(key)
	if err := q.DeleteBillSubjects(ctx, subjectKey); err != nil {
		return fmt.Errorf("DeleteBillSubjects failed: %w", err)
	}
	for _, subject := range parsedBill.Subjects {
		if err := q.InsertBillSubject(ctx, subject); err != nil {
			return fmt.Errorf("InsertBillSubject failed: %w", err)
		}
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("Commit failed for %d-%s-%d: %w", parsedBill.Bill.Congress, parsedBill.Bill.Billtype, parsedBill.Bill.Billnumber, err)
	}

	return nil
}

func updateBills(cfg appConfig) error {
	return runCongressTask(cfg, "govinfo", "--bulkdata=BILLSTATUS", fmt.Sprintf("--congress=%d", currentCongress()))
}

// fileExists checks whether a file exists and is accessible.
func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
