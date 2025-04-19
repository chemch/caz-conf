#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: ./delete-service.sh <service-name>"
  exit 1
fi

SERVICE="$1"
ENVIRONMENTS=("dev" "qa" "uat" "prod")

echo "Deleting Argo CD applications for service: $SERVICE"

for ENV in "${ENVIRONMENTS[@]}"; do
  APP_NAME="${SERVICE}-${ENV}"
  echo "Deleting: $APP_NAME"
  kubectl delete application "$APP_NAME" -n argocd --ignore-not-found
done

echo "Done: Argo CD applications deleted for $SERVICE"