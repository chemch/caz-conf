#!/bin/bash
set -euo pipefail

NAME="$1"
NAMESPACE="$2"
TIMEOUT="300s"  # 5 minutes

echo "🔍 Checking resource type for $NAME in namespace $NAMESPACE..."

if kubectl get rollout "$NAME" -n "$NAMESPACE" &>/dev/null; then
  echo "Found Argo Rollout: $NAME"
  echo "Waiting up to $TIMEOUT for rollout to complete..."
  kubectl-argo-rollouts get rollout "$NAME" -n "$NAMESPACE" --watch || {
    echo "Argo Rollout failed or timed out!"
    exit 1
  }

elif kubectl get deployment "$NAME" -n "$NAMESPACE" &>/dev/null; then
  echo "Found Kubernetes Deployment: $NAME"
  echo "Waiting up to $TIMEOUT for deployment rollout..."
  kubectl rollout status deployment "$NAME" -n "$NAMESPACE" --timeout="$TIMEOUT" || {
    echo "Deployment rollout failed or timed out!"
    exit 1
  }

else
  echo "Neither a Rollout nor Deployment named '$NAME' exists in namespace '$NAMESPACE'"
  exit 1
fi

echo "Rollout completed successfully!"