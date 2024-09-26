package main

import (
	"bufio"
	"context"
	"crypto/sha256"
	"csearch/csearch"
	"database/sql"
	"encoding/gob"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"runtime/debug"
	"strconv"
	"sync"

	_ "github.com/lib/pq"
	"github.com/spf13/viper"
	"github.com/sqlc-dev/pqtype"
)

// var mutex = &sync.Mutex{}

type VoteJSON struct {
	Bill struct {
		Congress string `json:"congress"`
		Number   string `json:"number"`
		Type     string `json:"type"`
	}
	Number    int    `json:"number"`
	BillType  string `json:"bill_type"`
	Date      string
	Congress  int `json:"congress"`
	Question  string
	Result    string
	Chamber   string `json:"chamber"`
	Votedate  string `json:"date"`
	Session   string `json:"session"`
	SourceURL string `json:"source_url"`
	Votetype  string `json:"type"`
	VoteID    string `json:"vote_id"`
	Votes     struct {
		Nay []struct {
			Display_name string `json:"display_name"`
			Id           string `json:"id"`
			Party        string `json:"party"`
			State        string `json:"state"`
		} `json:"Nay"`
		NotVoting []struct {
			Display_name string `json:"display_name"`
			Id           string `json:"id"`
			Party        string `json:"party"`
			State        string `json:"state"`
		} `json:"Not Voting"`
		Present []struct {
			Display_name string `json:"display_name"`
			Id           string `json:"id"`
			Party        string `json:"party"`
			State        string `json:"state"`
		} `json:"Present"`
		Yea []struct {
			Display_name string `json:"display_name"`
			Id           string `json:"id"`
			Party        string `json:"party"`
			State        string `json:"state"`
		} `json:"Yea"`
		Aye []struct {
			Display_name string `json:"display_name"`
			Id           string `json:"id"`
			Party        string `json:"party"`
			State        string `json:"state"`
		} `json:"Aye"`
		No []struct {
			Display_name string `json:"display_name"`
			Id           string `json:"id"`
			Party        string `json:"party"`
			State        string `json:"state"`
		} `json:"No"`
	}
}

func parse_vote(path string) csearch.InsertVoteParams {
	jsonFile, err := os.Open(path)
	if err != nil {
		fmt.Println(err)
	}
	defer jsonFile.Close()

	byteValue, _ := ioutil.ReadAll(jsonFile)
	var votejs VoteJSON

	json.Unmarshal(byteValue, &votejs)
	bill, err := json.Marshal(votejs.Bill)
	if err != nil {
		panic(err)
	}

	json.Unmarshal(byteValue, &votejs)

	var yeas []byte
	var nays []byte
	if len(votejs.Votes.Aye) == 0 && len(votejs.Votes.No) == 0 {
		yeas, err = json.Marshal(votejs.Votes.Yea)
		if err != nil {
			panic(err)
		}
		nays, err = json.Marshal(votejs.Votes.Nay)
		if err != nil {
			panic(err)
		}
	} else {
		yeas, err = json.Marshal(votejs.Votes.Aye)
		if err != nil {
			panic(err)
		}
		nays, err = json.Marshal(votejs.Votes.No)
		if err != nil {
			panic(err)
		}
	}

	presents, err := json.Marshal(votejs.Votes.Present)
	if err != nil {
		panic(err)
	}
	notvotings, err := json.Marshal(votejs.Votes.NotVoting)
	if err != nil {
		panic(err)
	}
	// Create Bill Struct, same fields as BillJSON
	var vote = csearch.InsertVoteParams{
		Bill:        pqtype.NullRawMessage{RawMessage: bill, Valid: true},
		Voteid:      votejs.VoteID,
		Chamber:     sql.NullString{String: votejs.Chamber, Valid: true},
		Votenumber:  sql.NullString{String: strconv.Itoa(votejs.Number), Valid: true},
		Votetype:    sql.NullString{String: votejs.Votetype, Valid: true},
		Question:    sql.NullString{String: votejs.Question, Valid: true},
		Congress:    sql.NullString{String: strconv.Itoa(votejs.Congress), Valid: true},
		Votesession: sql.NullString{String: votejs.Session, Valid: true},
		Yea:         pqtype.NullRawMessage{RawMessage: yeas, Valid: true},
		Nay:         pqtype.NullRawMessage{RawMessage: nays, Valid: true},
		Present:     pqtype.NullRawMessage{RawMessage: presents, Valid: true},
		Notvoting:   pqtype.NullRawMessage{RawMessage: notvotings, Valid: true},
		Votedate:    sql.NullString{String: votejs.Votedate, Valid: true},
		SourceUrl:   sql.NullString{String: votejs.SourceURL, Valid: true},
		Result:      sql.NullString{String: votejs.Result, Valid: true},
	}
	// ctx := context.Background()
	// _, err = db.NewInsert().Model(&bill).Exec(ctx)
	// if err != nil {
	// 	panic(err)
	// }
	return vote

}

