package main

import (
	"app/csearch/csearch"
	"bufio"
	"context"
	"database/sql"
	"fmt"
	"io"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"

	_ "github.com/lib/pq"
	"github.com/spf13/viper"
)

// workerLimit governs the maximum number of concurrent parser goroutines used
// during bill and vote ingest.
const workerLimit = 64

// dbWriteConcurrency caps concurrent write transactions to match the database
// pool size and the target cluster's available CPU.
const dbWriteConcurrency = 4

// appConfig holds the environment configuration needed by the updater to locate
// source data and connect to the database.
type appConfig struct {
	CongressDir string
	PostgresURI string
	RedisURL    string
	DBUser      string
	DBPassword  string
	DBName      string
	DBPort      string
}

// runStats accumulates one updater pass so the final summary log stays compact.
type runStats struct {
	BillsProcessed int64
	BillsSkipped   int64
	BillsFailed    int64
	VotesProcessed int64
	VotesSkipped   int64
	VotesFailed    int64
}

// loadConfig accepts container-style environment variables and falls back to a
// local .env file for developer workflows.
func loadConfig() (appConfig, error) {
	viper.SetConfigType("env")
	viper.AutomaticEnv()
	if _, err := os.Stat(".env"); err == nil {
		viper.SetConfigFile(".env")
		if err := viper.ReadInConfig(); err != nil {
			return appConfig{}, err
		}
	}

	cfg := appConfig{
		CongressDir: viper.GetString("CONGRESSDIR"),
		PostgresURI: viper.GetString("POSTGRESURI"),
		RedisURL:    viper.GetString("REDIS_URL"),
		DBUser:      viper.GetString("DB_USER"),
		DBPassword:  viper.GetString("DB_PASSWORD"),
		DBName:      viper.GetString("DB_NAME"),
		DBPort:      viper.GetString("DB_PORT"),
	}

	if cfg.CongressDir == "" {
		return appConfig{}, fmt.Errorf("missing CONGRESSDIR")
	}
	if cfg.PostgresURI == "" {
		return appConfig{}, fmt.Errorf("missing POSTGRESURI")
	}
	if cfg.DBUser == "" {
		cfg.DBUser = "postgres"
	}
	if cfg.DBPassword == "" {
		cfg.DBPassword = "postgres"
	}
	if cfg.DBName == "" {
		cfg.DBName = "csearch"
	}
	if cfg.DBPort == "" {
		cfg.DBPort = "5432"
	}
	if cfg.RedisURL == "" {
		cfg.RedisURL = "redis://localhost:6379"
	}

	return cfg, nil
}

// configuredLogLevel maps LOG_LEVEL onto slog's supported levels.
func configuredLogLevel() slog.Level {
	switch strings.ToLower(strings.TrimSpace(os.Getenv("LOG_LEVEL"))) {
	case "debug":
		return slog.LevelDebug
	case "warn", "warning":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}

// openQueries establishes a database connection and wraps it in the generated
// sqlc query interface.
func openQueries(cfg appConfig) (*sql.DB, *csearch.Queries, error) {
	db, err := sql.Open("postgres", postgresDSN(cfg))
	if err != nil {
		return nil, nil, err
	}
	db.SetMaxOpenConns(dbWriteConcurrency)
	db.SetMaxIdleConns(dbWriteConcurrency)

	if err := ensureSchemaCompatibility(db); err != nil {
		db.Close()
		return nil, nil, err
	}

	return db, csearch.New(db), nil
}

// ensureSchemaCompatibility applies lightweight, idempotent repairs needed for
// databases that were created before newer normalized tables existed.
func ensureSchemaCompatibility(db *sql.DB) error {
	const stmt = `
CREATE TABLE IF NOT EXISTS committees (
    committee_code text PRIMARY KEY,
    committee_name text,
    chamber        text
);

CREATE INDEX IF NOT EXISTS committees_chamber_idx
    ON committees (chamber);

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'bill_committees'
          AND column_name = 'committee_name'
    ) THEN
        INSERT INTO committees (committee_code, committee_name, chamber)
        SELECT DISTINCT ON (committee_code)
            committee_code,
            NULLIF(committee_name, ''),
            NULLIF(chamber, '')
        FROM bill_committees
        WHERE committee_code IS NOT NULL
        ORDER BY committee_code, committee_name NULLS LAST, chamber NULLS LAST
        ON CONFLICT (committee_code) DO UPDATE SET
            committee_name = COALESCE(excluded.committee_name, committees.committee_name),
            chamber = COALESCE(excluded.chamber, committees.chamber);
    END IF;
END $$;
`

	if _, err := db.Exec(stmt); err != nil {
		return fmt.Errorf("ensure schema compatibility: %w", err)
	}

	return nil
}

// postgresDSN formats a PostgreSQL connection string from the app config.
func postgresDSN(cfg appConfig) string {
	return fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		cfg.PostgresURI, cfg.DBPort, cfg.DBUser, cfg.DBPassword, cfg.DBName)
}

