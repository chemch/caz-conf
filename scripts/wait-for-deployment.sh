#!/bin/bash
set -euo pipefail

SERVICE_NAME="$1"     # e.g., detection-svc
ENVIRONMENT="$2"      # e.g., dev

BASE_NAME="${SERVICE_NAME%-svc}"             # Remove '-svc'
NAMESPACE="${BASE_NAME}-${ENVIRONMENT}"      # e.g., detection-dev
NAME="$SERVICE_NAME"

TIMEOUT_SECONDS=300
SLEEP_INTERVAL=5
ELAPSED=0

echo "🔍 Expecting resource:"
echo "   → Name:      $NAME"
echo "   → Namespace: $NAMESPACE"

# Wait for Rollout or Deployment to appear
while true; do
  if kubectl get rollout "$NAME" -n "$NAMESPACE" &>/dev/null; then
    TYPE="Rollout"
    break
  elif kubectl get deployment "$NAME" -n "$NAMESPACE" &>/dev/null; then
    TYPE="Deployment"
    break
  fi

  if (( ELAPSED >= TIMEOUT_SECONDS )); then
    echo "❌ Timeout: No Rollout or Deployment '$NAME' found in '$NAMESPACE'"
    exit 1
  fi

  echo "⏳ Waiting for '$NAME' to appear in '$NAMESPACE'... (${ELAPSED}s)"
  sleep "$SLEEP_INTERVAL"
  ELAPSED=$((ELAPSED + SLEEP_INTERVAL))
done

echo "✅ Found $TYPE: $NAME in $NAMESPACE"

# Wait for rollout/deployment to complete
if [ "$TYPE" = "Rollout" ]; then
  echo "⏳ Waiting for Argo Rollout to complete..."
  if ! kubectl-argo-rollouts status rollout "$NAME" -n "$NAMESPACE" --timeout 5m; then
    echo "❌ Rollout failed or timed out"
    echo "🔍 Rollout details:"
    kubectl-argo-rollouts get rollout "$NAME" -n "$NAMESPACE"
    exit 1
  fi
else
  echo "⏳ Waiting for Kubernetes Deployment to complete..."
  if ! kubectl rollout status deployment "$NAME" -n "$NAMESPACE" --timeout=5m; then
    echo "❌ Deployment rollout failed or timed out"
    echo "🔍 Deployment details:"
    kubectl describe deployment "$NAME" -n "$NAMESPACE"
    exit 1
  fi
fi

echo "🎉 $TYPE rollout completed successfully for $NAME in $NAMESPACE"