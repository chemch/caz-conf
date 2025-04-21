#!/bin/bash
set -euo pipefail

SERVICE_NAME="${1:-}"
IMAGE_TAG="${2:-latest}"

if [[ -z "$SERVICE_NAME" ]]; then
  echo "❌ SERVICE_NAME not provided"
  exit 1
fi

echo "🔧 SERVICE_NAME: $SERVICE_NAME"
echo "🔧 IMAGE_TAG: $IMAGE_TAG"

ACCOUNT_ID="${AWS_ACCOUNT_ID:-}"
REGION="${AWS_REGION:-}"

if [[ -z "$ACCOUNT_ID" ]]; then
  echo "❌ AWS_ACCOUNT_ID is not set"
  exit 1
fi

if [[ -z "$REGION" ]]; then
  echo "❌ AWS_REGION is not set"
  exit 1
fi

ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
echo "🖼️  Target image: $ECR_BASE/$SERVICE_NAME:$IMAGE_TAG"

TARGET_OVERLAY_DIR="overlays/$SERVICE_NAME/dev"

if [[ ! -d "$TARGET_OVERLAY_DIR" ]]; then
  echo "❌ Directory $TARGET_OVERLAY_DIR does not exist"
  exit 1
fi

cd "$TARGET_OVERLAY_DIR"
echo "📁 Changed directory to: $(pwd)"

echo "🚀 Running kustomize edit set image..."
kustomize edit set image "$SERVICE_NAME=$ECR_BASE/$SERVICE_NAME:$IMAGE_TAG"

echo "✅ Image set. Verifying..."
kustomize build . | grep image || {
  echo "❌ Image substitution failed!"
  exit 1
}