// congressRuntimeDir prefers the writable runtime copy of the scraper but
// falls back to the bundled image copy when Kubernetes volume mounts create a
// non-writable parent directory under CONGRESSDIR.
func congressRuntimeDir(cfg appConfig) string {
	runtimeDir := filepath.Join(cfg.CongressDir, "congress")
	if _, err := os.Stat(filepath.Join(runtimeDir, "run.py")); err == nil {
		return runtimeDir
	}

	return "/opt/csearch/congress"
}

// runCongressTask wraps the Python scraper entrypoint so the Go ingest can keep
// orchestration in one place while still streaming scraper logs to stdout.
func runCongressTask(cfg appConfig, args ...string) error {
	congressDir := congressRuntimeDir(cfg)
	cmd := exec.Command(filepath.Join(congressDir, "run.py"), args...)
	cmd.Dir = congressDir
	cmd.Env = append(os.Environ(), "PYTHONPATH="+pythonPathForCongressDir(congressDir))

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return err
	}
	if err := cmd.Start(); err != nil {
		return err
	}

	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		defer wg.Done()
		streamOutput("stdout", stdout)
	}()
	go func() {
		defer wg.Done()
		streamOutput("stderr", stderr)
	}()

	err = cmd.Wait()
	wg.Wait()
	return err
}

// pythonPathForCongressDir returns a PYTHONPATH rooted at the parent directory
// of the congress package so imports like `congress.tasks` resolve correctly.
func pythonPathForCongressDir(congressDir string) string {
	paths := []string{filepath.Dir(congressDir)}
	if existing := strings.TrimSpace(os.Getenv("PYTHONPATH")); existing != "" {
		paths = append(paths, existing)
	}

	return strings.Join(paths, string(os.PathListSeparator))
}

// streamOutput reads continuously from r and republishes each line as a
// structured log entry so Python scraper output stays parseable.
func streamOutput(source string, r io.Reader) {
	scanner := bufio.NewScanner(r)
	for scanner.Scan() {
		slog.Info("python", "stream", source, "output", scanner.Text())
	}

	if err := scanner.Err(); err != nil {
		slog.Warn("python output stream ended", "stream", source, "err", err)
	}
}

const redisCacheKeyPrefix = "csearch:"

// clearAPICache removes all Redis-backed API cache entries after a successful
// ingest so readers do not continue serving stale rows from pre-ingest state.
func clearAPICache(ctx context.Context, cfg appConfig) (int, error) {
	opt, err := redisOptions(cfg.RedisURL)
	if err != nil {
		return 0, err
	}

	client := newRedisClient(opt)
	defer client.Close()

	if err := client.Ping(ctx).Err(); err != nil {
		return 0, err
	}

	var (
		cursor  uint64
		deleted int
	)

	for {
		keys, nextCursor, err := client.Scan(ctx, cursor, redisCacheKeyPrefix+"*", 100).Result()
		if err != nil {
			return deleted, err
		}

		if len(keys) > 0 {
			if err := client.Del(ctx, keys...).Err(); err != nil {
				return deleted, err
			}
			deleted += len(keys)
		}

		cursor = nextCursor
		if cursor == 0 {
			break
		}
	}

	return deleted, nil
}
