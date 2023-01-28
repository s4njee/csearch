package main

import (
	"bufio"
	"context"
	"app/csearch/csearch"
	"crypto/sha256"
	"database/sql"
	"encoding/gob"
	"encoding/json"
	"encoding/xml"
	"errors"
	"fmt"
	"github.com/jackc/pgtype"
	"github.com/jackc/pgx/v4"
	_ "github.com/lib/pq"
	"io"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"runtime/debug"
	"strconv"
	"strings"
	"sync"
	"github.com/spf13/viper"
)

var Tables = [8]string{"s", "hr", "hconres", "hjres", "hres", "sconres", "sjres", "sres"}

// var mutex = &sync.Mutex{}

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
type BillXMLRoot struct {
	XMLName xml.Name `xml:"billStatus"`
	BillXML BillXML  `xml:"bill"`
}
type BillXMLRootnew struct {
	XMLName xml.Name   `xml:"billStatus"`
	BillXML BillXMLnew `xml:"bill"`
}
type ItemXML struct {
	XMLName xml.Name `xml:"item"`
	ActedAt string   `xml:"actionDate"`
	Text    string   `xml:"text"`
	Type    string   `xml:"type"`
}
type ActionsXML struct {
	XMLName xml.Name  `xml:"actions"`
	Actions []ItemXML `xml:"item"`
}
type SponsorXML struct {
	XMLName  xml.Name `xml:"item"`
	FullName string   `xml:"fullName"`
	State    string   `xml:"state"`
	Party    string   `xml:"party"`
}
type SponsorsXML struct {
	XMLName  xml.Name     `xml:"sponsors"`
	Sponsors []SponsorXML `xml:"item"`
}
type CosponsorXML struct {
	XMLName  xml.Name `xml:"item"`
	FullName string   `xml:"fullName"`
	State    string   `xml:"state"`
	Party    string   `xml:"party"`
}
type CosponsorsXML struct {
	XMLName    xml.Name     `xml:"cosponsors"`
	Cosponsors []SponsorXML `xml:"item"`
}
type BillXML struct {
	XMLName      xml.Name      `xml:"bill"`
	Number       string        `xml:"billNumber"`
	BillType     string        `xml:"billType"`
	IntroducedAt string        `xml:"introducedDate"`
	Congress     string        `xml:"congress"`
	Summary      XMLSummaries  `xml:"summaries"`
	Actions      ActionsXML    `xml:"actions"`
	Sponsors     SponsorsXML   `xml:"sponsors"`
	Cosponsors   CosponsorsXML `xml:"cosponsors"`
	ShortTitle   string        `xml:"title"`
	Type         string        `xml:"type"`
}
type BillXMLnew struct {
	XMLName      xml.Name      `xml:"bill"`
	Number       string        `xml:"number"`
	BillType     string        `xml:"billType"`
	IntroducedAt string        `xml:"introducedDate"`
	Congress     string        `xml:"congress"`
	Summary      XMLSummaries  `xml:"summaries"`
	Actions      ActionsXML    `xml:"actions"`
	Sponsors     SponsorsXML   `xml:"sponsors"`
	Cosponsors   CosponsorsXML `xml:"cosponsors"`
	ShortTitle   string        `xml:"title"`
	Type         string        `xml:"type"`
}
type BillXMLNN struct {
	Number string `xml:"number"`
}
type Bill struct {
	BillID        string
	Number        string
	BillType      string `json:"bill_type"`
	IntroducedAt  string `json:"introduced_at"`
	Congress      string
	Summary       []byte
	Actions       []byte
	Sponsors      []byte
	Cosponsors    []byte
	StatusAt      string `json:"status_at""`
	ShortTitle    string `json:"short_title"`
	OfficialTitle string `json:"official_title"`
}

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

	StatusAt      string `json:"status_at""`
	ShortTitle    string `json:"short_title"`
	OfficialTitle string `json:"official_title"`
}

