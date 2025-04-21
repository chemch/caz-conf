#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: ./start-service.sh <service-name> [environment]"
  exit 1
fi

SERVICE="$1"
SPECIFIC_ENV="${2:-}"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -n "$SPECIFIC_ENV" ]; then
  ENVIRONMENTS=("$SPECIFIC_ENV")
else
  ENVIRONMENTS=("dev" "qa" "uat" "prod")
fi

echo "Starting Argo CD applications for service: $SERVICE"

for ENV in "${ENVIRONMENTS[@]}"; do
  YAML="${BASE_DIR}/argo/${SERVICE}/${ENV}.yaml"
  NAMESPACE="${SERVICE//-svc/}-$ENV"

  echo "Expected Rollout/Deployment Info:"
  echo "   → Name:      $SERVICE"
  echo "   → Namespace: $NAMESPACE"

  echo "Checking namespace: $NAMESPACE"
  kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || {
    echo "Creating namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE"
  }

  if [ -f "$YAML" ]; then
    echo "Applying $YAML"
    kubectl apply -f "$YAML"
  else
    echo "Skipping $ENV: $YAML not found"
  fi
done

echo "Done: Argo CD applications started for $SERVICE"