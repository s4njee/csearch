package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestParseVoteSkipsLegacyStringMarkers(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	path := filepath.Join(dir, "data.json")
	payload := `{
	  "bill": {"congress": 110, "number": 70, "type": "sconres"},
	  "number": 47,
	  "congress": 110,
	  "question": "Question",
	  "result": "Passed",
	  "chamber": "s",
	  "date": "2008-03-13T12:38:00-04:00",
	  "session": "2008",
	  "source_url": "https://example.com/vote.xml",
	  "type": "On the Motion",
	  "vote_id": "s47-110.2008",
	  "votes": {
	    "Yea": [
	      "VP",
	      {
	        "display_name": "Example Senator (D-IL)",
	        "id": "S999",
	        "party": "D",
	        "state": "IL"
	      }
	    ],
	    "Nay": []
	  }
	}`

	if err := os.WriteFile(path, []byte(payload), 0o644); err != nil {
		t.Fatalf("WriteFile: %v", err)
	}

	parsed, err := parseVote(path)
	if err != nil {
		t.Fatalf("parseVote: %v", err)
	}

	if parsed.Vote.Voteid != "s47-110.2008" {
		t.Fatalf("unexpected vote id: %q", parsed.Vote.Voteid)
	}
	if len(parsed.Members) != 1 {
		t.Fatalf("expected 1 parsed member, got %d", len(parsed.Members))
	}
	if parsed.Members[0].BioguideID != "S999" {
		t.Fatalf("unexpected member id: %q", parsed.Members[0].BioguideID)
	}
	if parsed.Members[0].Position != "yea" {
		t.Fatalf("unexpected member position: %q", parsed.Members[0].Position)
	}
}
