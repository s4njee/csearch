// ============================================================================
// bills_parse_json.rs — Bill parsing from the older JSON data format
// ============================================================================
//
// This module handles bills stored as `data.json` files, which are used for
// older congress sessions that pre-date the XML (fdsys_billstatus.xml) format.
// ============================================================================

use std::fs;
use std::path::Path;

use anyhow::{Context, Result, anyhow};

use crate::models::{
    BillJson, BillJsonAction, InsertBillActionParams, InsertBillCosponsorParams, InsertBillParams,
    ParsedBill,
};
use crate::util::{option_string, parse_date_value, parse_i32_value};

use crate::bills::normalize_bill_status;

/// Parses a bill from the older JSON format (used by pre-XML congresses).
pub(crate) fn parse_bill_json(path: &Path) -> Result<ParsedBill> {
    let data = fs::read_to_string(path)?;
    let bill_json: BillJson = serde_json::from_str(&data)?;

    // Build sponsor display name from title + name + state.
    let sponsor_name = if bill_json.sponsor.title.is_empty() {
        format!("{} [{}]", bill_json.sponsor.name, bill_json.sponsor.state)
    } else {
        format!(
            "{} {} [{}]",
            bill_json.sponsor.title, bill_json.sponsor.name, bill_json.sponsor.state
        )
    };

    // Find the most recent action by comparing date strings.
    let (latest_action_date, latest_action_text) = latest_json_action(&bill_json.actions);

    // Parse date fields — the `?` propagates parsing errors.
    let parsed_introduced_at = parse_date_value(&bill_json.introduced_at)
        .with_context(|| format!("parse introduced date for {}", path.display()))?;
    let parsed_status_at = parse_date_value(&bill_json.status_at)
        .with_context(|| format!("parse status date for {}", path.display()))?;
    let parsed_latest_action_date = parse_date_value(&latest_action_date)
        .with_context(|| format!("parse latest action date for {}", path.display()))?;

    // Determine statusat with a fallback chain: status_at -> latest_action -> introduced.
    // `.or()` chains Option values — returns the first `Some(...)` found.
    // Like Python's `a or b or c`.
    let status_at = parsed_status_at
        .or(parsed_latest_action_date)
        .or(parsed_introduced_at)
        .ok_or_else(|| anyhow!("missing status date for {}", path.display()))?;

    let bill_number = parse_i32_value(&bill_json.number)
        .with_context(|| format!("parse bill number for {}", path.display()))?;
    let congress = parse_i32_value(&bill_json.congress)
        .with_context(|| format!("parse congress for {}", path.display()))?;

    let bill_type_lower = bill_json.bill_type.to_ascii_lowercase();
    let bill = InsertBillParams {
        billid: option_string(format!(
            "{}-{}-{}",
            congress, bill_json.bill_type, bill_number
        )),
        billnumber: bill_number,
        billtype: bill_type_lower.clone(),
        introducedat: parsed_introduced_at,
        congress,
        summary_date: option_string(bill_json.summary.date),
        summary_text: option_string(bill_json.summary.text),
        sponsor_bioguide_id: None,
        sponsor_name: option_string(sponsor_name),
        sponsor_state: option_string(bill_json.sponsor.state),
        sponsor_party: option_string(bill_json.sponsor.party),
        origin_chamber: None,
        policy_area: None,
        update_date: None,
        latest_action_date: parsed_latest_action_date,
        bill_status: normalize_bill_status(&bill_json.status, &latest_action_text),
        statusat: Some(status_at),
        shorttitle: option_string(bill_json.short_title),
        officialtitle: option_string(bill_json.official_title),
    };

    // Parse actions into InsertBillActionParams.
    // `Vec::with_capacity(n)` pre-allocates memory — an optimization.
    let mut actions = Vec::with_capacity(bill_json.actions.len());
    for action in bill_json.actions {
        let acted_at = parse_date_value(&action.acted_at)
            .with_context(|| format!("parse action date for {}", path.display()))?
            // `.ok_or_else(...)` converts `None` to an error.
            .ok_or_else(|| anyhow!("missing action date for {}", path.display()))?;

        actions.push(InsertBillActionParams {
            acted_at,
            action_text: option_string(action.text),
            // `r#type` — using the raw identifier syntax because `type` is
            // a reserved keyword in Rust (see models.rs for more on `r#`).
            action_type: option_string(action.r#type),
            action_code: None,
            source_system_code: None,
        });
    }

    // Parse cosponsors.
    let mut cosponsors = Vec::with_capacity(bill_json.cosponsors.len());
    for cosponsor in bill_json.cosponsors {
        let name = if cosponsor.title.is_empty() {
            format!("{} [{}]", cosponsor.name, cosponsor.state)
        } else {
            format!(
                "{} {} [{}]",
                cosponsor.title, cosponsor.name, cosponsor.state
            )
        };
        if name.is_empty() {
            continue;
        }

        cosponsors.push(InsertBillCosponsorParams {
            bioguide_id: String::new(),
            full_name: option_string(name),
            state: option_string(cosponsor.state),
            party: option_string(cosponsor.party),
            sponsorship_date: None,
            is_original_cosponsor: None,
        });
    }

    Ok(ParsedBill {
        bill,
        actions,
        cosponsors,
        committees: Vec::new(), // JSON format doesn't have committee data.
        subjects: Vec::new(),   // JSON format doesn't have subject data.
        latest_action_date: parsed_latest_action_date,
        latest_action_text,
    })
}

/// Finds the most recent action from JSON bill data by comparing date strings.
/// Returns (date_string, text_string).
pub(crate) fn latest_json_action(actions: &[BillJsonAction]) -> (String, String) {
    let mut latest_date = String::new();
    let mut latest_text = String::new();

    for action in actions {
        if action.acted_at.is_empty() {
            continue;
        }
        // String comparison works for ISO dates (YYYY-MM-DD sorts correctly).
        if latest_date.is_empty() || action.acted_at > latest_date {
            latest_date = action.acted_at.clone();
            latest_text = action.text.clone();
        }
    }

    (latest_date, latest_text)
}
