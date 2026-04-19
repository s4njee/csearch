// ============================================================================
// bills.rs — Bill data processing pipeline (orchestrator)
// ============================================================================
//
// This is the largest and most complex module. It handles:
//   1. Syncing bill data from Congress.gov (via Python subprocess)
//   2. Processing 8 bill types across congresses 93 to present
//   3. Parsing bills from two XML schemas (legacy + new) and JSON
//   4. Writing parsed bills to PostgreSQL with all related data
//      (actions, cosponsors, committees, subjects) in a single transaction
//
// The parallel processing architecture is identical to votes.rs:
//   Phase 1: Parse files on blocking thread pool (semaphore-gated, 64 workers)
//   Phase 2: Write to database (semaphore-gated, 4 concurrent)
//
// Submodules:
//   - bills_parse_json  — parse_bill_json() and JSON helpers
//   - bills_parse_xml   — parse_bill_xml(), legacy fallback, and XML helpers
//   - bills_write       — insert_parsed_bill(), write_bills_seed/incremental()
//
// ============================================================================

// Submodules are declared in main.rs (sibling files, not a directory module).
// See bills_parse_json.rs, bills_parse_xml.rs, bills_write.rs.

use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Arc;

use anyhow::{Context, Result};
// `quick_xml::de::from_str` deserializes XML strings into Rust structs,
// just like `serde_json::from_str` does for JSON. It uses the same `serde`
// framework, so the same `#[serde(rename = "...")]` annotations work.
use sqlx::PgPool;
use tokio::sync::Semaphore;
use tokio::task::JoinSet;
use tracing::{info, warn};

use crate::config::{BILLS_START_CONGRESS, BillWriteMode, Config};
use crate::hashes::{FileHashStore, sha256_file};
use crate::models::ParsedBill;
use crate::python::run_congress_task;
use crate::stats::RunStats;
use crate::util::file_exists;

use crate::bills_parse_json::parse_bill_json;
use crate::bills_parse_xml::parse_bill_xml;
use crate::bills_write::{write_bills_incremental, write_bills_seed};

/// The 8 types of congressional bills/resolutions.
/// `&[&str]` is a slice of string references — a fixed-size array known at
/// compile time. Unlike `Vec`, it lives in the program's read-only data section.
const BILL_TABLES: &[&str] = &[
    "s", "hr", "hconres", "hjres", "hres", "sconres", "sjres", "sres",
];
const WORKER_LIMIT: usize = 64;

/// A function pointer type for bill parsers.
///
/// `type` creates a type alias — a shorthand name for a complex type.
/// `fn(&Path) -> Result<ParsedBill>` is a function pointer — it stores
/// a reference to a function that takes a `&Path` and returns a `Result`.
///
/// This lets us dynamically choose between `parse_bill_xml` and
/// `parse_bill_json` at runtime, based on which file format is available.
/// Like storing a function reference in Python: `parser = parse_bill_xml`.
type BillParser = fn(&Path) -> Result<ParsedBill>;

/// A pending bill file with its parser function.
pub(crate) struct BillJob {
    pub(crate) path: PathBuf,
    /// Which parser to use (XML or JSON). This is a function pointer —
    /// we call it with `(job.parse)(&job.path)`.
    pub(crate) parse: BillParser,
    /// Human-readable bill identifier for error messages.
    pub(crate) display: String,
}

/// A bill that was parsed and found to have changed.
pub(crate) struct ChangedBill {
    pub(crate) parsed_bill: ParsedBill,
    pub(crate) path: PathBuf,
    pub(crate) hash: String,
}

/// Aggregated results from the parsing phase.
struct BillCollectResult {
    changed_bills: Vec<ChangedBill>,
    skipped: u32,
    failed: u32,
}

/// Outcome of parsing a single bill file.
/// Same pattern as `VoteParseOutcome` in votes.rs.
enum BillParseOutcome {
    Changed(ChangedBill),
    Skipped,
}

// ============================================================================
// Public API
// ============================================================================

/// Syncs bill data from Congress.gov using the Python govinfo tool.
/// Runs: `python3 run.py govinfo --bulkdata=BILLSTATUS --congress=N`
pub async fn update_bills(cfg: &Config) -> Result<()> {
    let congress = cfg.target_congress;
    if let Err(err) = run_congress_task(
        cfg,
        &[
            "govinfo",
            "--bulkdata=BILLSTATUS",
            &format!("--congress={congress}"),
        ],
    )
    .await
    {
        warn!(congress, error = %err, "bill sync skipped");
    }
    Ok(())
}

