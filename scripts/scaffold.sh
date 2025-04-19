#!/bin/bash

set -e

# Get script directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(dirname "$SCRIPT_DIR")

# Use absolute paths
OVERLAY_ROOT="${REPO_ROOT}/overlays"
BASE_ROOT="${REPO_ROOT}/base"
ARGO_ROOT="${REPO_ROOT}/argo"

# === Config Environments ===
ENVIRONMENTS=("dev" "qa" "uat" "prod")

# === Usage Check ===
if [ -z "$1" ]; then
  echo "Usage: ./scaffold-service.sh <service-name>"
  exit 1
fi

SERVICE=$1

echo "Creating scaffold for service: $SERVICE"

# === Create base ===
BASE_DIR="${BASE_ROOT}/${SERVICE}"
mkdir -p "$BASE_DIR"

cat > "$BASE_DIR/deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${SERVICE}
spec:
  replicas: <REPLICA_COUNT_PLACEHOLDER>
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
          ports:
            - containerPort: <PORT_PLACEHOLDER>
EOF

cat > "$BASE_DIR/service.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ${SERVICE}
  labels:
    app: ${SERVICE}
spec:
  selector:
    app: ${SERVICE}
  ports:
    - name: http
      protocol: TCP
      port: <PORT_PLACEHOLDER>
      targetPort: <PORT_PLACEHOLDER>
  type: ClusterIP
EOF

cat > "$BASE_DIR/kustomization.yaml" <<EOF
resources:
  - deployment.yaml
  - service.yaml
EOF

echo "Base created for $SERVICE."

# === Create overlays ===
for ENV in "${ENVIRONMENTS[@]}"; do
  OVERLAY_DIR="${OVERLAY_ROOT}/${SERVICE}/${ENV}"
  mkdir -p "$OVERLAY_DIR"

  cat > "$OVERLAY_DIR/patch-${SERVICE}-deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${SERVICE}
spec:
  replicas: <REPLICA_COUNT_PLACEHOLDER>
  template:
    spec:
      containers:
        - name: ${SERVICE}
          env:
            - name: PORT
              value: "<PORT_PLACEHOLDER>"
EOF

  cat > "$OVERLAY_DIR/patch-${SERVICE}-service.yaml" <<EOF
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
      port: <PORT_PLACEHOLDER>
      targetPort: <PORT_PLACEHOLDER>
  type: ClusterIP
EOF

  cat > "$OVERLAY_DIR/${SERVICE}-namespace.yaml" <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${SERVICE}-${ENV}
EOF

  cat > "$OVERLAY_DIR/kustomization.yaml" <<EOF
resources:
  - ${SERVICE}-namespace.yaml
  - ../../../../base/${SERVICE}

patches:
  - path: patch-${SERVICE}-deployment.yaml
  - path: patch-${SERVICE}-service.yaml

images:
  - name: chemch/${SERVICE}
    newTag: ${ENV}
EOF

  echo "Overlay created for $SERVICE in $ENV."
done

# === Create Argo CD app manifests ===
ARGO_DIR="${ARGO_ROOT}/${SERVICE}"
mkdir -p "$ARGO_DIR"

for ENV in "${ENVIRONMENTS[@]}"; do
  cat > "$ARGO_DIR/${ENV}.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${SERVICE}-${ENV}
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/chemch/caz-conf.git
    targetRevision: main
    path: overlays/${SERVICE}/${ENV}
  destination:
    server: https://kubernetes.default.svc
    namespace: ${SERVICE}-${ENV}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
done

echo "Argo CD app manifests created."

echo "$SERVICE scaffolding is complete."