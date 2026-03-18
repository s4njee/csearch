package main

import (
	"app/csearch/csearch"
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
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
		Congress int    `json:"congress"`
		Number   int    `json:"number"`
		Type     string `json:"type"`
	} `json:"bill"`
	Number    int                          `json:"number"`
	BillType  string                       `json:"bill_type"`
	Congress  int                          `json:"congress"`
	Question  string                       `json:"question"`
	Result    string                       `json:"result"`
	Chamber   string                       `json:"chamber"`
	Votedate  string                       `json:"date"`
	Session   string                       `json:"session"`
	SourceURL string                       `json:"source_url"`
	Votetype  string                       `json:"type"`
	VoteID    string                       `json:"vote_id"`
	Votes     map[string][]json.RawMessage `json:"votes"`
}

// normalizePosition maps standard vote keys to canonical position strings.
// Unrecognized keys (e.g. speaker candidate names) are returned as-is.
func normalizePosition(key string) string {
	switch key {
	case "Yea", "Aye":
		return "yea"
	case "Nay", "No":
		return "nay"
	case "Not Voting":
		return "notvoting"
	case "Present":
		return "present"
	case "Guilty":
		return "guilty"
	case "Not Guilty":
		return "notguilty"
	default:
		return key
	}
}

// ParsedVote groups a vote row with the normalized member positions extracted
// from one legacy vote data.json file.
type ParsedVote struct {
	Vote    csearch.InsertVoteParams
	Members []csearch.InsertVoteMemberParams
	Path    string // source file path, used to mark hash after successful DB insert
	Hash    string // SHA-256 digest of source file
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

	votedAt, err := parseDateValue(voteJSON.Votedate)
	if err != nil {
		return ParsedVote{}, fmt.Errorf("parse vote date for %s: %w", path, err)
	}

	vote := csearch.InsertVoteParams{
		Voteid:      voteJSON.VoteID,
		BillType:    nullStr(billType),
		BillNumber:  nullInt32(int32(voteJSON.Bill.Number)),
		Congress:    nullInt32(int32(voteJSON.Congress)),
		Votenumber:  nullInt32(int32(voteJSON.Number)),
		Votedate:    nullTime(votedAt),
		Question:    nullStr(voteJSON.Question),
		Result:      nullStr(voteJSON.Result),
		Votesession: nullStr(voteJSON.Session),
		Chamber:     nullStr(voteJSON.Chamber),
		SourceUrl:   nullStr(voteJSON.SourceURL),
		Votetype:    nullStr(voteJSON.Votetype),
	}

	members := make([]csearch.InsertVoteMemberParams, 0)
	for key, items := range voteJSON.Votes {
		parsedMembers, err := parseVoteMembers(items)
		if err != nil {
			return ParsedVote{}, fmt.Errorf("parse vote members for %s/%s: %w", path, key, err)
		}

		position := normalizePosition(key)
		for _, item := range parsedMembers {
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

	return ParsedVote{
		Vote:    vote,
		Members: members,
	}, nil
}

// parseVoteMembers accepts mixed legacy vote-member arrays. Some Senate
// tiebreaker votes include string markers like "VP" alongside normal member
// objects; those markers are ignored because they are not legislator records.
func parseVoteMembers(items []json.RawMessage) ([]voteMemberJSON, error) {
	members := make([]voteMemberJSON, 0, len(items))
	for _, item := range items {
		trimmed := bytes.TrimSpace(item)
		if len(trimmed) == 0 || bytes.Equal(trimmed, []byte("null")) {
			continue
		}
		if trimmed[0] == '"' {
			continue
		}

		var member voteMemberJSON
		if err := json.Unmarshal(trimmed, &member); err != nil {
			return nil, err
		}
		members = append(members, member)
	}

	return members, nil
}

// processVotes handles the discovery, parsing, and database insertion of all
// roll call votes for all supported congresses.
func processVotes(ctx context.Context, db *sql.DB, queries *csearch.Queries, cfg appConfig, hashes *fileHashStore) error {
	for congress := 101; congress <= currentCongress(); congress++ {
		jobs, err := voteJobsForCongress(cfg, congress)
		if err != nil {
			log.Printf("skipping vote congress %d: %v", congress, err)
			continue
		}

		log.Printf("processing vote congress %d (%d candidates)", congress, len(jobs))
		parsedVotes := collectChangedVotes(jobs, hashes)
		var wg sync.WaitGroup
		sem := make(chan struct{}, dbWriteConcurrency)
		for _, parsedVote := range parsedVotes {
			parsedVote := parsedVote
			wg.Add(1)
			go func() {
				defer wg.Done()

				sem <- struct{}{}
				defer func() { <-sem }()

				if err := insertParsedVote(ctx, db, queries, parsedVote); err != nil {
					log.Printf("unable to insert vote %s: %v", parsedVote.Vote.Voteid, err)
					return
				}
				hashes.MarkProcessed(parsedVote.Path, parsedVote.Hash)
			}()
		}
		wg.Wait()
	}

	return nil
}

// voteJobsForCongress scans the given congress directory to find all available
// vote JSON payloads.
func voteJobsForCongress(cfg appConfig, congress int) ([]voteJob, error) {
	root := filepath.Join(cfg.CongressDir, "congress", "data", fmt.Sprintf("%d", congress), "votes")
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
			parsedVote.Path = job.Path
			parsedVote.Hash = hash

			mu.Lock()
			parsedVotes = append(parsedVotes, parsedVote)
			mu.Unlock()
		}()
	}

	wg.Wait()
	return parsedVotes
}

// insertParsedVote inserts a parent vote record and replaces its child member
// positions in the database.
func insertParsedVote(ctx context.Context, db *sql.DB, queries *csearch.Queries, parsedVote ParsedVote) error {
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("BeginTx failed for %s: %w", parsedVote.Vote.Voteid, err)
	}
	defer tx.Rollback()

	q := queries.WithTx(tx)

	if err := q.InsertVote(ctx, parsedVote.Vote); err != nil {
		return fmt.Errorf("InsertVote failed for %s: %w", parsedVote.Vote.Voteid, err)
	}

	if err := q.DeleteVoteMembers(ctx, parsedVote.Vote.Voteid); err != nil {
		return fmt.Errorf("DeleteVoteMembers failed for %s: %w", parsedVote.Vote.Voteid, err)
	}

	for _, member := range parsedVote.Members {
		if err := q.InsertVoteMember(ctx, member); err != nil {
			return fmt.Errorf("InsertVoteMember failed for %s/%s: %w", parsedVote.Vote.Voteid, member.BioguideID, err)
		}
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("Commit failed for %s: %w", parsedVote.Vote.Voteid, err)
	}

	return nil
}

// updateVotes runs the upstream python scraper to fetch vote data for every
// congress. Per-congress failures are logged but do not abort the loop since
// older congresses may not have index pages available online.
func updateVotes(cfg appConfig) error {
	congress := currentCongress()
	if err := runCongressTask(cfg, "votes", fmt.Sprintf("--congress=%d", congress)); err != nil {
		log.Printf("vote sync skipped for congress %d: %v", congress, err)
	}
	return nil
}
