#!/bin/bash
set -euo pipefail

SERVICE_NAME="$1"
IMAGE_TAG="${2:-latest}"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)
ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "Setting image for service: $SERVICE_NAME"
echo "Image: $ECR_BASE/$SERVICE_NAME:$IMAGE_TAG"

cd overlays/$SERVICE_NAME/dev
kustomize edit set image $SERVICE_NAME=$ECR_BASE/$SERVICE_NAME:$IMAGE_TAG

echo "Verifying updated image in rendered manifest..."
kustomize build . | grep image: