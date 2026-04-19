// ============================================================================
// bills_write.rs — Bill database write operations
// ============================================================================
//
// This module handles writing parsed bills to PostgreSQL. It contains:
//   - `insert_parsed_bill` / `insert_parsed_bill_in_tx`: single-bill upsert
//   - `write_bills_incremental`: one transaction per bill (low-memory, safe)
//   - `write_bills_seed`: chunked batch transactions (fast initial load)
//   - `write_bill_seed_chunk`: one transaction per chunk with fallback to
//     per-bill retry on failure
// ============================================================================

use std::sync::Arc;

use anyhow::{Context, Result, anyhow};
use sqlx::{PgPool, Postgres, Transaction};
use tokio::sync::Semaphore;
use tokio::task::JoinSet;
use tracing::{info, warn};

use crate::config::Config;
use crate::db;
use crate::hashes::FileHashStore;
use crate::models::InsertCommitteeParams;
use crate::stats::RunStats;
use crate::util::option_string;

use crate::models::ParsedBill;

use crate::bills::ChangedBill;

/// Inserts a parsed bill and ALL its related data in a single transaction.
///
/// This is the most complex DB operation. In one atomic transaction:
///   1. Upsert the bill record
///   2. Clear + re-insert actions (and link the latest action)
///   3. Clear + re-insert cosponsors
///   4. Upsert committees + clear + re-insert bill-committee associations
///   5. Clear + re-insert subjects
///
/// If ANY step fails, the entire transaction is rolled back (nothing is
/// partially written). This ensures data consistency.
pub(crate) async fn insert_parsed_bill(pool: &PgPool, parsed_bill: &ParsedBill) -> Result<()> {
    let mut tx = pool.begin().await?;
    insert_parsed_bill_in_tx(&mut tx, parsed_bill).await?;
    tx.commit().await?;
    Ok(())
}

pub(crate) async fn insert_parsed_bill_in_tx(
    tx: &mut Transaction<'_, Postgres>,
    parsed_bill: &ParsedBill,
) -> Result<()> {
    let bill = &parsed_bill.bill;

    // Validate required fields before starting the transaction.
    if bill.billnumber == 0 || bill.billtype.is_empty() {
        return Err(anyhow!(
            "skipping bill with empty number/type (congress={}, id={})",
            bill.congress,
            // `.clone().unwrap_or_default()` — clone the Option<String>,
            // then unwrap to the inner String or an empty string if None.
            bill.billid.clone().unwrap_or_default()
        ));
    }
    if bill.bill_status.is_empty() {
        return Err(anyhow!(
            "skipping bill {}-{}-{}: bill_status is empty",
            bill.congress,
            bill.billtype,
            bill.billnumber
        ));
    }
    if bill.statusat.is_none() {
        return Err(anyhow!(
            "skipping bill {}-{}-{}: statusat is empty",
            bill.congress,
            bill.billtype,
            bill.billnumber
        ));
    }

    // Step 1: Upsert the bill row.
    db::insert_bill(tx, bill).await.with_context(|| {
        format!(
            "InsertBill failed for {}-{}-{}",
            bill.congress, bill.billtype, bill.billnumber
        )
    })?;

    // Step 2: Replace actions (clear latest_action, delete old, batch insert
    // new, set latest_action) — all in one SQL round-trip.
    db::replace_bill_actions(
        tx,
        &bill.billtype,
        bill.billnumber,
        bill.congress,
        &parsed_bill.actions,
        parsed_bill.latest_action_date,
        &parsed_bill.latest_action_text,
    )
    .await
    .context("ReplaceBillActions failed")?;

    // Step 3: Replace cosponsors — one round-trip.
    db::replace_bill_cosponsors(
        tx,
        &bill.billtype,
        bill.billnumber,
        bill.congress,
        &parsed_bill.cosponsors,
    )
    .await
    .context("ReplaceBillCosponsors failed")?;

    // Step 4: Upsert committees + replace bill_committees — one round-trip.
    let committee_params: Vec<InsertCommitteeParams> = parsed_bill
        .committees
        .iter()
        .map(|c| InsertCommitteeParams {
            committee_code: c.committee_code.clone(),
            committee_name: option_string(c.committee_name.clone()),
            chamber: option_string(c.chamber.clone()),
        })
        .collect();
    db::replace_bill_committees(
        tx,
        &bill.billtype,
        bill.billnumber,
        bill.congress,
        &committee_params,
    )
    .await
    .context("ReplaceBillCommittees failed")?;

    // Step 5: Replace subjects — one round-trip.
    db::replace_bill_subjects(
        tx,
        &bill.billtype,
        bill.billnumber,
        bill.congress,
        &parsed_bill.subjects,
    )
    .await
    .context("ReplaceBillSubjects failed")?;

    Ok(())
}

