package main

import (
	"app/csearch/csearch"
	"bufio"
	"context"
	"crypto/sha256"
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
)

type VoteJSON struct {
	Bill struct {
		Congress string `json:"congress"`
		Number   string `json:"number"`
		Type     string `json:"type"`
	}
	Number    int    `json:"number"`
	BillType  string `json:"bill_type"`
	Date      string
	Congress  int    `json:"congress"`
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

// ParsedVote holds the votes row plus member rows extracted from one data.json file.
type ParsedVote struct {
	Vote    csearch.InsertVoteParams
	Members []csearch.InsertVoteMemberParams
}

func parse_vote(path string) ParsedVote {
	jsonFile, err := os.Open(path)
	if err != nil {
		fmt.Println(err)
	}
	defer jsonFile.Close()

	byteValue, _ := ioutil.ReadAll(jsonFile)
	var votejs VoteJSON
	json.Unmarshal(byteValue, &votejs)

	vote := csearch.InsertVoteParams{
		Voteid:      votejs.VoteID,
		BillType:    sql.NullString{String: votejs.Bill.Type, Valid: votejs.Bill.Type != ""},
		BillNumber:  sql.NullString{String: votejs.Bill.Number, Valid: votejs.Bill.Number != ""},
		Congress:    sql.NullString{String: strconv.Itoa(votejs.Congress), Valid: true},
		Votenumber:  sql.NullString{String: strconv.Itoa(votejs.Number), Valid: true},
		Votedate:    sql.NullString{String: votejs.Votedate, Valid: votejs.Votedate != ""},
		Question:    sql.NullString{String: votejs.Question, Valid: votejs.Question != ""},
		Result:      sql.NullString{String: votejs.Result, Valid: votejs.Result != ""},
		Votesession: sql.NullString{String: votejs.Session, Valid: votejs.Session != ""},
		Chamber:     sql.NullString{String: votejs.Chamber, Valid: votejs.Chamber != ""},
		SourceUrl:   sql.NullString{String: votejs.SourceURL, Valid: votejs.SourceURL != ""},
		Votetype:    sql.NullString{String: votejs.Votetype, Valid: votejs.Votetype != ""},
	}

	var members []csearch.InsertVoteMemberParams

	addMembers := func(position string, items []struct {
		Display_name string `json:"display_name"`
		Id           string `json:"id"`
		Party        string `json:"party"`
		State        string `json:"state"`
	}) {
		for _, m := range items {
			if m.Id == "" {
				continue
			}
			members = append(members, csearch.InsertVoteMemberParams{
				Voteid:      votejs.VoteID,
				BioguideId:  m.Id,
				DisplayName: sql.NullString{String: m.Display_name, Valid: m.Display_name != ""},
				Party:       sql.NullString{String: m.Party, Valid: m.Party != ""},
				State:       sql.NullString{String: m.State, Valid: m.State != ""},
				Position:    position,
			})
		}
	}

	// House uses Aye/No; Senate uses Yea/Nay
	if len(votejs.Votes.Aye) > 0 || len(votejs.Votes.No) > 0 {
		addMembers("yea", votejs.Votes.Aye)
		addMembers("nay", votejs.Votes.No)
	} else {
		addMembers("yea", votejs.Votes.Yea)
		addMembers("nay", votejs.Votes.Nay)
	}
	addMembers("present", votejs.Votes.Present)
	addMembers("notvoting", votejs.Votes.NotVoting)

	return ParsedVote{Vote: vote, Members: members}
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
		decoder := gob.NewDecoder(decodeFile)
		fileHashes = make(map[string]string)
		decoder.Decode(&fileHashes)
		println("Hashes Loaded")
	}
	updateVotes()

	ctx := context.Background()
	db, err := sql.Open("postgres", "host="+postgresURI+" user=postgres password=postgres dbname=csearch sslmode=disable")
	if err != nil {
		panic(err)
	}
	queries := csearch.New(db)

	var wg sync.WaitGroup
	sem := make(chan struct{}, 64)
	for i := 101; i <= 118; i++ {
		var directory = fmt.Sprintf(congressdir+"data/%s/votes/", strconv.Itoa(i))
		years, err := os.ReadDir(directory)
		if err != nil {
			debug.PrintStack()
			continue
		}
		var parsedVotes []ParsedVote
		var mu sync.Mutex
		for _, year := range years {
			var votesdirectory = fmt.Sprintf(congressdir+"data/%s/votes/%s/", strconv.Itoa(i), year.Name())
			votes, err := os.ReadDir(votesdirectory)
			if err != nil {
				debug.PrintStack()
				continue
			}
			wg.Add(len(votes))
			fmt.Printf("Processing Congress %d; Number of Votes: %d \n", i, len(votes))
			for _, f := range votes {
				path := fmt.Sprintf(congressdir+"data/%s/votes/%s/", strconv.Itoa(i), year.Name()) + f.Name() + "/data.json"
				go func() {
					defer wg.Done()
					defer func() { <-sem }()
					sem <- struct{}{}
					f, err := os.Open(path)
					if err != nil {
						log.Fatal(err)
					}
					fileHash := sha256.New()
					io.Copy(fileHash, f)
					hashStr := fmt.Sprintf("%x", fileHash.Sum(nil))
					f.Close()
					fileHashesMutex.Lock()
					prev := fileHashes[path]
					fileHashesMutex.Unlock()
					if prev != hashStr {
						fileHashesMutex.Lock()
						fileHashes[path] = hashStr
						fileHashesMutex.Unlock()
						pv := parse_vote(path)
						mu.Lock()
						parsedVotes = append(parsedVotes, pv)
						mu.Unlock()
					}
				}()
			}
			wg.Wait()
		}

		for _, pv := range parsedVotes {
			_ = queries.InsertVote(ctx, pv.Vote)
			queries.DeleteVoteMembers(ctx, pv.Vote.Voteid)
			for _, m := range pv.Members {
				queries.InsertVoteMember(ctx, m)
			}
		}
		fmt.Printf("Vote Congress %d inserted\n", i)
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

func updateVotes() {
	var congressdir = viper.GetString("CONGRESSDIR")
	os.Chdir(congressdir)

	cmd := exec.Command(congressdir+"congress/run.py", "votes", "--congress=118")
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
