#!/bin/bash
set -euo pipefail

SERVICE_NAME="${1:?Usage: $0 <service-name> <environment>}"
ENVIRONMENT="${2:?Usage: $0 <service-name> <environment>}"

NAMESPACE="${SERVICE_NAME%-svc}-${ENVIRONMENT}"

echo "Force cleaning up namespace $NAMESPACE before redeployment..."

kubectl delete all --all -n "$NAMESPACE" --grace-period=0 --force || true
kubectl delete configmap,secret,pvc,job,cronjob --all -n "$NAMESPACE" --grace-period=0 --force || true

echo "Namespace $NAMESPACE force-cleaned."