#!/bin/bash
set -euo pipefail

SERVICE_NAME="${1:?Usage: $0 <service-name> <environment>}"
ENVIRONMENT="${2:?Usage: $0 <service-name> <environment>}"

NAMESPACE="${SERVICE_NAME%-svc}-${ENVIRONMENT}"

echo "Checking if $SERVICE_NAME is a Rollout or Deployment in namespace $NAMESPACE..."

# Try Rollout first
if kubectl get rollout "$SERVICE_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
  echo "Found Rollout $SERVICE_NAME. Restarting via Argo Rollouts."
  kubectl argo rollouts restart rollout "$SERVICE_NAME" -n "$NAMESPACE"

# Try Deployment next
elif kubectl get deployment "$SERVICE_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
  echo "Found Deployment $SERVICE_NAME. Restarting via kubectl rollout restart."
  kubectl rollout restart deployment "$SERVICE_NAME" -n "$NAMESPACE"

# Neither found
else
  echo "Neither Rollout nor Deployment named $SERVICE_NAME found in namespace $NAMESPACE."
  exit 1
fi