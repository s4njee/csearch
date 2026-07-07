// ============================================================================
// stats.rs — Simple counters for tracking scraper run statistics
// ============================================================================
//
// This is a plain data struct with no behavior beyond a single helper method.
// In Python, you'd likely use a `@dataclass`. In JS, just a plain object.
//
// `#[derive(Debug, Default)]`:
//   - `Debug`: auto-generates a way to print the struct for debugging
//     (like Python's `__repr__`).
//   - `Default`: auto-generates a constructor that zeros out all numeric
//     fields. So `RunStats::default()` gives you all zeros — like calling
//     `RunStats(0, 0, 0, 0, 0, 0)`.
//
// `u64` = unsigned 64-bit integer (0 to ~18 quintillion). Unsigned because
// counts can never be negative, and 64-bit gives plenty of headroom.
// ============================================================================

#[derive(Debug, Default)]
pub struct RunStats {
    /// Total bills written (inserted + updated). Kept as the roll-up because
    /// `has_writes()` and the ops run-summary consume it.
    pub bills_processed: u64,
    /// Bills that did not exist before this run (brand-new rows).
    pub bills_inserted: u64,
    /// Bills that already existed and were re-upserted (metadata refresh).
    /// A run can report hundreds of these with zero new bills — e.g. when
    /// congress.gov bumps update_date for cosponsor/text-version tweaks.
    pub bills_updated: u64,
    pub bills_skipped: u64,
    pub bills_failed: u64,
    pub votes_processed: u64,
    pub votes_skipped: u64,
    pub votes_failed: u64,
}

impl RunStats {
    /// Returns true if any bills or votes were actually written to the database.
    /// Used to decide whether to clear the Redis cache.
    pub fn has_writes(&self) -> bool {
        self.bills_processed > 0 || self.votes_processed > 0
    }
}
