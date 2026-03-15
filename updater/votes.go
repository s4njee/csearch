package main

import (
	"app/csearch/csearch"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"sync"
)

type voteMemberJSON struct {
	DisplayName string `json:"display_name"`
	ID          string `json:"id"`
	Party       string `json:"party"`
	State       string `json:"state"`
}

type VoteJSON struct {
	Bill struct {
		Congress string `json:"congress"`
		Number   string `json:"number"`
		Type     string `json:"type"`
	} `json:"bill"`
	Number    int    `json:"number"`
	BillType  string `json:"bill_type"`
	Congress  int    `json:"congress"`
	Question  string `json:"question"`
	Result    string `json:"result"`
	Chamber   string `json:"chamber"`
	Votedate  string `json:"date"`
	Session   string `json:"session"`
	SourceURL string `json:"source_url"`
	Votetype  string `json:"type"`
	VoteID    string `json:"vote_id"`
	Votes     struct {
		Nay       []voteMemberJSON `json:"Nay"`
		NotVoting []voteMemberJSON `json:"Not Voting"`
		Present   []voteMemberJSON `json:"Present"`
		Yea       []voteMemberJSON `json:"Yea"`
		Aye       []voteMemberJSON `json:"Aye"`
		No        []voteMemberJSON `json:"No"`
	} `json:"votes"`
}

// ParsedVote groups a vote row with the normalized member positions extracted
// from one legacy vote data.json file.
type ParsedVote struct {
	Vote    csearch.InsertVoteParams
	Members []csearch.InsertVoteMemberParams
}

type voteJob struct {
	Path string
}

// parseVote reads a vote data.json file and extracts its metadata and member
// positions into a ParsedVote.
func parseVote(path string) (ParsedVote, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return ParsedVote{}, err
	}

	var voteJSON VoteJSON
	if err := json.Unmarshal(data, &voteJSON); err != nil {
		return ParsedVote{}, err
	}

	billType := voteJSON.Bill.Type
	if billType == "" {
		billType = voteJSON.BillType
	}

	vote := csearch.InsertVoteParams{
		Voteid:      voteJSON.VoteID,
		BillType:    nullStr(billType),
		BillNumber:  nullStr(voteJSON.Bill.Number),
		Congress:    nullStr(strconv.Itoa(voteJSON.Congress)),
		Votenumber:  nullStr(strconv.Itoa(voteJSON.Number)),
		Votedate:    nullStr(voteJSON.Votedate),
		Question:    nullStr(voteJSON.Question),
		Result:      nullStr(voteJSON.Result),
		Votesession: nullStr(voteJSON.Session),
		Chamber:     nullStr(voteJSON.Chamber),
		SourceUrl:   nullStr(voteJSON.SourceURL),
		Votetype:    nullStr(voteJSON.Votetype),
	}

	members := make([]csearch.InsertVoteMemberParams, 0)
	addMembers := func(position string, items []voteMemberJSON) {
		for _, item := range items {
			if item.ID == "" {
				continue
			}

			members = append(members, csearch.InsertVoteMemberParams{
				Voteid:      voteJSON.VoteID,
				BioguideID:  item.ID,
				DisplayName: nullStr(item.DisplayName),
				Party:       nullStr(item.Party),
				State:       nullStr(item.State),
				Position:    position,
			})
		}
	}

	// House payloads use Aye/No while Senate payloads use Yea/Nay.
	if len(voteJSON.Votes.Aye) > 0 || len(voteJSON.Votes.No) > 0 {
		addMembers("yea", voteJSON.Votes.Aye)
		addMembers("nay", voteJSON.Votes.No)
	} else {
		addMembers("yea", voteJSON.Votes.Yea)
		addMembers("nay", voteJSON.Votes.Nay)
	}
	addMembers("present", voteJSON.Votes.Present)
	addMembers("notvoting", voteJSON.Votes.NotVoting)

	return ParsedVote{
		Vote:    vote,
		Members: members,
	}, nil
}

