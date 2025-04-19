#!/bin/bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARGO_DIR="${REPO_ROOT}/argo"
START_SCRIPT="${REPO_ROOT}/scripts/start-service.sh"

if [ ! -f "$START_SCRIPT" ]; then
  echo "Missing: $START_SCRIPT"
  exit 1
fi

echo "Starting all Argo CD applications from $ARGO_DIR..."

for SERVICE in "$ARGO_DIR"/*; do
  if [ -d "$SERVICE" ]; then
    SERVICE_NAME=$(basename "$SERVICE")
    echo "Starting: $SERVICE_NAME"
    "$START_SCRIPT" "$SERVICE_NAME"
  fi
done

echo "All Argo CD apps started."