package main

import (
	"strings"
	"testing"
)

func TestFilterAPIHitsKeepsOnlyNonHealthAPICompletions(t *testing.T) {
	body := strings.Join([]string{
		`{"msg":"incoming request","reqId":"api-1","req":{"url":"/bills/hr"},"kubernetes":{"labels":{"app.kubernetes.io/name":"csearch-api"}}}`,
		`{"msg":"request completed","reqId":"api-1","route":"/bills/:billtype","kubernetes":{"labels":{"app.kubernetes.io/name":"csearch-api"}}}`,
		`{"msg":"request completed","reqId":"health-1","route":"/health","kubernetes":{"labels":{"app.kubernetes.io/name":"csearch-api"}}}`,
		`{"msg":"scraper run complete","kubernetes":{"labels":{"app.kubernetes.io/name":"csearch-updater"}}}`,
		`not-json`,
		"",
	}, "\n")

	got := string(filterAPIHits([]byte(body)))

	if !strings.Contains(got, `"reqId":"api-1"`) {
		t.Fatalf("expected API request completion to be kept, got %q", got)
	}
	for _, unexpected := range []string{"incoming request", `"route":"/health"`, "scraper run complete", "not-json"} {
		if strings.Contains(got, unexpected) {
			t.Fatalf("expected %q to be filtered out, got %q", unexpected, got)
		}
	}
	if !strings.HasSuffix(got, "\n") {
		t.Fatalf("expected filtered body to end in newline, got %q", got)
	}
}

func TestFilterAPIHitsReturnsNilWhenNothingMatches(t *testing.T) {
	body := []byte(`{"msg":"request completed","route":"/health","kubernetes":{"labels":{"app.kubernetes.io/name":"csearch-api"}}}`)

	if got := filterAPIHits(body); got != nil {
		t.Fatalf("expected nil body when no API hit matches, got %q", string(got))
	}
}

func TestShouldLogCollectorRequestSuppressesNoise(t *testing.T) {
	for _, path := range []string{"/healthz", "/ingest"} {
		if shouldLogCollectorRequest(path) {
			t.Fatalf("expected collector path %q to be suppressed", path)
		}
	}

	if !shouldLogCollectorRequest("/debug") {
		t.Fatal("expected non-routine collector path to be logged")
	}
}
