#!/bin/bash
set -euo pipefail

SERVICE_NAME="$1"
NAMESPACE="$2"

TIMEOUT_SECONDS=300
SLEEP_INTERVAL=5
ELAPSED=0

echo "Checking rollout status for $SERVICE_NAME in namespace $NAMESPACE..."

while true; do
  if kubectl get rollout "$SERVICE_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "Found Rollout: $SERVICE_NAME in $NAMESPACE"
    break
  elif kubectl get deployment "$SERVICE_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "Found Deployment: $SERVICE_NAME in $NAMESPACE"
    break
  fi

  if (( ELAPSED >= TIMEOUT_SECONDS )); then
    echo "Timeout: Resource '$SERVICE_NAME' not found in namespace '$NAMESPACE'"
    exit 1
  fi

  echo "Waiting for '$SERVICE_NAME' to appear in '$NAMESPACE'... (${ELAPSED}s)"
  sleep "$SLEEP_INTERVAL"
  ELAPSED=$((ELAPSED + SLEEP_INTERVAL))
done

# Wait for rollout to complete
if kubectl get rollout "$SERVICE_NAME" -n "$NAMESPACE" &>/dev/null; then
  echo "Monitoring rollout with Argo Rollouts CLI..."
  if ! kubectl-argo-rollouts get rollout "$SERVICE_NAME" -n "$NAMESPACE" --watch; then
    echo "Rollout failed or stuck. Status:"
    kubectl-argo-rollouts get rollout "$SERVICE_NAME" -n "$NAMESPACE"
    exit 1
  fi
else
  echo "Monitoring deployment with kubectl..."
  if ! kubectl rollout status deployment "$SERVICE_NAME" -n "$NAMESPACE" --timeout=300s; then
    echo "Deployment rollout failed or timed out"
    exit 1
  fi
fi

echo " Rollout or Deployment completed successfully for $SERVICE_NAME in $NAMESPACE"