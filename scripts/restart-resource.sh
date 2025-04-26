#!/bin/bash
set -euo pipefail

SERVICE_NAME="${1:?Usage: $0 <service-name> <environment>}"
ENVIRONMENT="${2:?Usage: $0 <service-name> <environment>}"

NAMESPACE="${SERVICE_NAME%-svc}-${ENVIRONMENT}"

echo "Restarting all Rollouts and Deployments in namespace $NAMESPACE..."

# Restart all Rollouts
ROLLOUTS=$(kubectl get rollouts -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
for rollout in $ROLLOUTS; do
  echo "Restarting Rollout: $rollout"
  kubectl argo rollouts restart rollout "$rollout" -n "$NAMESPACE"
done

# Restart all Deployments
DEPLOYMENTS=$(kubectl get deployments -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
for deployment in $DEPLOYMENTS; do
  echo "Restarting Deployment: $deployment"
  kubectl rollout restart deployment "$deployment" -n "$NAMESPACE"
done

echo "Restart commands issued for all Rollouts and Deployments in $NAMESPACE."