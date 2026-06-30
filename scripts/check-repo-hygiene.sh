#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

fail=0

report_matches() {
  local title="$1"
  local matches="$2"

  if [[ -n "$matches" ]]; then
    fail=1
    printf '\n%s\n' "$title" >&2
    printf '%s\n' "$matches" | sed 's/^/  /' >&2
  fi
}

tracked_files="$(git ls-files)"

duplicate_files="$(printf '%s\n' "$tracked_files" | rg '(^|/)[^/]+ 2\.[^/]+$' || true)"
report_matches "Duplicate copy/conflict files are tracked:" "$duplicate_files"

generated_files="$(
  printf '%s\n' "$tracked_files" |
    rg '^(backend/scraper/congress/data/|backend/scraper/congress/env/|backend/scraper/data/|backend/api/data/|backend/nlp/project-tarp/data/|frontend/\.output/|\.codex-.+)|(^|/)(__pycache__/|\.pytest_cache/|\.mypy_cache/|\.ruff_cache/|\.venv/|env/|target/|node_modules/)|\.pyc$' || true
)"
report_matches "Generated, runtime, or local environment artifacts are tracked:" "$generated_files"

legacy_archive_files="$(
  printf '%s\n' "$tracked_files" |
    rg '^k8s/archive/' |
    rg -v '^k8s/archive/README\.md$' || true
)"
report_matches "Legacy Kubernetes manifests are tracked outside the archive pointer:" "$legacy_archive_files"

if printf '%s\n' "$tracked_files" | rg -q '^deploy\.sh$'; then
  report_matches "Root legacy deploy script is tracked:" "deploy.sh"
fi

stale_doc_refs="$(
  git grep -n -E \
    'Fastify|cache\.js|backend/api/utils|backend/api/controllers|S3/CloudFront|CloudFront|Qdrant|k8s/archive/legacy|mars-images' \
    -- '*.md' ':!docs/archive/**' ':!docs/CRITICISMS.md' ':!research/**' || true
)"
report_matches "Active docs contain retired implementation or deployment references:" "$stale_doc_refs"

max_bytes=$((5 * 1024 * 1024))
large_files=""
while IFS= read -r file; do
  [[ -f "$file" ]] || continue

  if size="$(stat -c '%s' "$file" 2>/dev/null)"; then
    :
  else
    size="$(stat -f '%z' "$file")"
  fi

  if (( size > max_bytes )); then
    large_files+="${file} (${size} bytes)"$'\n'
  fi
done < <(printf '%s\n' "$tracked_files")
report_matches "Tracked files exceed 5 MiB and should be justified or moved out of git:" "$large_files"

if (( fail )); then
  printf '\nRepo hygiene check failed.\n' >&2
  exit 1
fi

printf 'Repo hygiene check passed.\n'
