#!/bin/bash
set -euo pipefail

SERVICE_NAME="$1"      # e.g., detection-svc
ENVIRONMENT="$2"       # e.g., dev
NAME="$SERVICE_NAME"
NAMESPACE="$(echo "$SERVICE_NAME" | sed 's/-svc$//')-$ENVIRONMENT"

TIMEOUT_SECONDS=300
SLEEP_INTERVAL=10
ELAPSED=0

echo "🔍 Expecting resource:"
echo "   → Name:      $NAME"
echo "   → Namespace: $NAMESPACE"

# Wait for the resource to exist
while true; do
  if kubectl get rollout "$NAME" -n "$NAMESPACE" &>/dev/null; then
    TYPE="Rollout"
    echo "✅ Found Rollout: $NAME in $NAMESPACE"
    break
  elif kubectl get deployment "$NAME" -n "$NAMESPACE" &>/dev/null; then
    TYPE="Deployment"
    echo "✅ Found Deployment: $NAME in $NAMESPACE"
    break
  fi

  if (( ELAPSED >= TIMEOUT_SECONDS )); then
    echo "❌ Timeout: resource '$NAME' not found in namespace '$NAMESPACE'"
    exit 1
  fi

  echo "⏳ Waiting for '$NAME' to appear in '$NAMESPACE'... (${ELAPSED}s)"
  sleep "$SLEEP_INTERVAL"
  ELAPSED=$((ELAPSED + SLEEP_INTERVAL))
done

# Reset timer for rollout completion
ELAPSED=0
echo "📡 Checking $TYPE rollout status every ${SLEEP_INTERVAL}s for up to ${TIMEOUT_SECONDS}s..."

while (( ELAPSED < TIMEOUT_SECONDS )); do
  if [ "$TYPE" == "Rollout" ]; then
    STATUS=$(kubectl-argo-rollouts get rollout "$NAME" -n "$NAMESPACE" -o=jsonpath='{.status.phase}' 2>/dev/null || echo "Missing")
    echo "🔄 Rollout status: $STATUS"
    if [[ "$STATUS" == "Healthy" ]]; then
      echo "✅ Rollout completed successfully!"
      exit 0
    fi
  else
    READY=$(kubectl get deployment "$NAME" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' || echo "0")
    DESIRED=$(kubectl get deployment "$NAME" -n "$NAMESPACE" -o jsonpath='{.status.replicas}' || echo "0")
    echo "🔄 Deployment status: readyReplicas=$READY / replicas=$DESIRED"
    if [[ "$READY" == "$DESIRED" && "$READY" != "0" ]]; then
      echo "✅ Deployment completed successfully!"
      exit 0
    fi
  fi

  sleep "$SLEEP_INTERVAL"
  ELAPSED=$((ELAPSED + SLEEP_INTERVAL))
done

echo "❌ Timeout waiting for $TYPE to complete."
echo "🔍 Dumping final status:"
if [ "$TYPE" == "Rollout" ]; then
  kubectl-argo-rollouts get rollout "$NAME" -n "$NAMESPACE"
else
  kubectl get deployment "$NAME" -n "$NAMESPACE"
fi

exit 1