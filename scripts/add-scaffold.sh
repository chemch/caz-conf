#!/bin/bash
set -e

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <new-service-name> <template-service-name>"
  exit 1
fi

NEW_SERVICE=$1               # e.g., detection-svc
TEMPLATE_SERVICE=$2          # e.g., alert-svc
STRIPPED_SERVICE=$(echo "$NEW_SERVICE" | sed 's/-svc$//')  # e.g., detection
ENVIRONMENTS=("dev" "qa" "uat" "prod")

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(dirname "$SCRIPT_DIR")

BASE_DIR="${REPO_ROOT}/base"
OVERLAYS_DIR="${REPO_ROOT}/overlays"
ARGO_DIR="${REPO_ROOT}/argo"

# === Base copy ===
SRC_BASE="${BASE_DIR}/${TEMPLATE_SERVICE}"
DST_BASE="${BASE_DIR}/${NEW_SERVICE}"

if [ ! -d "$SRC_BASE" ]; then
  echo "Template base not found: $SRC_BASE"
  exit 1
fi

mkdir -p "$DST_BASE"
cp "$SRC_BASE"/* "$DST_BASE"
find "$DST_BASE" -type f -exec sed -i '' "s/${TEMPLATE_SERVICE}/${NEW_SERVICE}/g" {} +
echo "Base copied from $TEMPLATE_SERVICE to $NEW_SERVICE"

# === Overlays copy ===
for ENV in "${ENVIRONMENTS[@]}"; do
  SRC_ENV_DIR="${OVERLAYS_DIR}/${TEMPLATE_SERVICE}/${ENV}"
  DST_ENV_DIR="${OVERLAYS_DIR}/${NEW_SERVICE}/${ENV}"

  if [ ! -d "$SRC_ENV_DIR" ]; then
    echo "Template overlay not found: $SRC_ENV_DIR"
    exit 1
  fi

  mkdir -p "$DST_ENV_DIR"
  cp "$SRC_ENV_DIR"/* "$DST_ENV_DIR"

  for FILE in "$DST_ENV_DIR"/*; do
    sed -i '' "s/${TEMPLATE_SERVICE}/${NEW_SERVICE}/g" "$FILE"
    NEW_NAME=$(basename "$FILE" | sed "s/${TEMPLATE_SERVICE}/${NEW_SERVICE}/g")
    mv "$FILE" "$DST_ENV_DIR/$NEW_NAME"
  done

  echo "Overlay copied: $ENV"
done

# === Argo CD app manifests ===
SRC_ARGO_DIR="${ARGO_DIR}/${TEMPLATE_SERVICE}"
DST_ARGO_DIR="${ARGO_DIR}/${NEW_SERVICE}"
mkdir -p "$DST_ARGO_DIR"

for ENV in "${ENVIRONMENTS[@]}"; do
  SRC_FILE="${SRC_ARGO_DIR}/${ENV}.yaml"
  DST_FILE="${DST_ARGO_DIR}/${ENV}.yaml"
  if [ ! -f "$SRC_FILE" ]; then
    echo "⚠Skipping Argo app $ENV: $SRC_FILE not found"
    continue
  fi

  cp "$SRC_FILE" "$DST_FILE"
  # Replace all occurrences of the template service with the new one
  sed -i '' "s/${TEMPLATE_SERVICE}/${NEW_SERVICE}/g" "$DST_FILE"

  # Override only destination.namespace (not metadata.name)
  sed -i '' "s/namespace: .*-${ENV}/namespace: ${STRIPPED_SERVICE}-${ENV}/" "$DST_FILE"
  echo "Argo CD app written: $DST_FILE"
done

echo "Scaffolding complete for new service: ${NEW_SERVICE}"