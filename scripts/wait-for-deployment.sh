#!/bin/bash
set -euo pipefail

NAME="$1"
NAMESPACE="$2"
TIMEOUT_SECONDS=300
SLEEP_INTERVAL=5
ELAPSED=0

echo "🔍 Checking resource type for $NAME in namespace $NAMESPACE..."

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
    echo "❌ Timeout waiting for Rollout or Deployment named '$NAME' in namespace '$NAMESPACE'"
    exit 1
  fi

  echo "⏳ Waiting for Rollout or Deployment '$NAME' to appear in namespace '$NAMESPACE'... (${ELAPSED}s)"
  sleep "$SLEEP_INTERVAL"
  ELAPSED=$((ELAPSED + SLEEP_INTERVAL))
done

echo "✅ Found $TYPE: $NAME"

# Now wait for the rollout to complete
if [ "$TYPE" = "Rollout" ]; then
  kubectl-argo-rollouts get rollout "$NAME" -n "$NAMESPACE" --watch || {
    echo "❌ Argo Rollout failed or was interrupted"
    exit 1
  }
else
  kubectl rollout status deployment "$NAME" -n "$NAMESPACE" --timeout=300s || {
    echo "❌ Kubernetes Deployment rollout failed or timed out"
    exit 1
  }
fi

echo "🎉 $TYPE rollout for $NAME in $NAMESPACE completed successfully."