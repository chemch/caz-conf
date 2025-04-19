#!/bin/bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARGO_DIR="${REPO_ROOT}/argo"
DELETE_SCRIPT="${REPO_ROOT}/scripts/delete-service.sh"

if [ ! -f "$DELETE_SCRIPT" ]; then
  echo "Missing: $DELETE_SCRIPT"
  exit 1
fi

echo "Deleting all Argo CD applications for each service in $ARGO_DIR..."

for SERVICE in "$ARGO_DIR"/*; do
  if [ -d "$SERVICE" ]; then
    SERVICE_NAME=$(basename "$SERVICE")
    echo "Deleting: $SERVICE_NAME"
    "$DELETE_SCRIPT" "$SERVICE_NAME"
  fi
done

echo "All Argo CD apps deleted."