func parse_bill(path string) csearch.InsertBillParams {
	jsonFile, err := os.Open(path)
	if err != nil {
		fmt.Println(err)
	}
	defer jsonFile.Close()

	byteValue, _ := ioutil.ReadAll(jsonFile)
	var billjs BillJSON

	json.Unmarshal(byteValue, &billjs)

	var action_structs []struct {
		ActedAt string
		Text    string
		Type    string
	}

	for _, action := range billjs.Actions {
		action_structs = append(action_structs, struct {
			ActedAt string
			Text    string
			Type    string
		}{
			ActedAt: action.ActedAt,
			Text:    action.Text,
			Type:    action.Type,
		})
	}
	var sponsor_structs []struct {
		Title    string `json:"omitempty"`
		Name     string
		State    string
		District string `json:"omitempty"`
		Party    string `json:"omitempty"`
	}

	var Name string
	if len(billjs.Sponsor.Title) > 0 {
		Name = fmt.Sprintf("%s %s [%s]", billjs.Sponsor.Title, billjs.Sponsor.Name, billjs.Sponsor.State)
	} else {
		Name = fmt.Sprintf("%s [%s]", billjs.Sponsor.Name, billjs.Sponsor.State)
	}
	sponsor_structs = append(sponsor_structs, struct {
		Title    string `json:"omitempty"`
		Name     string
		State    string
		District string `json:"omitempty"`
		Party    string `json:"omitempty"`
	}{
		Name:  Name,
		State: billjs.Sponsor.State,
		Party: billjs.Sponsor.Party,
	})

	var cosponsor_structs []struct {
		Title    string `json:"omitempty"`
		Name     string
		State    string
		District string `json:"omitempty"`
		Party    string `json:"omitempty"`
	}

	for _, cosponsor := range billjs.Cosponsors {
		var Name string
		if len(cosponsor.Title) > 0 {
			Name = fmt.Sprintf("%s %s [%s]", cosponsor.Title, cosponsor.Name, cosponsor.State)
		} else {
			Name = fmt.Sprintf("%s [%s]", cosponsor.Name, cosponsor.State)
		}
		cosponsor_structs = append(cosponsor_structs, struct {
			Title    string `json:"omitempty"`
			Name     string
			State    string
			District string `json:"omitempty"`
			Party    string `json:"omitempty"`
		}{
			Name:  Name,
			State: cosponsor.State,
			Party: cosponsor.Party,
		})
	}
	summaryjs, err := json.Marshal(billjs.Summary)
	if err != nil {
		panic(err)
	}
	actionsjs, err := json.Marshal(action_structs)
	if err != nil {
		panic(err)
	}
	sponsorsjs, err := json.Marshal(sponsor_structs)
	if err != nil {
		panic(err)
	}
	cosponsorsjs, err := json.Marshal(cosponsor_structs)
	if err != nil {
		panic(err)
	}
	billID := fmt.Sprintf("%s-%s-%s", billjs.Congress, billjs.BillType, billjs.Number)
	// Create Bill Struct, same fields as BillJSON
	var bill = csearch.InsertBillParams{
		Billid:        sql.NullString{String: billID, Valid: true},
		Billnumber:    billjs.Number,
		Billtype:      billjs.BillType,
		Introducedat:  sql.NullString{String: billjs.IntroducedAt, Valid: true},
		Congress:      billjs.Congress,
		Summary:       pgtype.JSONB{Bytes: summaryjs, Status: pgtype.Present},
		Actions:       pgtype.JSONB{Bytes: actionsjs, Status: pgtype.Present},
		Sponsors:      pgtype.JSONB{Bytes: sponsorsjs, Status: pgtype.Present},
		Cosponsors:    pgtype.JSONB{Bytes: cosponsorsjs, Status: pgtype.Present},
		Statusat:      sql.NullString{String: billjs.StatusAt, Valid: true},
		Shorttitle:    sql.NullString{String: billjs.ShortTitle, Valid: true},
		Officialtitle: sql.NullString{String: billjs.OfficialTitle, Valid: true},
	}
	// ctx := context.Background()
	// _, err = db.NewInsert().Model(&bill).Exec(ctx)
	// if err != nil {
	// 	panic(err)
	// }
	return bill

}

