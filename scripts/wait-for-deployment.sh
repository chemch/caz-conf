#!/bin/bash
set -euo pipefail

SERVICE_NAME="${1:?Usage: $0 <service-name> <environment>}"
ENVIRONMENT="${2:?Usage: $0 <service-name> <environment>}"

# Configurable vars (with defaults)
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-300}"
SLEEP_INTERVAL="${SLEEP_INTERVAL:-10}"
RETRY_ATTEMPTS="${RETRY_ATTEMPTS:-3}"
RETRY_DELAY="${RETRY_DELAY:-2}"

NAME="$SERVICE_NAME"
NAMESPACE="${NAMESPACE_OVERRIDE:-$(echo "$SERVICE_NAME" | sed 's/-svc$//')-$ENVIRONMENT}"

echo "🔍 Expecting resource:"
echo "   → Name:      $NAME"
echo "   → Namespace: $NAMESPACE"

# Retry wrapper for kubectl calls
retry() {
  local attempt=1
  until "$@"; do
    if (( attempt >= RETRY_ATTEMPTS )); then
      return 1
    fi
    echo "⚠️  Command failed. Retrying in $RETRY_DELAY seconds... (Attempt $attempt/$RETRY_ATTEMPTS)"
    sleep "$RETRY_DELAY"
    attempt=$((attempt + 1))
  done
}

# Wait for the resource to exist
ELAPSED=0
while true; do
  if retry kubectl get rollout "$NAME" -n "$NAMESPACE" &>/dev/null; then
    TYPE="Rollout"
    echo "✅ Found Rollout: $NAME in $NAMESPACE"
    break
  elif retry kubectl get deployment "$NAME" -n "$NAMESPACE" &>/dev/null; then
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

# Reset timer for rollout/deployment readiness
ELAPSED=0
echo "📡 Monitoring $TYPE readiness for up to ${TIMEOUT_SECONDS}s..."

while (( ELAPSED < TIMEOUT_SECONDS )); do
  if [[ "$TYPE" == "Rollout" ]]; then
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
echo "🔍 Final status:"
if [[ "$TYPE" == "Rollout" ]]; then
  kubectl-argo-rollouts get rollout "$NAME" -n "$NAMESPACE" || true
else
  kubectl get deployment "$NAME" -n "$NAMESPACE" || true
fi

exit 1