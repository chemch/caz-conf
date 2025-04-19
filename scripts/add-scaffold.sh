#!/bin/bash
set -e

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <new-service-name> <template-service-name>"
  exit 1
fi

NEW_SERVICE=$1
TEMPLATE_SERVICE=$2
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

cp -r "$SRC_BASE" "$DST_BASE"
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

  # Rename and replace file contents
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
  cp "${SRC_ARGO_DIR}/${ENV}.yaml" "${DST_ARGO_DIR}/${ENV}.yaml"
  sed -i '' "s/${TEMPLATE_SERVICE}/${NEW_SERVICE}/g" "${DST_ARGO_DIR}/${ENV}.yaml"
done

echo "Argo CD apps copied to argo/${NEW_SERVICE}/"

echo "Scaffolding complete for new service: ${NEW_SERVICE}"