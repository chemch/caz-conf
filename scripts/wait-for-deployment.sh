#!/bin/bash
set -euo pipefail

NAME="$1"
NAMESPACE="$2"

TIMEOUT_SECONDS=300
SLEEP_INTERVAL=5
ELAPSED=0

echo "🔍 Checking rollout status for $NAME in namespace $NAMESPACE..."

# Wait for rollout to reach Healthy
while true; do
  STATUS=$(kubectl argo rollouts get rollout "$NAME" -n "$NAMESPACE" -o=jsonpath='{.status.phase}' || echo "Unknown")
  READY=$(kubectl get pods -n "$NAMESPACE" -l app="$NAME" -o jsonpath='{.items[*].status.containerStatuses[*].ready}' | grep -o true | wc -l)
  DESIRED=$(kubectl argo rollouts get rollout "$NAME" -n "$NAMESPACE" -o=jsonpath='{.spec.replicas}')

  echo "⏳ [$ELAPSED s] Status: $STATUS — Ready Pods: $READY / $DESIRED"

  if [[ "$STATUS" == "Healthy" && "$READY" -eq "$DESIRED" ]]; then
    echo "✅ Rollout is healthy and all pods are ready"
    break
  fi

  if (( ELAPSED >= TIMEOUT_SECONDS )); then
    echo "❌ Timeout: Rollout failed to become healthy"
    kubectl argo rollouts get rollout "$NAME" -n "$NAMESPACE"
    exit 1
  fi

  sleep "$SLEEP_INTERVAL"
  ELAPSED=$((ELAPSED + SLEEP_INTERVAL))
done