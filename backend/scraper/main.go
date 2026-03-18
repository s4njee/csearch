package main

import (
	"context"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// currentCongress returns the number of the current US Congress based on the
// calendar year. A new Congress begins every two years in January of odd-numbered
// years; Congress 1 convened in 1789.
func currentCongress() int {
	return (time.Now().Year()-1789)/2 + 1
}

// envEnabled reads an environment variable and parses it as a boolean, falling
// back to defaultValue if the variable is unset or unrecognized.
func envEnabled(name string, defaultValue bool) bool {
	value, ok := os.LookupEnv(name)
	if !ok {
		return defaultValue
	}

	switch strings.ToLower(strings.TrimSpace(value)) {
	case "1", "true", "yes", "on":
		return true
	case "0", "false", "no", "off":
		return false
	default:
		return defaultValue
	}
}

func main() {
	cfg, err := loadConfig()
	if err != nil {
		log.Printf("unable to load updater config: %v", err)
		return
	}

	db, queries, err := openQueries(cfg)
	if err != nil {
		log.Fatalf("unable to connect to postgres: %v", err)
	}
	defer db.Close()

	ctx := context.Background()

	voteHashes, err := loadFileHashStore(filepath.Join(cfg.CongressDir, "data", "voteHashes.gob"))
	if err != nil {
		log.Fatalf("unable to load vote hash cache: %v", err)
	}

	billHashes, err := loadFileHashStore(filepath.Join(cfg.CongressDir, "data", "fileHashes.gob"))
	if err != nil {
		log.Fatalf("unable to load bill hash cache: %v", err)
	}

	if envEnabled("RUN_VOTES", true) {
		if err := updateVotes(cfg); err != nil {
			log.Fatalf("vote sync failed: %v", err)
		}
		if err := processVotes(ctx, db, queries, cfg, voteHashes); err != nil {
			log.Fatalf("vote ingest failed: %v", err)
		}
		if err := voteHashes.Save(); err != nil {
			log.Fatalf("unable to persist vote hash cache: %v", err)
		}
	}

	if envEnabled("RUN_BILLS", true) {
		if err := updateBills(cfg); err != nil {
			log.Fatalf("bill sync failed: %v", err)
		}
		if err := processBills(ctx, db, queries, cfg, billHashes); err != nil {
			log.Fatalf("bill ingest failed: %v", err)
		}
		if err := billHashes.Save(); err != nil {
			log.Fatalf("unable to persist bill hash cache: %v", err)
		}
	}
}