func processVotes() {
	viper.SetConfigFile(".env")
	err := viper.ReadInConfig()
	if err != nil {
		return
	}

	congressdir := viper.GetString("CONGRESSDIR")
	postgresURI := viper.GetString("POSTGRESURI")
	fileHashes := make(map[string]string)
	fileHashesMutex := sync.RWMutex{}
	fileHashesPath := congressdir + "./voteHashes.gob"

	if _, err := os.Stat(fileHashesPath); err == nil {
		decodeFile, err := os.Open(fileHashesPath)
		if err != nil {
			panic(err)
		}
		defer decodeFile.Close()

		// Create a decoder
		decoder := gob.NewDecoder(decodeFile)

		// Place to decode into
		fileHashes = make(map[string]string)

		// Decode -- We need to pass a pointer otherwise accounts2 isn't modified
		decoder.Decode(&fileHashes)
		println("Hashes Loaded")
	}
	// Runs unitedstates/congress run script to update bill xmls
	updateVotes()

	ctx := context.Background()
	//db, err := pgx.Connect(context.Background(), "postgres://postgres:postgres@postgres-service:5432/csearch?sslmode=disable")
	db, err := sql.Open("postgres", "host="+postgresURI+" user=postgres password=postgres dbname=csearch sslmode=disable")
	if err != nil {
		panic(err)
	}
	queries := csearch.New(db)
	if err != nil {
		panic(err)
	}

	var wg sync.WaitGroup
	sem := make(chan struct{}, 64)
	for i := 101; i <= 118; i++ {
		var directory = fmt.Sprintf(congressdir+"data/%s/votes/", strconv.Itoa(i))
		years, err := os.ReadDir(directory)
		if err != nil {
			debug.PrintStack()
			continue
		}
		var votesParams []csearch.InsertVoteParams
		for _, year := range years {
			var votesdirectory = fmt.Sprintf(congressdir+"data/%s/votes/%s/", strconv.Itoa(i), year.Name())
			votes, err := os.ReadDir(votesdirectory)
			if err != nil {
				debug.PrintStack()
				continue
			}
			wg.Add(len(votes))
			fmt.Printf("Processing Congress %d; Number of Votes: %d \n", i, len(votes))
			for z, f := range votes {
				path := fmt.Sprintf(congressdir+"data/%s/votes/%s/", strconv.Itoa(i), year.Name()) + f.Name()
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
					fileHashesMutex.Lock()
					hash := fileHashes[path]
					fileHashesMutex.Unlock()
					if hash != fileHashString {
						fileHashesMutex.Lock()
						fileHashes[path] = fileHashString
						fileHashesMutex.Unlock()
						sem <- struct{}{}
						var vjs = parse_vote(path)
						// mutex.Lock()
						votesParams = append(votesParams, vjs)
					}
					defer func() { <-sem }()
					defer wg.Done()
				}(z)
			}
			wg.Wait()
			if len(votesParams) > 0 {
				//_ = queries.InsertBill(ctx, bills)
				for _, vote := range votesParams {
					_ = queries.InsertVote(ctx, vote)
					if err != nil {
						panic(err)
					}
				}
				fmt.Printf("Vote Congress %s Year %sInserted", strconv.Itoa(i), year)
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

func updateVotes() {
	var congressdir = viper.GetString("CONGRESSDIR")
	os.Chdir(congressdir)
	// Update Congress Bills

	cmd := exec.Command(congressdir+"congress/run.py", "votes", "--congress=118", "--session=2023")
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

}

func copyOutput(r io.Reader) {
	scanner := bufio.NewScanner(r)
	for scanner.Scan() {
		fmt.Println(scanner.Text())
	}
}
