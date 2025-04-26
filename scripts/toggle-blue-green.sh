#!/bin/bash
set -e

SERVICE=$1
ENV=$2
REPO_ROOT=$(git rev-parse --show-toplevel)
PATCH_PATH="${REPO_ROOT}/overlays/${SERVICE}/${ENV}/patch-service.yaml"

if [ -z "$SERVICE" ] || [ -z "$ENV" ]; then
  echo "Usage: $0 <service-name> <environment>"
  exit 1
fi

if [ ! -f "$PATCH_PATH" ]; then
  echo "patch-service.yaml not found at $PATCH_PATH"
  exit 1
fi

# Detect current version
CURRENT=$(yq '.spec.selector.version' "$PATCH_PATH")

if [ "$CURRENT" == "blue" ]; then
  NEXT="green"
  CURRENT_EMOJI="🟦"
  NEXT_EMOJI="🟩"
else
  NEXT="blue"
  CURRENT_EMOJI="🟩"
  NEXT_EMOJI="🟦"
fi

echo "Switching $SERVICE in $ENV from $CURRENT_EMOJI $CURRENT to $NEXT_EMOJI $NEXT..."

# Update the patch-service.yaml
yq eval ".spec.selector.version = \"$NEXT\"" -i "$PATCH_PATH"

# Git commit the change
cd "$REPO_ROOT"
git add "$PATCH_PATH"
git commit -m "chore(${SERVICE}-${ENV}): switch color to $NEXT"

echo "Service selector updated to $NEXT. Push to apply:"
echo ""
echo "    git push"
echo ""