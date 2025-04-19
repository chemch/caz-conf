#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: ./start-service.sh <service-name>"
  exit 1
fi

SERVICE="$1"
ENVIRONMENTS=("dev" "qa" "uat" "prod")
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Starting Argo CD applications for service: $SERVICE"

for ENV in "${ENVIRONMENTS[@]}"; do
  YAML="${BASE_DIR}/argo/${SERVICE}/${ENV}.yaml"
  if [ -f "$YAML" ]; then
    echo "Applying $YAML"
    kubectl apply -f "$YAML"
  else
    echo "⚠Skipping $ENV: $YAML not found"
  fi
done

echo "Done: Argo CD applications started for $SERVICE"