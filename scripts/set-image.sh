#!/bin/bash
set -euo pipefail

SERVICE_NAME="$1"
IMAGE_TAG="${2:-latest}"

ACCOUNT_ID="${AWS_ACCOUNT_ID:?AWS_ACCOUNT_ID not set}"
REGION="${AWS_REGION:?AWS_REGION not set}"
ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "Setting image for $SERVICE_NAME"
echo "Image: $ECR_BASE/$SERVICE_NAME:$IMAGE_TAG"

cd overlays/$SERVICE_NAME/dev
kustomize edit set image $SERVICE_NAME=$ECR_BASE/$SERVICE_NAME:$IMAGE_TAG

echo "Image updated in Kustomize:"
kustomize build . | grep image