/// Processes bill data for all congress sessions from the first supported
/// bill congress through the configured target congress.
///
/// For each congress, processes all 8 bill types (s, hr, hconres, etc.).
/// The inner loop structure means we process one bill type at a time
/// within each congress, allowing fine-grained progress logging.
pub async fn process_bills(
    pool: &PgPool,
    cfg: &Config,
    hashes: &mut FileHashStore,
    stats: &mut RunStats,
) -> Result<()> {
    for congress in BILLS_START_CONGRESS..=cfg.target_congress {
        // Iterate over each bill type (s, hr, hconres, hjres, etc.)
        for table in BILL_TABLES {
            let jobs = match bill_jobs_for_table(cfg, congress, table) {
                Ok(jobs) => jobs,
                Err(err) => {
                    warn!(congress, billtype = *table, error = %err, "skipping congress bill type");
                    stats.bills_failed += 1;
                    continue;
                }
            };

            info!(
                congress,
                billtype = *table,
                candidates = jobs.len(),
                "processing congress bill type"
            );

            let bill_candidates = jobs.len() as u32;

            // Phase 1: Parse changed bills in parallel.
            let collected = collect_changed_bills(jobs, hashes, congress, table).await;
            let changed_candidates = collected.changed_bills.len() as u32;
            stats.bills_skipped += u64::from(collected.skipped);
            stats.bills_failed += u64::from(collected.failed);

            let (table_processed, table_failed) = match cfg.bill_write_mode {
                BillWriteMode::Incremental => {
                    write_bills_incremental(
                        pool,
                        cfg,
                        hashes,
                        stats,
                        congress,
                        table,
                        collected.changed_bills,
                        collected.failed,
                    )
                    .await
                }
                BillWriteMode::Seed => {
                    write_bills_seed(
                        pool,
                        cfg,
                        hashes,
                        stats,
                        congress,
                        table,
                        collected.changed_bills,
                        collected.failed,
                    )
                    .await
                }
            };

            info!(
                congress,
                billtype = *table,
                candidates = bill_candidates,
                changed = changed_candidates,
                skipped = collected.skipped,
                processed = table_processed,
                failed = table_failed,
                "congress bill type done"
            );
        }

        // Save hashes after each congress (checkpoint for crash recovery).
        hashes
            .save()
            .with_context(|| format!("persist bill hashes for congress {congress}"))?;
    }

    Ok(())
}

// ============================================================================
// File discovery
// ============================================================================

/// Discovers all bill files for a given congress and bill type.
///
/// Directory structure:
///   {congress_dir}/congress/data/{congress}/bills/{type}/{number}/
///     - fdsys_billstatus.xml  (preferred — newer, more complete)
///     - data.json             (fallback — older format)
///
/// Returns a Vec<BillJob> where each job has the appropriate parser function.
fn bill_jobs_for_table(cfg: &Config, congress: i32, table: &str) -> Result<Vec<BillJob>> {
    let directory = cfg
        .congress_dir
        .join("congress")
        .join("data")
        .join(congress.to_string())
        .join("bills")
        .join(table);
    let entries = fs::read_dir(directory)?;

    let mut jobs = Vec::new();
    for entry in entries {
        let entry = entry?;
        let base = entry.path();

        // Prefer XML format (newer, more fields).
        let xml_path = base.join("fdsys_billstatus.xml");
        if file_exists(&xml_path) {
            jobs.push(BillJob {
                path: xml_path,
                // `parse_bill_xml` is a function pointer — we store the
                // function itself (not a call to it) so we can call it later.
                parse: parse_bill_xml,
                display: entry.file_name().to_string_lossy().into_owned(),
            });
            continue;
        }

        // Fall back to JSON format.
        let json_path = base.join("data.json");
        if !file_exists(&json_path) {
            continue;
        }

        jobs.push(BillJob {
            path: json_path,
            parse: parse_bill_json,
            display: entry.file_name().to_string_lossy().into_owned(),
        });
    }

    Ok(jobs)
}

// ============================================================================
// Phase 1: Parallel bill parsing
// ============================================================================

/// Same pattern as `collect_changed_votes` in votes.rs.
/// See that function for detailed comments on Arc, Semaphore, JoinSet, etc.
async fn collect_changed_bills(
    jobs: Vec<BillJob>,
    hashes: &FileHashStore,
    congress: i32,
    billtype: &str,
) -> BillCollectResult {
    let known_hashes = Arc::new(hashes.snapshot());
    let parse_sem = Arc::new(Semaphore::new(WORKER_LIMIT));
    let mut tasks = JoinSet::new();

    for job in jobs {
        let known_hashes = known_hashes.clone();
        let parse_sem = parse_sem.clone();
        tasks.spawn(async move {
            let _permit = parse_sem.acquire_owned().await?;
            // Offload CPU-heavy XML/JSON parsing to blocking thread pool.
            tokio::task::spawn_blocking(move || parse_bill_job(job, &known_hashes)).await?
        });
    }

    let mut changed_bills = Vec::new();
    let mut skipped = 0u32;
    let mut failed = 0u32;
    while let Some(result) = tasks.join_next().await {
        match result {
            Ok(Ok(BillParseOutcome::Changed(changed_bill))) => changed_bills.push(changed_bill),
            Ok(Ok(BillParseOutcome::Skipped)) => skipped += 1,
            Ok(Err(err)) => {
                warn!(congress, billtype, error = %err, "unable to parse bill");
                failed += 1;
            }
            Err(err) => {
                warn!(congress, billtype, error = %err, "bill parse task failed");
                failed += 1;
            }
        }
    }

    BillCollectResult {
        changed_bills,
        skipped,
        failed,
    }
}

