package main

import (
	"context"
	"log/slog"
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
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: configuredLogLevel(),
	}))
	slog.SetDefault(logger)

	startedAt := time.Now()
	runVotes := envEnabled("RUN_VOTES", true)
	runBills := envEnabled("RUN_BILLS", true)
	stats := &runStats{}

	slog.Info("scraper run starting",
		"run_votes", runVotes,
		"run_bills", runBills,
	)

	cfg, err := loadConfig()
	if err != nil {
		slog.Error("unable to load updater config", "err", err)
		os.Exit(1)
	}

	db, queries, err := openQueries(cfg)
	if err != nil {
		slog.Error("unable to connect to postgres", "err", err)
		os.Exit(1)
	}
	defer db.Close()

	ctx := context.Background()

	voteHashes, err := loadFileHashStore(filepath.Join(cfg.CongressDir, "data", "voteHashes.gob"))
	if err != nil {
		slog.Error("unable to load vote hash cache", "err", err)
		os.Exit(1)
	}

	billHashes, err := loadFileHashStore(filepath.Join(cfg.CongressDir, "data", "fileHashes.gob"))
	if err != nil {
		slog.Error("unable to load bill hash cache", "err", err)
		os.Exit(1)
	}

	if runVotes {
		if err := updateVotes(cfg); err != nil {
			slog.Error("vote sync failed", "err", err)
			os.Exit(1)
		}
		if err := processVotes(ctx, db, queries, cfg, voteHashes, stats); err != nil {
			slog.Error("vote ingest failed", "err", err)
			os.Exit(1)
		}
	}

	if runBills {
		if err := updateBills(cfg); err != nil {
			slog.Error("bill sync failed", "err", err)
			os.Exit(1)
		}
		if err := processBills(ctx, db, queries, cfg, billHashes, stats); err != nil {
			slog.Error("bill ingest failed", "err", err)
			os.Exit(1)
		}
	}

	slog.Info("scraper run complete",
		"bills_processed", stats.BillsProcessed,
		"bills_skipped", stats.BillsSkipped,
		"bills_failed", stats.BillsFailed,
		"votes_processed", stats.VotesProcessed,
		"votes_skipped", stats.VotesSkipped,
		"votes_failed", stats.VotesFailed,
		"duration_s", time.Since(startedAt).Seconds(),
	)
}
