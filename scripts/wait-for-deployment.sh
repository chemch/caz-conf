#!/bin/bash
set -euo pipefail

SERVICE_NAME="${1:?Usage: $0 <service-name> <environment>}"
ENVIRONMENT="${2:?Usage: $0 <service-name> <environment>}"

# Configurable vars
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-120}"
SLEEP_INTERVAL="${SLEEP_INTERVAL:-15}"
RETRY_ATTEMPTS="${RETRY_ATTEMPTS:-3}"
RETRY_DELAY="${RETRY_DELAY:-3}"

NAME="$SERVICE_NAME"
NAMESPACE="${NAMESPACE_OVERRIDE:-$(echo "$SERVICE_NAME" | sed 's/-svc$//')-$ENVIRONMENT}"

echo "Expecting resource:"
echo "   → Name:      $NAME"
echo "   → Namespace: $NAMESPACE"

# Retry wrapper
retry() {
  local attempt=1
  until "$@"; do
    if (( attempt >= RETRY_ATTEMPTS )); then
      return 1
    fi
    echo "Command failed. Retrying in $RETRY_DELAY seconds... (Attempt $attempt/$RETRY_ATTEMPTS)"
    sleep "$RETRY_DELAY"
    attempt=$((attempt + 1))
  done
}

# Determine if it's a Rollout or Deployment
ELAPSED=0
while (( ELAPSED < TIMEOUT_SECONDS )); do
  if retry kubectl get rollout "$NAME" -n "$NAMESPACE" &>/dev/null; then
    TYPE="Rollout"
    echo "Found Rollout: $NAME in $NAMESPACE"
    break
  elif retry kubectl get deployment "$NAME" -n "$NAMESPACE" &>/dev/null; then
    TYPE="Deployment"
    echo "Found Deployment: $NAME in $NAMESPACE"
    break
  else
    # Try detecting active color from patch-service.yaml if standard name not found
    PATCH_PATH="overlays/${SERVICE_NAME}/${ENVIRONMENT}/patch-service.yaml"
    if [[ -f "$PATCH_PATH" ]]; then
      COLOR=$(yq '.spec.selector.version' "$PATCH_PATH" 2>/dev/null || echo "")
      if [[ -n "$COLOR" ]]; then
        ALT_NAME="${SERVICE_NAME}-${COLOR}"
        if retry kubectl get deployment "$ALT_NAME" -n "$NAMESPACE" &>/dev/null; then
          NAME="$ALT_NAME"
          TYPE="Deployment"
          echo "Fallback: Found Blue-Green Deployment: $NAME in $NAMESPACE"
          break
        fi
        if retry kubectl get rollout "$ALT_NAME" -n "$NAMESPACE" &>/dev/null; then
          NAME="$ALT_NAME"
          TYPE="Rollout"
          echo "Fallback: Found Blue-Green Rollout: $NAME in $NAMESPACE"
          break
        fi
      fi
    fi
  fi

  echo "Waiting for resource '$NAME' in '$NAMESPACE'... (${ELAPSED}s)"
  sleep "$SLEEP_INTERVAL"
  ELAPSED=$((ELAPSED + SLEEP_INTERVAL))
done

  echo "Waiting for resource '$NAME' in '$NAMESPACE'... (${ELAPSED}s)"
  sleep "$SLEEP_INTERVAL"
  ELAPSED=$((ELAPSED + SLEEP_INTERVAL))
done

if [[ -z "${TYPE:-}" ]]; then
  echo "Timeout: Resource '$NAME' not found in '$NAMESPACE'"
  exit 1
fi

# Reset and wait for readiness
ELAPSED=0
echo "Monitoring $TYPE readiness for up to ${TIMEOUT_SECONDS}s..."

while (( ELAPSED < TIMEOUT_SECONDS )); do
  if [[ "$TYPE" == "Rollout" ]]; then
    STATUS=$(kubectl get rollout "$NAME" -n "$NAMESPACE" -o=jsonpath='{.status.phase}' 2>/dev/null || echo "Missing")
    echo "Rollout status: $STATUS"
    if [[ "$STATUS" == "Healthy" ]]; then
      echo "Rollout completed successfully!"
      exit 0
    fi
  else
    READY=$(retry kubectl get deployment "$NAME" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    DESIRED=$(retry kubectl get deployment "$NAME" -n "$NAMESPACE" -o jsonpath='{.status.replicas}' 2>/dev/null || echo "0")
    echo "Deployment status: readyReplicas=$READY / replicas=$DESIRED"
    if [[ "$READY" == "$DESIRED" && "$READY" != "0" ]]; then
      echo "Deployment completed successfully!"
      exit 0
    fi
  fi

  sleep "$SLEEP_INTERVAL"
  ELAPSED=$((ELAPSED + SLEEP_INTERVAL))
done

echo "Timeout waiting for $TYPE to complete."
echo "Final status:"
kubectl get "$TYPE" "$NAME" -n "$NAMESPACE" || true
exit 1