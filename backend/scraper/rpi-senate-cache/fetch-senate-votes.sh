#!/usr/bin/env bash
#
# Fetch the current Congress's Senate roll-call vote XML from senate.gov and
# publish it to the `senate-vote-cache` branch.
#
# Why this exists: senate.gov blocks the netcup (production) datacenter IP, so
# the main pipeline cannot pull Senate votes directly. A US *residential* IP can
# (e.g. a home Raspberry Pi). This script is the standalone equivalent of
# .github/workflows/senate-vote-cache.yml — run it from the RPi on a timer.
#
# It is safe to run alongside the GitHub Action: the publish step is diff-gated,
# so whichever runs first wins and the other no-ops (idempotent).
#
# Config comes from the environment (see senate-vote-cache.env.example):
#   GH_TOKEN     (required) fine-grained PAT with Contents:read+write on the repo
#   REPO_URL     (optional) https clone URL, default github.com/s4njee/csearch
#   SCRAPER_REF  (optional) branch to pull scraper code from, default main
#   WORK_DIR     (optional) state dir, default ~/.local/share/senate-vote-cache
#   CONGRESS     (optional) override target Congress; default = current
#   FORCE        (optional) 1 = re-download all (CI parity), 0 = incremental; default 1

set -euo pipefail

: "${GH_TOKEN:?GH_TOKEN must be set (fine-grained PAT with Contents:read+write)}"
: "${REPO_URL:=https://github.com/s4njee/csearch.git}"
: "${SCRAPER_REF:=main}"
: "${WORK_DIR:=$HOME/.local/share/senate-vote-cache}"
: "${CONGRESS:=}"
: "${FORCE:=1}"

REPO_DIR="$WORK_DIR/repo"
VENV_DIR="$WORK_DIR/venv"
CACHE_DIR="$WORK_DIR/cache-branch"
PAYLOAD_DIR="$WORK_DIR/payload"
CONGRESS_DIR="$REPO_DIR/backend/scraper/congress"

log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }

# ---- 1. up-to-date checkout of the scraper code -----------------------------
mkdir -p "$WORK_DIR"
if [ ! -d "$REPO_DIR/.git" ]; then
  log "cloning $REPO_URL ($SCRAPER_REF)"
  git clone --depth=1 --branch "$SCRAPER_REF" "$REPO_URL" "$REPO_DIR"
else
  log "updating scraper checkout to origin/$SCRAPER_REF"
  git -C "$REPO_DIR" fetch --depth=1 origin "$SCRAPER_REF"
  git -C "$REPO_DIR" reset --hard "origin/$SCRAPER_REF"
fi

# Match CI's clean-slate fetch so the payload is exactly the target Congress.
if [ "$FORCE" = "1" ]; then
  rm -rf "$CONGRESS_DIR/cache"
fi

# ---- 2. python deps in a venv ----------------------------------------------
if [ ! -x "$VENV_DIR/bin/python" ]; then
  python3 -m venv "$VENV_DIR"
fi
"$VENV_DIR/bin/pip" install --quiet --upgrade pip
"$VENV_DIR/bin/pip" install --quiet -r "$REPO_DIR/backend/scraper/requirements.txt"

# ---- 3. resolve target Congress --------------------------------------------
if [ -z "$CONGRESS" ]; then
  CONGRESS="$("$VENV_DIR/bin/python" - <<'PY'
from datetime import datetime
print((datetime.utcnow().year - 1789) // 2 + 1)
PY
)"
fi
log "target Congress: $CONGRESS (force=$FORCE)"

# ---- 4. fetch Senate vote XML (download only) ------------------------------
force_flag=()
[ "$FORCE" = "1" ] && force_flag=(--force)
( cd "$CONGRESS_DIR" && \
  "$VENV_DIR/bin/python" run.py votes \
    --congress="$CONGRESS" --chamber=senate \
    --download_only "${force_flag[@]}" --log=info )

# ---- 5. assemble cache payload (senate.xml + s*.xml only) ------------------
rm -rf "$PAYLOAD_DIR"; mkdir -p "$PAYLOAD_DIR"
rsync -a \
  --include='*/' --include='senate.xml' --include='s*.xml' --exclude='*' \
  "$CONGRESS_DIR/cache/" "$PAYLOAD_DIR/"
log "payload files: $(find "$PAYLOAD_DIR" -type f | wc -l | tr -d ' ')"

# ---- 6. publish to the senate-vote-cache branch ----------------------------
# Token only lives in this ephemeral checkout's remote (CACHE_DIR is recreated
# each run), so it is not persisted across runs.
repo_path="${REPO_URL#https://github.com/}"
auth_url="https://x-access-token:${GH_TOKEN}@github.com/${repo_path}"

rm -rf "$CACHE_DIR"
if ! git clone --depth=1 --branch senate-vote-cache "$auth_url" "$CACHE_DIR" 2>/dev/null; then
  log "senate-vote-cache branch missing; creating it as an orphan"
  git clone --depth=1 "$auth_url" "$CACHE_DIR"
  git -C "$CACHE_DIR" checkout --orphan senate-vote-cache
  git -C "$CACHE_DIR" rm -rf . >/dev/null 2>&1 || true
fi

rsync -a --delete --exclude='.git/' "$PAYLOAD_DIR/" "$CACHE_DIR/"
touch "$CACHE_DIR/.nojekyll"

git -C "$CACHE_DIR" config user.name "senate-vote-cache (rpi)"
git -C "$CACHE_DIR" config user.email "senate-vote-cache@users.noreply.github.com"
git -C "$CACHE_DIR" add -A
if git -C "$CACHE_DIR" diff --cached --quiet; then
  log "no Senate vote cache changes to publish"
else
  git -C "$CACHE_DIR" commit -q -m "chore(cache): refresh Senate vote XML (rpi)"
  git -C "$CACHE_DIR" push -q origin HEAD:senate-vote-cache
  log "published Senate vote cache"
fi
log "done"
