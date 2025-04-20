#!/bin/bash
set -e

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <namespace> <color>"
  echo "Example: $0 alert-dev green"
  exit 1
fi

NAMESPACE=$1
COLOR=$2

if [[ "$COLOR" != "blue" && "$COLOR" != "green" ]]; then
  echo "Error: color must be 'blue' or 'green'"
  exit 1
fi

echo "Switching alert-svc to version: $COLOR in namespace: $NAMESPACE"

kubectl patch service alert-svc -n "$NAMESPACE" \
  -p "{\"spec\": {\"selector\": {\"app\": \"alert-svc\", \"version\": \"$COLOR\"}}}"

echo "Service updated to route traffic to version: $COLOR"