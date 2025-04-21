#!/bin/bash
set -euo pipefail

SERVICE_NAME="$1"      # e.g., detection-svc
ENVIRONMENT="$2"       # e.g., dev
NAME="$SERVICE_NAME"
NAMESPACE="$(echo "$SERVICE_NAME" | cut -d'-' -f1)-$ENVIRONMENT"  # e.g., detection-dev

TIMEOUT_SECONDS=300
SLEEP_INTERVAL=5
ELAPSED=0

echo "🔍 Waiting for $NAME in namespace $NAMESPACE..."

# Wait until the resource appears
while true; do
  if kubectl get rollout "$NAME" -n "$NAMESPACE" &>/dev/null; then
    TYPE="Rollout"
    break
  elif kubectl get deployment "$NAME" -n "$NAMESPACE" &>/dev/null; then
    TYPE="Deployment"
    break
  fi

  if (( ELAPSED >= TIMEOUT_SECONDS )); then
    echo "❌ Timeout: Rollout or Deployment '$NAME' not found in namespace '$NAMESPACE'"
    exit 1
  fi

  echo "⏳ Waiting for '$NAME' to appear in '$NAMESPACE'... (${ELAPSED}s)"
  sleep "$SLEEP_INTERVAL"
  ELAPSED=$((ELAPSED + SLEEP_INTERVAL))
done

echo "✅ Found $TYPE: $NAME in $NAMESPACE"

# Wait for rollout to complete
if [ "$TYPE" = "Rollout" ]; then
  kubectl-argo-rollouts get rollout "$NAME" -n "$NAMESPACE" --watch || {
    echo "❌ Rollout failed or stuck"
    exit 1
  }
else
  kubectl rollout status deployment "$NAME" -n "$NAMESPACE" --timeout=300s || {
    echo "❌ Deployment rollout failed or timed out"
    exit 1
  }
fi

echo "🎉 $TYPE rollout completed for $NAME in $NAMESPACE"