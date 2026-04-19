// ============================================================================
// bills_parse_xml.rs — Bill parsing from the newer XML data format
// ============================================================================
//
// This module handles bills stored as `fdsys_billstatus.xml` files. Congress.gov
// uses two distinct XML schemas:
//
//   - **New schema** (used from roughly the 113th Congress onward): fields named
//     `<number>` and `<type>`, with richer metadata including committees,
//     subjects, and structured sponsor/cosponsor records.
//
//   - **Legacy schema** (used before the new schema cutoff): fields named
//     `<billNumber>` and `<billType>`. A bill file uses the legacy schema
//     when the `<number>` field is empty after parsing with the new struct.
//
// The new schema was introduced around Congress.gov v3.0.0 (approximately the
// 113th Congress / 2013). Older files retain the legacy tag names.
// ============================================================================

use std::fs;
use std::path::Path;

use anyhow::{Context, Result};
use quick_xml::de::from_str;

use crate::models::{
    ActionsXml, BillJson, BillXmlRootLegacy, BillXmlRootNew, CommitteesXml, CosponsorsXml,
    InsertBillActionParams, InsertBillCosponsorParams, InsertBillParams, InsertBillSubjectParams,
    ParsedBill, ParsedCommittee, SponsorsXml, SubjectsXml, TitlesXml, XmlSummaries,
};
use crate::util::{file_exists, must_parse_date_value, option_string, parse_date_value, parse_i32_value};

use crate::bills::normalize_bill_status;

/// Parses a bill from XML format (fdsys_billstatus.xml).
///
/// Congress.gov has two XML schemas:
///   - **New format**: Uses `<number>` and `<type>` tags (newer congresses)
///   - **Legacy format**: Uses `<billNumber>` and `<billType>` tags (older congresses)
///
/// We try the new format first. If the `number` field is empty (indicating
/// the XML uses the legacy schema), we re-parse with the legacy struct.
pub(crate) fn parse_bill_xml(path: &Path) -> Result<ParsedBill> {
    let data = fs::read_to_string(path)?;

    // Try new XML format first.
    // `from_str` is `quick_xml::de::from_str` — XML deserialization.
    let root_new: BillXmlRootNew = from_str(&data)?;
    let bill = root_new.bill;

    // Determine bill type from whichever field is populated.
    let bill_type = if bill.bill_type_new.is_empty() {
        bill.bill_type.to_ascii_lowercase()
    } else {
        bill.bill_type_new.to_ascii_lowercase()
    };

    // Try to get bill status from a companion data.json file (sidecar).
    let bill_status = bill_status_from_sidecar(path);

    // If the number field is populated, we successfully parsed the new format.
    if !bill.number.is_empty() {
        let bill_number = parse_i32_value(&bill.number)
            .with_context(|| format!("parse bill number for {}", path.display()))?;
        let congress = parse_i32_value(&bill.congress)
            .with_context(|| format!("parse congress for {}", path.display()))?;
        return build_parsed_bill(
            bill_number,
            bill_type,
            &bill.introduced_at,
            &bill.update_date,
            &bill.origin_chamber,
            congress,
            &bill.short_title,
            &bill.latest_action.action_date,
            &bill.latest_action.text,
            bill.summary,
            bill.actions,
            bill.sponsors,
            bill.cosponsors,
            bill.titles,
            bill.committees,
            bill.subjects,
            &bill_status,
        );
    }

    // Fall back to legacy XML format (pre-v3.0.0 schema, older congresses).
    let root_legacy: BillXmlRootLegacy = from_str(&data)?;
    let legacy_bill = root_legacy.bill;
    let bill_number = parse_i32_value(&legacy_bill.number)
        .with_context(|| format!("parse bill number for {}", path.display()))?;
    let congress = parse_i32_value(&legacy_bill.congress)
        .with_context(|| format!("parse congress for {}", path.display()))?;

    build_parsed_bill(
        bill_number,
        legacy_bill.bill_type.to_ascii_lowercase(),
        &legacy_bill.introduced_at,
        &legacy_bill.update_date,
        &legacy_bill.origin_chamber,
        congress,
        &legacy_bill.short_title,
        &legacy_bill.latest_action.action_date,
        &legacy_bill.latest_action.text,
        legacy_bill.summary,
        legacy_bill.actions,
        legacy_bill.sponsors,
        legacy_bill.cosponsors,
        legacy_bill.titles,
        legacy_bill.committees,
        legacy_bill.subjects,
        &bill_status,
    )
}

