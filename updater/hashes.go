package main

import (
	"crypto/sha256"
	"encoding/gob"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sync"
)

// fileHashStore tracks the last ingested digest for each source file so reruns
// can skip unchanged bill and vote payloads.
type fileHashStore struct {
	path   string
	hashes map[string]string
	mu     sync.RWMutex
}

// loadFileHashStore deserializes a previously saved gob cache of file hashes
// or returns a new empty store if the file does not exist.
func loadFileHashStore(path string) (*fileHashStore, error) {
	store := &fileHashStore{
		path:   path,
		hashes: make(map[string]string),
	}

	if _, err := os.Stat(path); err != nil {
		if os.IsNotExist(err) {
			return store, nil
		}
		return nil, err
	}

	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	if err := gob.NewDecoder(file).Decode(&store.hashes); err != nil {
		return nil, err
	}

	return store, nil
}

// NeedsProcessing computes the current digest and reports whether the file
// differs from the last successful ingest without mutating the cache yet.
func (s *fileHashStore) NeedsProcessing(path string) (string, bool, error) {
	hash, err := sha256File(path)
	if err != nil {
		return "", false, err
	}

	s.mu.RLock()
	previous := s.hashes[path]
	s.mu.RUnlock()

	if previous == hash {
		return hash, false, nil
	}

	return hash, true, nil
}

// MarkProcessed updates the cache with a new digest for the given path.
func (s *fileHashStore) MarkProcessed(path string, hash string) {
	s.mu.Lock()
	s.hashes[path] = hash
	s.mu.Unlock()
}

// Save serializes the current hash map to disk so future runs can skip
// previously ingested payloads.
func (s *fileHashStore) Save() error {
	if err := os.MkdirAll(filepath.Dir(s.path), 0o755); err != nil {
		return err
	}

	file, err := os.Create(s.path)
	if err != nil {
		return err
	}
	defer file.Close()

	s.mu.RLock()
	defer s.mu.RUnlock()

	return gob.NewEncoder(file).Encode(s.hashes)
}

// sha256File computes the SHA-256 digest of the file at the given path.
func sha256File(path string) (string, error) {
	file, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer file.Close()

	sum := sha256.New()
	if _, err := io.Copy(sum, file); err != nil {
		return "", err
	}

	return fmt.Sprintf("%x", sum.Sum(nil)), nil
}
