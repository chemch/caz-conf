#!/bin/bash
set -euo pipefail

SERVICE_NAME="${1:?Usage: $0 <service-name> <environment>}"
ENVIRONMENT="${2:?Usage: $0 <service-name> <environment>}"

NAMESPACE="${SERVICE_NAME%-svc}-${ENVIRONMENT}"

echo "Cleaning up namespace $NAMESPACE before redeployment..."

kubectl delete all --all -n "$NAMESPACE" || true

echo "Namespace $NAMESPACE cleaned."