/// Synchronous: checks if a bill file has changed and parses it if so.
/// Runs on the blocking thread pool via `spawn_blocking`.
fn parse_bill_job(
    job: BillJob,
    known_hashes: &HashMap<String, String>,
) -> Result<BillParseOutcome> {
    let hash =
        sha256_file(&job.path).with_context(|| format!("hash bill {}", job.path.display()))?;
    let key = job.path.to_string_lossy();
    if known_hashes.get(key.as_ref()) == Some(&hash) {
        return Ok(BillParseOutcome::Skipped);
    }

    // Call the parser function (either parse_bill_xml or parse_bill_json)
    // via the function pointer stored in the job.
    // `(job.parse)(&job.path)` — parentheses around `job.parse` are needed
    // to call a function pointer stored in a struct field.
    let parsed_bill = (job.parse)(&job.path)
        .with_context(|| format!("parse bill {} ({})", job.display, job.path.display()))?;

    Ok(BillParseOutcome::Changed(ChangedBill {
        parsed_bill,
        path: job.path,
        hash,
    }))
}

// ============================================================================
// Status helpers
// ============================================================================

/// Normalizes a raw status string to one of our standard status values.
///
/// First tries to match the raw status against known keywords. If the raw
/// status is empty or unrecognized, falls back to keyword-matching against
/// the latest action text via `derive_bill_status`.
pub(crate) fn normalize_bill_status(raw_status: &str, latest_action_text: &str) -> String {
    let status = raw_status.trim().to_ascii_lowercase();
    if status.is_empty() {
        return derive_bill_status(latest_action_text);
    }
    if status.contains("enact") {
        "enacted".to_string()
    } else if status.contains("veto") {
        "vetoed".to_string()
    } else if status.contains("pass") {
        "passed".to_string()
    } else if status.contains("report") {
        "reported".to_string()
    } else if status.contains("refer") {
        "referred".to_string()
    } else if status.contains("introduc") {
        "introduced".to_string()
    } else if status.contains("active") {
        "active".to_string()
    } else {
        // Unrecognized raw status — fall back to deriving from action text.
        derive_bill_status(latest_action_text)
    }
}

/// Derives a bill status from the latest action text when no explicit
/// status is provided. Uses keyword matching (contains checks).
fn derive_bill_status(latest_action_text: &str) -> String {
    let text = latest_action_text.to_ascii_lowercase();
    if text.is_empty() {
        "introduced".to_string()
    } else if text.contains("enact") {
        "enacted".to_string()
    } else if text.contains("veto") {
        "vetoed".to_string()
    } else if text.contains("pass") {
        "passed".to_string()
    } else if text.contains("report") {
        "reported".to_string()
    } else if text.contains("refer") {
        "referred".to_string()
    } else if text.contains("introduc") {
        "introduced".to_string()
    } else {
        "active".to_string()
    }
}

// ============================================================================
// Tests
// ============================================================================
#[cfg(test)]
mod tests {
    use std::fs;

    use super::*;
    use tempfile::tempdir;

    #[test]
    fn parse_bill_json_builds_normalized_bill() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("data.json");
        let payload = r#"{
          "number": "42",
          "bill_type": "hr",
          "introduced_at": "2024-01-10",
          "congress": "118",
          "status": "",
          "summary": {
            "date": "2024-01-11",
            "text": "Summary text"
          },
          "actions": [
            {
              "acted_at": "2024-01-12",
              "text": "Passed House",
              "type": "vote"
            }
          ],
          "sponsor": {
            "title": "Rep.",
            "name": "Example",
            "state": "IL",
            "party": "D"
          },
          "cosponsors": [],
          "status_at": "2024-01-12",
          "short_title": "Example Act",
          "official_title": "Example Act Official"
        }"#;

        fs::write(&path, payload).unwrap();

        let parsed = parse_bill_json(&path).unwrap();
        assert_eq!(parsed.bill.billnumber, 42);
        assert_eq!(parsed.bill.billtype, "hr");
        assert_eq!(parsed.bill.congress, 118);
        // Status "" + latest action "Passed House" -> "passed"
        assert_eq!(parsed.bill.bill_status, "passed");
        assert_eq!(parsed.actions.len(), 1);
        assert_eq!(parsed.bill.shorttitle.as_deref(), Some("Example Act"));
    }
}