/// Builds a `ParsedBill` from XML-extracted components.
///
/// `#[allow(clippy::too_many_arguments)]` suppresses a lint warning about
/// having too many function parameters. Normally Clippy (Rust's linter)
/// suggests refactoring, but here we accept it since this is a data
/// transformation function that needs all these inputs.
///
/// This function is shared between new and legacy XML formats.
#[allow(clippy::too_many_arguments)]
pub(crate) fn build_parsed_bill(
    number: i32,
    bill_type: String,
    introduced_at: &str,
    update_date: &str,
    origin_chamber: &str,
    congress: i32,
    short_title: &str,
    latest_action_date: &str,
    latest_action_text: &str,
    summary: XmlSummaries,
    actions: ActionsXml,
    sponsors: SponsorsXml,
    cosponsors: CosponsorsXml,
    titles: TitlesXml,
    committees: CommitteesXml,
    subjects: SubjectsXml,
    bill_status: &str,
) -> Result<ParsedBill> {
    // Use provided latest action date/text, or derive from actions list.
    let mut latest_action_date_value = latest_action_date.to_string();
    let mut latest_action_text_value = latest_action_text.to_string();

    let (derived_latest_action_date, derived_latest_action_text) = latest_xml_action(&actions);
    if latest_action_date_value.is_empty() {
        latest_action_date_value = derived_latest_action_date;
    }
    if latest_action_text_value.is_empty() {
        latest_action_text_value = derived_latest_action_text;
    }

    // Parse dates, using `.unwrap_or(None)` to silently handle parse failures.
    let parsed_introduced_at = parse_date_value(introduced_at).unwrap_or(None);
    let parsed_update_date = parse_date_value(update_date).unwrap_or(None);
    let parsed_latest_action_date = parse_date_value(&latest_action_date_value).unwrap_or(None);

    // Extract summary from the first summary item (if any).
    // `.first()` returns `Option<&T>` — the first element or None.
    // `.map(|item| ...)` transforms the inner value if present.
    // `.unwrap_or((None, None))` provides the default if no items exist.
    let (summary_date, summary_text) = summary
        .bill_summaries
        .items
        .first()
        .map(|item| {
            (
                option_string(item.date.clone()),
                option_string(item.text.clone()),
            )
        })
        .unwrap_or((None, None));

    // Extract sponsor info from the first sponsor (if any).
    // Same `.first().map(...).unwrap_or(...)` pattern.
    let (sponsor_bioguide_id, sponsor_name, sponsor_state, sponsor_party) = sponsors
        .sponsors
        .first()
        .map(|sponsor| {
            (
                option_string(sponsor.bioguide_id.clone()),
                option_string(sponsor.full_name.clone()),
                option_string(sponsor.state.clone()),
                option_string(sponsor.party.clone()),
            )
        })
        .unwrap_or((None, None, None, None));

    // Use official title if available, fall back to short title.
    let mut official = official_title(&titles);
    if official.is_empty() {
        official = short_title.to_string();
    }

    // Determine status date with fallback chain.
    // `.or_else(|| ...)` is like `.or()` but lazily evaluates the fallback.
    let status_at = parsed_latest_action_date
        .or(parsed_introduced_at)
        .or_else(|| must_parse_date_value(introduced_at));

    let bill = InsertBillParams {
        billid: option_string(format!(
            "{}-{}-{}",
            congress,
            bill_type.to_ascii_uppercase(),
            number
        )),
        billnumber: number,
        billtype: bill_type.clone(),
        introducedat: parsed_introduced_at,
        congress,
        summary_date,
        summary_text,
        sponsor_bioguide_id,
        sponsor_name,
        sponsor_state,
        sponsor_party,
        origin_chamber: option_string(origin_chamber.to_string()),
        policy_area: option_string(subjects.policy_area.name.clone()),
        update_date: parsed_update_date,
        latest_action_date: parsed_latest_action_date,
        bill_status: normalize_bill_status(bill_status, &latest_action_text_value),
        statusat: status_at,
        shorttitle: option_string(short_title.to_string()),
        officialtitle: option_string(official),
    };

    // Parse actions from XML, skipping entries with empty dates.
    let mut parsed_actions = Vec::with_capacity(actions.actions.len());
    for action in actions.actions {
        if action.acted_at.is_empty() {
            continue;
        }
        // `let Some(acted_at) = ... else { continue }` — pattern matching
        // that skips to the next iteration if the date is None or invalid.
        let Some(acted_at) = parse_date_value(&action.acted_at).unwrap_or(None) else {
            continue;
        };

        parsed_actions.push(InsertBillActionParams {
            acted_at,
            action_text: option_string(action.text),
            action_type: option_string(action.item_type),
            action_code: option_string(action.action_code),
            source_system_code: option_string(action.source_system.code),
        });
    }

    // Parse cosponsors, skipping entries without bioguide IDs.
    let mut parsed_cosponsors = Vec::with_capacity(cosponsors.cosponsors.len());
    for cosponsor in cosponsors.cosponsors {
        if cosponsor.bioguide_id.is_empty() {
            continue;
        }

        parsed_cosponsors.push(InsertBillCosponsorParams {
            bioguide_id: cosponsor.bioguide_id,
            full_name: option_string(cosponsor.full_name),
            state: option_string(cosponsor.state),
            party: option_string(cosponsor.party),
            sponsorship_date: must_parse_date_value(&cosponsor.sponsorship_date),
            // Parse "true"/"false" string to bool Option.
            // `.eq_ignore_ascii_case("true")` is case-insensitive comparison.
            is_original_cosponsor: if cosponsor.is_original_cosponsor.is_empty() {
                None
            } else {
                Some(cosponsor.is_original_cosponsor.eq_ignore_ascii_case("true"))
            },
        });
    }

    // Parse committees, skipping entries without system codes.
    let mut parsed_committees = Vec::with_capacity(committees.items.len());
    for committee in committees.items {
        if committee.system_code.is_empty() {
            continue;
        }

        parsed_committees.push(ParsedCommittee {
            committee_code: committee.system_code,
            committee_name: committee.name,
            chamber: committee.chamber,
        });
    }

    // Parse legislative subjects.
    let mut parsed_subjects = Vec::with_capacity(subjects.legislative_subjects.items.len());
    for subject in subjects.legislative_subjects.items {
        if subject.name.is_empty() {
            continue;
        }

        parsed_subjects.push(InsertBillSubjectParams {
            subject: subject.name,
        });
    }

    Ok(ParsedBill {
        bill,
        actions: parsed_actions,
        cosponsors: parsed_cosponsors,
        committees: parsed_committees,
        subjects: parsed_subjects,
        latest_action_date: parsed_latest_action_date,
        latest_action_text: latest_action_text_value,
    })
}

