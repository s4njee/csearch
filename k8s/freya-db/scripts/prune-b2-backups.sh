#!/bin/sh
set -eu

: "${RESTIC_REPOSITORY:?RESTIC_REPOSITORY is required}"
: "${RESTIC_PASSWORD:?RESTIC_PASSWORD is required}"
: "${B2_ACCOUNT_ID:?B2_ACCOUNT_ID is required}"
: "${B2_ACCOUNT_KEY:?B2_ACCOUNT_KEY is required}"

RESTIC_KEEP_LAST="${RESTIC_KEEP_LAST:-8}"

restic forget \
  --tag postgres \
  --tag freya \
  --tag physical \
  --keep-last "$RESTIC_KEEP_LAST" \
  --prune
