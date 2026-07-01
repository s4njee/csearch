#!/bin/sh
set -eu

: "${RESTIC_REPOSITORY:?RESTIC_REPOSITORY is required}"
: "${RESTIC_PASSWORD:?RESTIC_PASSWORD is required}"
: "${B2_ACCOUNT_ID:?B2_ACCOUNT_ID is required}"
: "${B2_ACCOUNT_KEY:?B2_ACCOUNT_KEY is required}"

RESTIC_KEEP_LAST="${RESTIC_KEEP_LAST:-14}"
RESTIC_KEEP_WEEKLY="${RESTIC_KEEP_WEEKLY:-8}"
RESTIC_CLUSTER_TAG="${RESTIC_CLUSTER_TAG:-netcup}"
RESTIC_BACKUP_TAG="${RESTIC_BACKUP_TAG:-logical}"

restic forget \
  --tag postgres \
  --tag "$RESTIC_CLUSTER_TAG" \
  --tag "$RESTIC_BACKUP_TAG" \
  --group-by host,tags \
  --keep-daily "$RESTIC_KEEP_LAST" \
  --keep-weekly "$RESTIC_KEEP_WEEKLY" \
  --prune
