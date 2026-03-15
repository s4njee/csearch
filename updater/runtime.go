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

	_ "github.com/lib/pq"
	"github.com/spf13/viper"
)

// workerLimit governs the maximum number of concurrent parser goroutines used
// during bill and vote ingest.
const workerLimit = 64

// appConfig holds the environment configuration needed by the updater to locate
// source data and connect to the database.
type appConfig struct {
	CongressDir string
	PostgresURI string
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
	}

	if cfg.CongressDir == "" {
		return appConfig{}, fmt.Errorf("missing CONGRESSDIR")
	}
	if cfg.PostgresURI == "" {
		return appConfig{}, fmt.Errorf("missing POSTGRESURI")
	}

	return cfg, nil
}

// openQueries establishes a database connection and wraps it in the generated
// sqlc query interface.
func openQueries(cfg appConfig) (*sql.DB, *csearch.Queries, error) {
	db, err := sql.Open("postgres", postgresDSN(cfg.PostgresURI))
	if err != nil {
		return nil, nil, err
	}

	return db, csearch.New(db), nil
}

// postgresDSN formats a PostgreSQL connection string for the local container network.
func postgresDSN(host string) string {
	return fmt.Sprintf("host=%s user=postgres password=postgres dbname=csearch sslmode=disable", host)
}

// runCongressTask wraps the Python scraper entrypoint so the Go ingest can keep
// orchestration in one place while still streaming scraper logs to stdout.
func runCongressTask(cfg appConfig, args ...string) error {
	cmd := exec.Command(filepath.Join(cfg.CongressDir, "congress", "run.py"), args...)
	cmd.Dir = cfg.CongressDir

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

// streamOutput reads continuously from r and writes to standard output.
// It is primarily used for surfacing scraper logs.
func streamOutput(r io.Reader) {
	scanner := bufio.NewScanner(r)
	for scanner.Scan() {
		fmt.Println(scanner.Text())
	}
}
