#!/bin/bash
set -e

# === Input check ===
if [ -z "$1" ]; then
  echo "Usage: $0 <service-name>"
  exit 1
fi

SERVICE=$1
ENVIRONMENTS=("dev")
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(dirname "$SCRIPT_DIR")

BASE_DIR="${REPO_ROOT}/base/${SERVICE}"
OVERLAYS_DIR="${REPO_ROOT}/overlays/${SERVICE}"
ARGO_DIR="${REPO_ROOT}/argo/${SERVICE}"

echo "🚀 Scaffolding base for $SERVICE..."

mkdir -p "$BASE_DIR"

# === Base Deployment ===
cat > "${BASE_DIR}/deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${SERVICE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${SERVICE}
  template:
    metadata:
      labels:
        app: ${SERVICE}
    spec:
      containers:
        - name: ${SERVICE}
          image: chemch/${SERVICE}:latest
          imagePullPolicy: Always
EOF

# === Base Service ===
cat > "${BASE_DIR}/service.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ${SERVICE}
  labels:
    app: ${SERVICE}
spec:
  selector:
    app: ${SERVICE}
  type: ClusterIP
EOF

# === Base Kustomization ===
cat > "${BASE_DIR}/kustomization.yaml" <<EOF
resources:
  - deployment.yaml
  - service.yaml
EOF

echo "✅ Base created for $SERVICE."

# === Overlays ===
for ENV in "${ENVIRONMENTS[@]}"; do
  echo "📦 Creating overlay: ${ENV}"
  ENV_DIR="${OVERLAYS_DIR}/${ENV}"
  mkdir -p "$ENV_DIR"

  # Namespace YAML
  cat > "${ENV_DIR}/${SERVICE}-namespace.yaml" <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${SERVICE}-${ENV}
EOF

  # Deployment patch
  cat > "${ENV_DIR}/patch-${SERVICE}-deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${SERVICE}
spec:
  replicas: REPLICA_COUNT_PLACEHOLDER
  template:
    spec:
      containers:
        - name: ${SERVICE}
          env:
            - name: PORT
              value: "PORT_PLACEHOLDER"
EOF

  # Service patch
  cat > "${ENV_DIR}/patch-${SERVICE}-service.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ${SERVICE}
\$patch: replace
spec:
  selector:
    app: ${SERVICE}
  ports:
    - name: http
      protocol: TCP
      port: PORT_PLACEHOLDER
      targetPort: PORT_PLACEHOLDER
  type: ClusterIP
EOF

  # Overlay kustomization.yaml
  cat > "${ENV_DIR}/kustomization.yaml" <<EOF
resources:
  - ${SERVICE}-namespace.yaml
  - ../../../base/${SERVICE}

patches:
  - path: patch-${SERVICE}-deployment.yaml
  - path: patch-${SERVICE}-service.yaml

images:
  - name: chemch/${SERVICE}
    newTag: ${ENV}
EOF
done

echo "✅ Overlay scaffolding complete for $SERVICE."