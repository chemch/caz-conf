#!/bin/bash

# Usage: ./switch-color.sh <service-name> <environment> <new-color>
# Example: ./switch-color.sh alert-svc dev green

set -e

SERVICE="$1"
ENV="$2"
NEW_COLOR="$3"

if [[ -z "$SERVICE" || -z "$ENV" || -z "$NEW_COLOR" ]]; then
  echo "Usage: $0 <service-name> <environment> <new-color>"
  exit 1
fi

PATCH_FILE="overlays/${SERVICE}/${ENV}/patch-service.yaml"

if [[ ! -f "$PATCH_FILE" ]]; then
  echo "Error: Patch file not found at $PATCH_FILE"
  exit 1
fi

# Update color label in patch-service.yaml
sed -i '' "s/color: .*/color: ${NEW_COLOR}/" "$PATCH_FILE"

# Reapply with kubectl (optional)
echo "Updated $PATCH_FILE to use color: $NEW_COLOR"
echo "Reapplying configuration..."
kubectl apply -k overlays/${SERVICE}/${ENV}
