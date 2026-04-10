package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

const maxBodyBytes = 10 << 20

type collector struct {
	logDir string
	mu     sync.Mutex
}

func main() {
	logDir := getenv("LOG_COLLECTOR_DIR", "/var/log/csearch-collector")
	listenAddr := getenv("LOG_COLLECTOR_LISTEN_ADDR", ":8080")

	if err := os.MkdirAll(logDir, 0o755); err != nil {
		log.Fatalf("create log dir: %v", err)
	}

	c := &collector{logDir: logDir}
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", c.healthz)
	mux.HandleFunc("/ingest", c.ingest)

	server := &http.Server{
		Addr:              listenAddr,
		Handler:           loggingMiddleware(mux),
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Printf("collector listening on %s, writing to %s", listenAddr, logDir)
	if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatalf("listen: %v", err)
	}
}

func (c *collector) healthz(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok\n"))
}

func (c *collector) ingest(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	defer r.Body.Close()
	body, err := io.ReadAll(io.LimitReader(r.Body, maxBodyBytes+1))
	if err != nil {
		http.Error(w, "read body failed", http.StatusBadRequest)
		return
	}
	if len(body) == 0 {
		http.Error(w, "empty body", http.StatusBadRequest)
		return
	}
	if len(body) > maxBodyBytes {
		http.Error(w, "body too large", http.StatusRequestEntityTooLarge)
		return
	}

	if body[len(body)-1] != '\n' {
		body = append(body, '\n')
	}

	body = filterAPIHits(body)
	if len(body) == 0 {
		w.WriteHeader(http.StatusAccepted)
		_, _ = w.Write([]byte("accepted\n"))
		return
	}

	cluster := sanitizeSegment(r.Header.Get("X-Cluster"))
	if cluster == "" {
		cluster = "unknown-cluster"
	}
	source := sanitizeSegment(r.Header.Get("X-Source"))
	if source == "" {
		source = "unknown-source"
	}

	now := time.Now().UTC()
	dir := filepath.Join(c.logDir, cluster, source)
	name := fmt.Sprintf("%s.ndjson", now.Format("2006-01-02"))
	path := filepath.Join(dir, name)

	c.mu.Lock()
	defer c.mu.Unlock()

	if err := os.MkdirAll(dir, 0o755); err != nil {
		http.Error(w, "create target dir failed", http.StatusInternalServerError)
		return
	}

	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		http.Error(w, "open target file failed", http.StatusInternalServerError)
		return
	}
	defer f.Close()

	if _, err := f.Write(body); err != nil {
		http.Error(w, "write failed", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusAccepted)
	_, _ = w.Write([]byte("accepted\n"))
}

func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		if !shouldLogCollectorRequest(r.URL.Path) {
			return
		}
		log.Printf("request completed method=%s path=%s remote=%s duration_ms=%.2f", r.Method, r.URL.Path, r.RemoteAddr, float64(time.Since(start).Microseconds())/1000)
	})
}

func shouldLogCollectorRequest(path string) bool {
	return path != "/healthz" && path != "/ingest"
}

func filterAPIHits(body []byte) []byte {
	lines := bytes.Split(body, []byte{'\n'})
	kept := make([][]byte, 0, len(lines))

	for _, line := range lines {
		if len(line) == 0 {
			continue
		}
		if apiHit(line) {
			kept = append(kept, line)
		}
	}

	if len(kept) == 0 {
		return nil
	}
	return append(bytes.Join(kept, []byte{'\n'}), '\n')
}

func apiHit(line []byte) bool {
	var entry map[string]any
	if err := json.Unmarshal(line, &entry); err != nil {
		return false
	}

	kubernetes, ok := entry["kubernetes"].(map[string]any)
	if !ok {
		return false
	}
	labels, ok := kubernetes["labels"].(map[string]any)
	if !ok {
		return false
	}
	appName, _ := labels["app.kubernetes.io/name"].(string)
	if appName != "csearch-api" {
		return false
	}

	msg, _ := entry["msg"].(string)
	if msg != "request completed" {
		return false
	}

	if route, _ := entry["route"].(string); route == "/health" {
		return false
	}

	if req, ok := entry["req"].(map[string]any); ok {
		url, _ := req["url"].(string)
		if url == "/health" {
			return false
		}
	}

	return true
}

func sanitizeSegment(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return ""
	}

	replacer := strings.NewReplacer("/", "-", "\\", "-", "..", "-", " ", "-")
	value = replacer.Replace(value)
	return strings.Map(func(r rune) rune {
		switch {
		case r >= 'a' && r <= 'z':
			return r
		case r >= 'A' && r <= 'Z':
			return r
		case r >= '0' && r <= '9':
			return r
		case r == '-', r == '_', r == '.':
			return r
		default:
			return '-'
		}
	}, value)
}

func getenv(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}