/// Finds the "Official Title" from the titles list.
///
/// `.iter()` creates an iterator over the slice.
/// `.find(|t| ...)` returns the first element matching the predicate.
/// `.map(|t| t.title.clone())` transforms the result if found.
/// `.unwrap_or_default()` returns an empty string if no match.
///
/// This chain is like:
///   next((t.title for t in titles if t.title_type.startswith("Official Title")), "")
/// in Python.
pub(crate) fn official_title(titles: &TitlesXml) -> String {
    titles
        .items
        .iter()
        .find(|title| title.title_type.starts_with("Official Title"))
        .map(|title| title.title.clone())
        .unwrap_or_default()
}

/// Same as `latest_json_action` but for XML action structs.
pub(crate) fn latest_xml_action(actions: &ActionsXml) -> (String, String) {
    let mut latest_date = String::new();
    let mut latest_text = String::new();

    for action in &actions.actions {
        if action.acted_at.is_empty() {
            continue;
        }
        if latest_date.is_empty() || action.acted_at > latest_date {
            latest_date = action.acted_at.clone();
            latest_text = action.text.clone();
        }
    }

    (latest_date, latest_text)
}

/// Reads bill status from a companion data.json file (sidecar).
///
/// Some bills have both XML (for detailed data) and JSON (for status).
/// This reads the JSON sidecar to get the status field.
///
/// `let Ok(data) = ... else { return ... }` — let-else pattern for
/// early return on error. If `fs::read_to_string` fails, we return
/// an empty string instead of propagating the error.
pub(crate) fn bill_status_from_sidecar(path: &Path) -> String {
    let sidecar_path = path.parent().unwrap_or(path).join("data.json");
    if !file_exists(&sidecar_path) {
        return String::new();
    }

    let Ok(data) = fs::read_to_string(sidecar_path) else {
        return String::new();
    };
    let Ok(bill_json) = serde_json::from_str::<BillJson>(&data) else {
        return String::new();
    };

    bill_json.status
}
