package main

import (
	"app/csearch/csearch"
	"bufio"
	"database/sql"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

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
	DBUser      string
	DBPassword  string
	DBName      string
	DBPort      string
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

	return cfg, nil
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

	return db, csearch.New(db), nil
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

	go streamOutput(stdout)
	go streamOutput(stderr)

	return cmd.Wait()
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

// streamOutput reads continuously from r and writes to standard output.
// It is primarily used for surfacing scraper logs.
func streamOutput(r io.Reader) {
	scanner := bufio.NewScanner(r)
	for scanner.Scan() {
		fmt.Println(scanner.Text())
	}
}