pub(crate) async fn write_bills_incremental(
    pool: &PgPool,
    cfg: &Config,
    hashes: &mut FileHashStore,
    stats: &mut RunStats,
    congress: i32,
    table: &str,
    changed_bills: Vec<ChangedBill>,
    initial_failed: u32,
) -> (u32, u32) {
    let write_sem = Arc::new(Semaphore::new(cfg.db_write_concurrency as usize));
    let mut write_tasks = JoinSet::new();

    for changed_bill in changed_bills {
        let pool = pool.clone();
        let write_sem = write_sem.clone();
        let billtype = table.to_string();
        write_tasks.spawn(async move {
            let _permit = write_sem.acquire_owned().await?;
            insert_parsed_bill(&pool, &changed_bill.parsed_bill).await?;
            Ok::<_, anyhow::Error>((changed_bill, billtype))
        });
    }

    let mut table_processed = 0u32;
    let mut table_failed = initial_failed;
    while let Some(result) = write_tasks.join_next().await {
        match result {
            Ok(Ok((changed_bill, _billtype))) => {
                hashes.mark_processed(&changed_bill.path, changed_bill.hash);
                stats.bills_processed += 1;
                table_processed += 1;
            }
            Ok(Err(err)) => {
                warn!(congress, billtype = table, error = %err, "unable to insert bill");
                stats.bills_failed += 1;
                table_failed += 1;
            }
            Err(err) => {
                warn!(congress, billtype = table, error = %err, "bill write task failed");
                stats.bills_failed += 1;
                table_failed += 1;
            }
        }
    }

    (table_processed, table_failed)
}

pub(crate) async fn write_bills_seed(
    pool: &PgPool,
    cfg: &Config,
    hashes: &mut FileHashStore,
    stats: &mut RunStats,
    congress: i32,
    table: &str,
    changed_bills: Vec<ChangedBill>,
    initial_failed: u32,
) -> (u32, u32) {
    let mut table_processed = 0u32;
    let mut table_failed = initial_failed;
    let total_chunks = changed_bills.len().div_ceil(cfg.bill_seed_chunk_size);
    let mut pending = changed_bills.into_iter();
    let mut write_tasks = JoinSet::new();
    let write_sem = Arc::new(Semaphore::new(cfg.db_write_concurrency as usize));
    let db_write_concurrency = cfg.db_write_concurrency;

    for chunk_index in 0..total_chunks {
        let chunk: Vec<ChangedBill> = pending.by_ref().take(cfg.bill_seed_chunk_size).collect();
        let pool = pool.clone();
        let write_sem = write_sem.clone();
        let billtype = table.to_string();

        write_tasks.spawn(async move {
            let _permit = write_sem.acquire_owned().await?;
            info!(
                congress,
                billtype = billtype.as_str(),
                chunk_index = chunk_index + 1,
                total_chunks,
                chunk_size = chunk.len(),
                db_write_concurrency,
                "processing seed bill chunk"
            );

            let result = write_bill_seed_chunk(&pool, chunk).await;
            Ok::<_, anyhow::Error>((chunk_index + 1, result))
        });
    }

    while let Some(result) = write_tasks.join_next().await {
        match result {
            Ok(Ok((chunk_index, Ok(chunk)))) => {
                for changed_bill in &chunk {
                    hashes.mark_processed(&changed_bill.path, changed_bill.hash.clone());
                    stats.bills_processed += 1;
                    table_processed += 1;
                }

                info!(
                    congress,
                    billtype = table,
                    chunk_index,
                    total_chunks,
                    chunk_size = chunk.len(),
                    processed_total = table_processed,
                    "seed bill chunk committed"
                );
            }
            Ok(Ok((chunk_index, Err((err, chunk))))) => {
                warn!(
                    congress,
                    billtype = table,
                    chunk_index,
                    total_chunks,
                    chunk_size = chunk.len(),
                    error = %err,
                    "seed bill chunk failed; retrying bills individually"
                );

                for changed_bill in &chunk {
                    match insert_parsed_bill(pool, &changed_bill.parsed_bill).await {
                        Ok(()) => {
                            hashes.mark_processed(&changed_bill.path, changed_bill.hash.clone());
                            stats.bills_processed += 1;
                            table_processed += 1;
                        }
                        Err(err) => {
                            warn!(
                                congress,
                                billtype = table,
                                error = %err,
                                "unable to insert bill after chunk fallback"
                            );
                            stats.bills_failed += 1;
                            table_failed += 1;
                        }
                    }
                }

                info!(
                    congress,
                    billtype = table,
                    chunk_index,
                    total_chunks,
                    chunk_size = chunk.len(),
                    processed_total = table_processed,
                    failed_total = table_failed,
                    "seed bill chunk fallback complete"
                );
            }
            Ok(Err(err)) => {
                warn!(congress, billtype = table, error = %err, "seed bill chunk task failed");
                stats.bills_failed += 1;
                table_failed += 1;
            }
            Err(err) => {
                warn!(congress, billtype = table, error = %err, "seed bill join task failed");
                stats.bills_failed += 1;
                table_failed += 1;
            }
        }
    }

    (table_processed, table_failed)
}

pub(crate) async fn write_bill_seed_chunk(
    pool: &PgPool,
    chunk: Vec<ChangedBill>,
) -> std::result::Result<Vec<ChangedBill>, (anyhow::Error, Vec<ChangedBill>)> {
    let mut tx = match pool.begin().await {
        Ok(tx) => tx,
        Err(err) => return Err((err.into(), chunk)),
    };

    for changed_bill in &chunk {
        if let Err(err) = insert_parsed_bill_in_tx(&mut tx, &changed_bill.parsed_bill).await {
            return Err((err, chunk));
        }
    }

    if let Err(err) = tx.commit().await {
        return Err((err.into(), chunk));
    }

    Ok(chunk)
}
