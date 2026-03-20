# Vendored Python Congress Scraper

This directory is a vendored copy of the upstream `unitedstates/congress` Python project. In CSearch, it is used as the low-level fetcher for raw congressional source data.

Most engineers working on CSearch should start with [`../README.md`](../README.md), not with this directory.

## Why This Directory Exists

The CSearch scraper intentionally splits responsibilities:

- this vendored Python project fetches raw bill and vote source files
- the Go updater in `backend/scraper/` parses those files and writes normalized rows into Postgres

## When You Probably Need To Edit This Code

Edit this directory only when:

- upstream source acquisition behavior changes
- a GovInfo or congress.gov fetch format changes
- the Go updater needs different raw files than the current fetch pipeline produces

If the problem is about normalized bill or vote records in Postgres, the fix is usually in:

- `../bills.go`
- `../votes.go`
- `../runtime.go`

## Upstream Context

This code originated in the public `unitedstates/congress` project. The original upstream documentation focuses on the standalone Python scraper, but in this repository the Python code is only one part of a larger Go + Python ingest pipeline.

For the CSearch-specific runtime model, environment variables, and debugging workflow, use [`../README.md`](../README.md).