// processVotes handles the discovery, parsing, and database insertion of all
// roll call votes for all supported congresses.
func processVotes(ctx context.Context, db *sql.DB, queries *csearch.Queries, cfg appConfig, hashes *fileHashStore) error {
	for congress := 101; congress <= 118; congress++ {
		jobs, err := voteJobsForCongress(cfg, congress)
		if err != nil {
			log.Printf("skipping vote congress %d: %v", congress, err)
			continue
		}

		log.Printf("processing vote congress %d (%d candidates)", congress, len(jobs))
		parsedVotes := collectChangedVotes(jobs, hashes)
		for _, parsedVote := range parsedVotes {
			insertParsedVote(ctx, db, queries, parsedVote)
		}
	}

	return nil
}

// voteJobsForCongress scans the given congress directory to find all available
// vote JSON payloads.
func voteJobsForCongress(cfg appConfig, congress int) ([]voteJob, error) {
	root := filepath.Join(cfg.CongressDir, "data", fmt.Sprintf("%d", congress), "votes")
	years, err := os.ReadDir(root)
	if err != nil {
		return nil, err
	}

	jobs := make([]voteJob, 0)
	for _, year := range years {
		yearDir := filepath.Join(root, year.Name())
		votes, err := os.ReadDir(yearDir)
		if err != nil {
			log.Printf("skipping vote year %s: %v", year.Name(), err)
			continue
		}

		for _, vote := range votes {
			jobs = append(jobs, voteJob{
				Path: filepath.Join(yearDir, vote.Name(), "data.json"),
			})
		}
	}

	return jobs, nil
}

// collectChangedVotes runs parser jobs concurrently and returns all votes
// whose source files have changed since the last successful ingest.
func collectChangedVotes(jobs []voteJob, hashes *fileHashStore) []ParsedVote {
	parsedVotes := make([]ParsedVote, 0, len(jobs))
	var mu sync.Mutex
	var wg sync.WaitGroup
	sem := make(chan struct{}, workerLimit)

	for _, job := range jobs {
		job := job
		wg.Add(1)

		go func() {
			defer wg.Done()

			sem <- struct{}{}
			defer func() { <-sem }()

			if !fileExists(job.Path) {
				return
			}

			hash, changed, err := hashes.NeedsProcessing(job.Path)
			if err != nil {
				log.Printf("unable to hash %s: %v", job.Path, err)
				return
			}
			if !changed {
				return
			}

			parsedVote, err := parseVote(job.Path)
			if err != nil {
				log.Printf("unable to parse vote %s: %v", job.Path, err)
				return
			}

			mu.Lock()
			parsedVotes = append(parsedVotes, parsedVote)
			mu.Unlock()
			hashes.MarkProcessed(job.Path, hash)
		}()
	}

	wg.Wait()
	return parsedVotes
}

// insertParsedVote inserts a parent vote record and replaces its child member
// positions in the database.
func insertParsedVote(ctx context.Context, db *sql.DB, queries *csearch.Queries, parsedVote ParsedVote) {
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		log.Printf("BeginTx failed for %s: %v", parsedVote.Vote.Voteid, err)
		return
	}
	defer tx.Rollback()

	q := queries.WithTx(tx)

	if err := q.InsertVote(ctx, parsedVote.Vote); err != nil {
		log.Printf("InsertVote failed for %s: %v", parsedVote.Vote.Voteid, err)
		return
	}

	if err := q.DeleteVoteMembers(ctx, parsedVote.Vote.Voteid); err != nil {
		log.Printf("DeleteVoteMembers failed for %s: %v", parsedVote.Vote.Voteid, err)
		return
	}

	for _, member := range parsedVote.Members {
		if err := q.InsertVoteMember(ctx, member); err != nil {
			log.Printf("InsertVoteMember failed for %s/%s: %v", parsedVote.Vote.Voteid, member.BioguideID, err)
			return
		}
	}

	if err := tx.Commit(); err != nil {
		log.Printf("Commit failed for %s: %v", parsedVote.Vote.Voteid, err)
	}
}

// updateVotes runs the upstream python scraper to fetch recent vote data.
func updateVotes(cfg appConfig) error {
	return runCongressTask(cfg, "votes", "--congress=118")
}
