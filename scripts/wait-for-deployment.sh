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
NAMESPACE="${NAMESPACE_OVERRIDE:-$(echo "$SERVICE_NAME" | sed 's/-svc$//')-$ENVIRONMENT"

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
while (( ELAPSED < TIMEOUT_SECONDS )); do
  if retry kubectl get deployment "$NAME" -n "$NAMESPACE" &>/dev/null; then
    TYPE="Deployment"
    echo "✅ Found Deployment: $NAME in $NAMESPACE"
    break
  fi

  echo "⏳ Waiting for deployment '$NAME' to appear in '$NAMESPACE'... (${ELAPSED}s)"
  sleep "$SLEEP_INTERVAL"
  ELAPSED=$((ELAPSED + SLEEP_INTERVAL))
done

if [[ "${TYPE:-}" != "Deployment" ]]; then
  echo "❌ Timeout: Deployment '$NAME' not found in namespace '$NAMESPACE'"
  exit 1
fi

# Reset timer for readiness
ELAPSED=0
echo "📡 Monitoring Deployment readiness for up to ${TIMEOUT_SECONDS}s..."

while (( ELAPSED < TIMEOUT_SECONDS )); do
  READY=$(kubectl get deployment "$NAME" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  DESIRED=$(kubectl get deployment "$NAME" -n "$NAMESPACE" -o jsonpath='{.status.replicas}' 2>/dev/null || echo "0")

  echo "🔄 Deployment status: readyReplicas=$READY / replicas=$DESIRED"
  if [[ "$READY" == "$DESIRED" && "$READY" != "0" ]]; then
    echo "✅ Deployment completed successfully!"
    exit 0
  fi

  sleep "$SLEEP_INTERVAL"
  ELAPSED=$((ELAPSED + SLEEP_INTERVAL))
done

echo "❌ Timeout waiting for deployment to complete."
kubectl get deployment "$NAME" -n "$NAMESPACE" || true
exit 1