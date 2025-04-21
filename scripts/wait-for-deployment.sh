#!/bin/bash
set -euo pipefail

SERVICE_NAME="$1"      # e.g., detection-svc
ENVIRONMENT="$2"       # e.g., dev
NAME="$SERVICE_NAME"
NAMESPACE="$(echo "$SERVICE_NAME" | sed 's/-svc$//')-$ENVIRONMENT"  # detection-svc → detection-dev

TIMEOUT_SECONDS=300
SLEEP_INTERVAL=5
ELAPSED=0

echo "🔍 Expecting resource:"
echo "   → Name:      $NAME"
echo "   → Namespace: $NAMESPACE"

# Wait for the resource to appear
while true; do
  if kubectl get rollout "$NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "✅ Found Rollout: $NAME in $NAMESPACE"
    TYPE="Rollout"
    break
  elif kubectl get deployment "$NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "✅ Found Deployment: $NAME in $NAMESPACE"
    TYPE="Deployment"
    break
  fi

  if (( ELAPSED >= TIMEOUT_SECONDS )); then
    echo "❌ Timeout: '$NAME' not found in namespace '$NAMESPACE'"
    exit 1
  fi

  echo "⏳ Waiting for '$NAME' to appear in '$NAMESPACE'... (${ELAPSED}s)"
  sleep "$SLEEP_INTERVAL"
  ELAPSED=$((ELAPSED + SLEEP_INTERVAL))
done

# Wait for rollout or deployment to complete
if [ "$TYPE" == "Rollout" ]; then
  echo "📡 Monitoring rollout with Argo Rollouts CLI..."
  if ! kubectl-argo-rollouts get rollout "$NAME" -n "$NAMESPACE" --watch; then
    echo "❌ Rollout failed or stuck. Full status:"
    kubectl-argo-rollouts get rollout "$NAME" -n "$NAMESPACE"
    exit 1
  fi
else
  echo "📡 Monitoring deployment with kubectl..."
  if ! kubectl rollout status deployment "$NAME" -n "$NAMESPACE" --timeout=300s; then
    echo "❌ Deployment rollout failed or timed out"
    exit 1
  fi
fi

echo "🎉 $TYPE completed successfully for $NAME in $NAMESPACE"