func parse_bill_xml(path string, congress int) csearch.InsertBillParams {
	xmlFile, err := os.Open(path)
	if err != nil {
		fmt.Println(err)
	}
	defer xmlFile.Close()

	byteValue, _ := ioutil.ReadAll(xmlFile)
	if congress < 114 {
		var billxml BillXMLRoot
		xml.Unmarshal(byteValue, &billxml)
		var action_structs []struct {
			ActedAt string
			Text    string
			Type    string
		}

		for _, action := range billxml.BillXML.Actions.Actions {
			action_structs = append(action_structs, struct {
				ActedAt string
				Text    string
				Type    string
			}{
				ActedAt: action.ActedAt,
				Text:    action.Text,
				Type:    action.Type,
			})
		}
		var sponsor_structs []struct {
			Title    string `json:"omitempty"`
			Name     string
			State    string
			District string `json:"omitempty"`
			Party    string `json:"omitempty"`
		}

		for _, sponsor := range billxml.BillXML.Sponsors.Sponsors {
			sponsor_structs = append(sponsor_structs, struct {
				Title    string `json:"omitempty"`
				Name     string
				State    string
				District string `json:"omitempty"`
				Party    string `json:"omitempty"`
			}{
				Name:  sponsor.FullName,
				State: sponsor.State,
			})
		}
		var cosponsor_structs []struct {
			Title    string `json:"omitempty"`
			Name     string
			State    string
			District string `json:"omitempty"`
			Party    string `json:"omitempty"`
		}

		for _, cosponsor := range billxml.BillXML.Cosponsors.Cosponsors {
			cosponsor_structs = append(cosponsor_structs, struct {
				Title    string `json:"omitempty"`
				Name     string
				State    string
				District string `json:"omitempty"`
				Party    string `json:"omitempty"`
			}{
				Name:  cosponsor.FullName,
				State: cosponsor.State,
			})
		}
		var Date string
		var Text string
		if billxml.BillXML.Summary.XMLBillSummaries.XMLBillItems != nil {
			Date = billxml.BillXML.Summary.XMLBillSummaries.XMLBillItems[0].Date
			Text = billxml.BillXML.Summary.XMLBillSummaries.XMLBillItems[0].Text
		}
		summary := struct {
			Date string
			Text string
		}{
			Date: Date,
			Text: Text,
		}
		billID := fmt.Sprintf("%s-%s-%s", billxml.BillXML.Congress, billxml.BillXML.BillType, billxml.BillXML.Number)
		summaryjs, err := json.Marshal(summary)
		if err != nil {
			panic(err)
		}
		actionsjs, err := json.Marshal(action_structs)
		if err != nil {
			panic(err)
		}
		sponsorsjs, err := json.Marshal(sponsor_structs)
		if err != nil {
			panic(err)
		}
		cosponsorsjs, err := json.Marshal(cosponsor_structs)
		if err != nil {
			panic(err)
		}
		// Create Bill Struct, same fields as BillJSON
		var bill = csearch.InsertBillParams{
			Billid:        sql.NullString{String: billID, Valid: true},
			Billnumber:    billxml.BillXML.Number,
			Billtype:      strings.ToLower(billxml.BillXML.BillType),
			Introducedat:  sql.NullString{String: billxml.BillXML.IntroducedAt, Valid: true},
			Congress:      billxml.BillXML.Congress,
			Summary:       pgtype.JSONB{Bytes: summaryjs, Status: pgtype.Present},
			Actions:       pgtype.JSONB{Bytes: actionsjs, Status: pgtype.Present},
			Sponsors:      pgtype.JSONB{Bytes: sponsorsjs, Status: pgtype.Present},
			Cosponsors:    pgtype.JSONB{Bytes: cosponsorsjs, Status: pgtype.Present},
			Statusat:      sql.NullString{String: billxml.BillXML.IntroducedAt, Valid: true},
			Shorttitle:    sql.NullString{String: billxml.BillXML.ShortTitle, Valid: true},
			Officialtitle: sql.NullString{String: billxml.BillXML.ShortTitle, Valid: true}}
		return bill

	} else if congress >= 114 {
		var billxml BillXMLRootnew
		xml.Unmarshal(byteValue, &billxml)
		var action_structs []struct {
			ActedAt string
			Text    string
			Type    string
		}

		for _, action := range billxml.BillXML.Actions.Actions {
			action_structs = append(action_structs, struct {
				ActedAt string
				Text    string
				Type    string
			}{
				ActedAt: action.ActedAt,
				Text:    action.Text,
				Type:    action.Type,
			})
		}
		var sponsor_structs []struct {
			Title    string `json:"omitempty"`
			Name     string
			State    string
			District string `json:"omitempty"`
			Party    string `json:"omitempty"`
		}

		for _, sponsor := range billxml.BillXML.Sponsors.Sponsors {
			sponsor_structs = append(sponsor_structs, struct {
				Title    string `json:"omitempty"`
				Name     string
				State    string
				District string `json:"omitempty"`
				Party    string `json:"omitempty"`
			}{
				Name:  sponsor.FullName,
				State: sponsor.State,
			})
		}
		var cosponsor_structs []struct {
			Title    string `json:"omitempty"`
			Name     string
			State    string
			District string `json:"omitempty"`
			Party    string `json:"omitempty"`
		}

		for _, cosponsor := range billxml.BillXML.Cosponsors.Cosponsors {
			cosponsor_structs = append(cosponsor_structs, struct {
				Title    string `json:"omitempty"`
				Name     string
				State    string
				District string `json:"omitempty"`
				Party    string `json:"omitempty"`
			}{
				Name:  cosponsor.FullName,
				State: cosponsor.State,
			})
		}
		var Date string
		var Text string
		if billxml.BillXML.Summary.XMLBillSummaries.XMLBillItems != nil {
			Date = billxml.BillXML.Summary.XMLBillSummaries.XMLBillItems[0].Date
			Text = billxml.BillXML.Summary.XMLBillSummaries.XMLBillItems[0].Text
		}
		summary := struct {
			Date string
			Text string
		}{
			Date: Date,
			Text: Text,
		}
		billID := fmt.Sprintf("%s-%s-%s", billxml.BillXML.Congress, billxml.BillXML.BillType, billxml.BillXML.Number)
		summaryjs, err := json.Marshal(summary)
		if err != nil {
			panic(err)
		}
		actionsjs, err := json.Marshal(action_structs)
		if err != nil {
			panic(err)
		}
		sponsorsjs, err := json.Marshal(sponsor_structs)
		if err != nil {
			panic(err)
		}
		cosponsorsjs, err := json.Marshal(cosponsor_structs)
		if err != nil {
			panic(err)
		}
		var bill = csearch.InsertBillParams{
			Billid:        sql.NullString{String: billID, Valid: true},
			Billnumber:    billxml.BillXML.Number,
			Billtype:      strings.ToLower(billxml.BillXML.Type),
			Introducedat:  sql.NullString{String: billxml.BillXML.IntroducedAt, Valid: true},
			Congress:      billxml.BillXML.Congress,
			Summary:       pgtype.JSONB{Bytes: summaryjs, Status: pgtype.Present},
			Actions:       pgtype.JSONB{Bytes: actionsjs, Status: pgtype.Present},
			Sponsors:      pgtype.JSONB{Bytes: sponsorsjs, Status: pgtype.Present},
			Cosponsors:    pgtype.JSONB{Bytes: cosponsorsjs, Status: pgtype.Present},
			Statusat:      sql.NullString{String: billxml.BillXML.IntroducedAt, Valid: true},
			Shorttitle:    sql.NullString{String: billxml.BillXML.ShortTitle, Valid: true},
			Officialtitle: sql.NullString{String: billxml.BillXML.ShortTitle, Valid: true},
		}
		return bill
	}

	// ctx := context.Background()
	// _, err = db.NewInsert().Model(&bill).Exec(ctx)
	// if err != nil {
	// 	panic(err)
	// }
	return csearch.InsertBillParams{}
}

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
	fileHashesPath := congressdir+"./fileHashes.gob"

	if _,err := os.Stat(fileHashesPath); err == nil {
		decodeFile, err := os.Open(fileHashesPath)
		if err != nil {
			panic(err)
		}
		defer decodeFile.Close()

		// Create a decoder
		decoder := gob.NewDecoder(decodeFile)

		// Place to decode into
		fileHashes := make(map[string]string)

		// Decode -- We need to pass a pointer otherwise accounts2 isn't modified
		decoder.Decode(&fileHashes)
	}
	// Runs unitedstates/congress run script to update bill xmls
	update_bills()

	ctx := context.Background()
	db, err := pgx.Connect(context.Background(), "postgres://postgres:postgres@"+postgresURI+":5432/csearch?sslmode=disable")
	//db, err := sql.Open("postgres", "host=localhost user=sanjee dbname=temp sslmode=disable")
	if err != nil {
		panic(err)
	}
	queries := csearch.New(db)
	if err != nil {
		panic(err)
	}

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
			var bills = make([]csearch.InsertBillParams, len(files))
			wg.Add(len(files))
			fmt.Printf("Processing Congress %d; Type: %s, Number of Bills: %d \n", i, table, len(files))
			for z, f := range files {
				path := fmt.Sprintf(congressdir+"data/%s/bills/%s/", strconv.Itoa(i), table) + f.Name()
				var xmlcheck = path + "/fdsys_billstatus.xml"
				if _, err := os.Stat(xmlcheck); err == nil {
					go func(z int) {
						f, err := os.Open(xmlcheck)
						if err != nil {
							log.Fatal(err)
						}
						fileHash := sha256.New()
						if _, err := io.Copy(fileHash, f); err != nil {
							log.Fatal(err)
						}
						var fileHashString = fmt.Sprintf("%x", fileHash.Sum(nil))
						f.Close()

						fileHashesMutex.Lock()
						hash := fileHashes[xmlcheck]
						fileHashesMutex.Unlock()
						if hash != fileHashString {
							fileHashesMutex.Lock()
							fileHashes[xmlcheck] = fileHashString
							fileHashesMutex.Unlock()
							sem <- struct{}{}
							// mutex.Lock()
							bills[z] = parse_bill_xml(xmlcheck, i)
							//res2B, _ := json.Marshal(bills[z])
							//println(res2B)
							defer func() { <-sem }()
							defer wg.Done()
						}
					}(z)
				} else if errors.Is(err, os.ErrNotExist) {
					path += "/data.json"

					go func(z int) {
						f, err := os.Open(path)
						if err != nil {
							log.Fatal(err)
						}

						fileHash := sha256.New()
						if _, err := io.Copy(fileHash, f); err != nil {
							log.Fatal(err)
						}
						var fileHashString = fmt.Sprintf("%x", fileHash.Sum(nil))
						f.Close()
						// defer mutex.Unlock()
						fileHashesMutex.Lock()
						hash := fileHashes[path]
						fileHashesMutex.Unlock()
						if hash != fileHashString {
							fileHashesMutex.Lock()
							fileHashes[path] = fileHashString
							fileHashesMutex.Unlock()
							sem <- struct{}{}
							var bjs = parse_bill(path)
							// mutex.Lock()
							bills[z] = bjs
							defer func() { <-sem }()
							defer wg.Done()
						}
					}(z)
				}

			}
			wg.Wait()

			if len(bills) > 0 {
				_, err = queries.InsertBill(ctx, bills)
			}
		}
	}
	encodeFile, err := os.Create(fileHashesPath)
	if err != nil {
		panic(err)
	}

	// Since this is a binary format large parts of it will be unreadable
	encoder := gob.NewEncoder(encodeFile)

	// Write to the file
	if err := encoder.Encode(fileHashes); err != nil {
		panic(err)
	}
	encodeFile.Close()

	close(sem)
	if err != nil {
		panic(err)
	}
}

func update_bills() {
	var congressdir = viper.GetString("CONGRESSDIR")
	var postgresuri = viper.GetString("POSTGRESURI")
	os.Chdir(congressdir)
	// Update Congress Bills
	cmd := exec.Command(congressdir+ "congress/run.py", "govinfo", "--bulkdata=BILLSTATUS")
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

	// Latest bills only (if above fails)
	cmd = exec.Command(congressdir+ "congress/run.py", "govinfo", "--bulkdata=BILLSTATUS", "--congress=118")
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

	cmd = exec.Command("psql", "-U", "postgres", "-d", "csearch", "-h", postgresuri, "-c", "DROP TABLE bills CASCADE ")
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

	    files, err := os.ReadDir(".")
	    if err != nil {
		panic(err)
	    }

	    for _, file := range files {
		fmt.Println(file.Name())
	    }

	cmd = exec.Command("psql", "-U", "postgres", "-h", postgresuri, "-d", "csearch", "-f", "./schema.sql")
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
