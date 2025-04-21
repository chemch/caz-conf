#!/bin/bash
set -euo pipefail

SERVICE_NAME="$1"      # e.g., detection-svc
ENVIRONMENT="$2"       # e.g., dev

# Remove '-svc' from service name to derive namespace
BASE_NAME="${SERVICE_NAME%-svc}"               # detection-svc → detection
NAMESPACE="${BASE_NAME}-${ENVIRONMENT}"        # → detection-dev

TIMEOUT_SECONDS=300
SLEEP_INTERVAL=5
ELAPSED=0

echo "🔍 Expecting resource:"
echo "   → Name:      $SERVICE_NAME"
echo "   → Namespace: $NAMESPACE"

# Wait until the resource appears
while true; do
  if kubectl get rollout "$SERVICE_NAME" -n "$NAMESPACE" &>/dev/null; then
    TYPE="Rollout"
    break
  elif kubectl get deployment "$SERVICE_NAME" -n "$NAMESPACE" &>/dev/null; then
    TYPE="Deployment"
    break
  fi

  if (( ELAPSED >= TIMEOUT_SECONDS )); then
    echo "❌ Timeout: Rollout or Deployment '$SERVICE_NAME' not found in namespace '$NAMESPACE'"
    exit 1
  fi

  echo "⏳ Waiting for '$SERVICE_NAME' to appear in '$NAMESPACE'... (${ELAPSED}s)"
  sleep "$SLEEP_INTERVAL"
  ELAPSED=$((ELAPSED + SLEEP_INTERVAL))
done

echo "✅ Found $TYPE: $SERVICE_NAME in $NAMESPACE"

# Wait for rollout to complete
if [ "$TYPE" = "Rollout" ]; then
  kubectl-argo-rollouts get rollout "$SERVICE_NAME" -n "$NAMESPACE" --watch || {
    echo "❌ Rollout failed or stuck"
    exit 1
  }
else
  kubectl rollout status deployment "$SERVICE_NAME" -n "$NAMESPACE" --timeout=300s || {
    echo "❌ Deployment rollout failed or timed out"
    exit 1
  }
fi

echo "🎉 $TYPE rollout completed for $SERVICE_NAME in $NAMESPACE"