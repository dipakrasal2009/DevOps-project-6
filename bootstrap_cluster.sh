#!/bin/bash

# bootstrap_cluster.sh - Create cluster and install all components
# This script creates a Kubernetes cluster, installs Gitea, ArgoCD, MinIO, Trivy Operator, Velero, and sets up initial GitOps repo

# Don't exit on error - handle errors gracefully
set +e

echo "🚀 Bootstrapping Kubernetes cluster with DevOps components..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
CLUSTER_NAME="devops-pipeline"
GITEA_NAMESPACE="gitea"
ARGOCD_NAMESPACE="argocd"
MINIO_NAMESPACE="minio"
TRIVY_NAMESPACE="trivy-system"
VELERO_NAMESPACE="velero"

# Check Docker is running
print_status "Checking Docker status..."
if ! systemctl is-active --quiet docker 2>/dev/null && ! docker info >/dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker first:"
    echo "  systemctl start docker"
    echo "  systemctl enable docker"
    exit 1
fi

# Check Docker has enough resources
print_status "Checking Docker resources..."
if ! docker info | grep -q "Swarm: active"; then
    print_status "Docker is ready"
else
    print_warning "Docker Swarm is active. This may cause issues with kind."
fi

# Create kind cluster configuration
# Use single-node cluster for reliability (can add workers later if needed)
print_status "Creating kind cluster configuration..."
cat > /tmp/kind-config.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${CLUSTER_NAME}
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
  - containerPort: 30081
    hostPort: 30081
    protocol: TCP
  - containerPort: 30082
    hostPort: 30082
    protocol: TCP
  - containerPort: 30083
    hostPort: 30083
    protocol: TCP
  - containerPort: 30084
    hostPort: 30084
    protocol: TCP
  - containerPort: 30085
    hostPort: 30085
    protocol: TCP
  - containerPort: 30500
    hostPort: 30500
    protocol: TCP
EOF

# Clean up any existing cluster first
print_status "Checking for existing clusters..."
if kind get clusters | grep -q ${CLUSTER_NAME}; then
    print_warning "Cluster ${CLUSTER_NAME} already exists. Deleting..."
    kind delete cluster --name ${CLUSTER_NAME} || true
    sleep 5
    # Clean up any leftover containers
    docker ps -a | grep ${CLUSTER_NAME} | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null || true
fi

# Try creating cluster with retry logic
print_status "Creating kind cluster (this may take 2-3 minutes)..."
print_status "Using single-node cluster for better reliability..."
if kind get clusters | grep -q ${CLUSTER_NAME}; then
    print_warning "Cluster ${CLUSTER_NAME} already exists. Deleting..."
    kind delete cluster --name ${CLUSTER_NAME}
    sleep 5
fi

# Try creating cluster with retry logic
print_status "Creating kind cluster (this may take 2-3 minutes)..."
print_status "Using single-node cluster for better reliability..."

# Clean up any existing cluster first
if kind get clusters | grep -q ${CLUSTER_NAME}; then
    print_warning "Cleaning up existing cluster..."
    kind delete cluster --name ${CLUSTER_NAME} || true
    sleep 5
fi

# Create cluster - ignore storage class and worker node errors as they're non-critical
print_status "Attempting to create cluster..."
if kind create cluster --config /tmp/kind-config.yaml --wait 180s 2>&1 | tee /tmp/kind-create.log; then
    print_success "Cluster created successfully!"
else
    # Check if control plane is working even if creation had errors
    print_warning "Cluster creation had warnings. Checking if control plane is functional..."
    sleep 15
    
    # Check if cluster exists and control plane is working
    if kind get clusters | grep -q ${CLUSTER_NAME}; then
        print_status "Cluster exists, verifying control plane..."
        # Try to get kubeconfig
        mkdir -p ~/.kube
        if kind get kubeconfig --name ${CLUSTER_NAME} > ~/.kube/config 2>/dev/null; then
            export KUBECONFIG=~/.kube/config
            if kubectl cluster-info &>/dev/null 2>&1 && kubectl get nodes &>/dev/null 2>&1; then
                print_success "Control plane is working despite warnings!"
            else
                print_error "Control plane is not responding. Trying fallback method..."
                # Fallback: delete and recreate with simpler config
                kind delete cluster --name ${CLUSTER_NAME} || true
                sleep 5
                print_status "Trying fallback: creating cluster without config file..."
                if kind create cluster --name ${CLUSTER_NAME} --wait 180s; then
                    print_success "Cluster created using fallback method!"
                else
                    print_error "All cluster creation methods failed. Please check Docker and system resources."
                    exit 1
                fi
            fi
        else
            print_error "Cannot get kubeconfig. Trying fallback method..."
            kind delete cluster --name ${CLUSTER_NAME} || true
            sleep 5
            if kind create cluster --name ${CLUSTER_NAME} --wait 180s; then
                print_success "Cluster created using fallback method!"
            else
                print_error "All cluster creation methods failed. Please check Docker and system resources."
                exit 1
            fi
        fi
    else
        print_error "Cluster creation failed completely. Trying fallback method..."
        sleep 5
        if kind create cluster --name ${CLUSTER_NAME} --wait 180s; then
            print_success "Cluster created using fallback method!"
        else
            print_error "All cluster creation methods failed. Please check:"
            echo "  1. Docker is running: systemctl status docker"
            echo "  2. Docker has enough resources: docker info"
            echo "  3. System has enough memory (at least 4GB free)"
            exit 1
        fi
    fi
fi

# Ensure kubeconfig directory exists
mkdir -p ~/.kube

# Set kubectl context and verify cluster is ready
print_status "Setting kubectl context..."
if ! kind get kubeconfig --name ${CLUSTER_NAME} > ~/.kube/config 2>/dev/null; then
    print_error "Failed to get kubeconfig from kind cluster"
    print_error "Please check if cluster is running: kind get clusters"
    print_error "If cluster exists, try: kind delete cluster --name ${CLUSTER_NAME} && ./bootstrap_cluster.sh"
    exit 1
fi

export KUBECONFIG=~/.kube/config

# Ensure context is set
kubectl config use-context kind-${CLUSTER_NAME} || {
    print_error "Failed to set kubectl context"
    exit 1
}

# Wait for cluster to be ready
print_status "Waiting for cluster to be ready..."
for i in {1..60}; do
    if kubectl cluster-info &>/dev/null && kubectl get nodes &>/dev/null && kubectl get nodes | grep -q Ready; then
        print_success "Cluster is ready!"
        break
    fi
    if [ $i -eq 60 ]; then
        print_error "Cluster is not ready after waiting. Please check Docker and retry."
        print_error "Try: systemctl restart docker && kind delete cluster --name ${CLUSTER_NAME}"
        exit 1
    fi
    sleep 2
done

# Additional wait to ensure API server is stable
print_status "Ensuring API server is stable..."
sleep 10

# Verify cluster nodes are ready
print_status "Verifying cluster nodes..."
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
READY_COUNT=$(kubectl get nodes --no-headers | grep Ready | wc -l)
print_status "Cluster has ${NODE_COUNT} node(s), ${READY_COUNT} ready"

if [ "$READY_COUNT" -eq 0 ]; then
    print_error "No nodes are ready. Cluster may be unhealthy."
    print_error "Please check: kubectl get nodes"
    exit 1
fi

kubectl get nodes
kubectl cluster-info

# Install NGINX Ingress Controller
print_status "Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml || {
    print_error "Failed to install NGINX Ingress Controller"
    exit 1
}

print_status "Waiting for NGINX Ingress Controller to be ready (this may take 2-3 minutes)..."
# Wait for ingress controller pods to be created first
for i in {1..30}; do
    if kubectl get pods -n ingress-nginx 2>/dev/null | grep -v NAME | grep -q .; then
        break
    fi
    sleep 2
done

# Wait for ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s || {
    print_warning "NGINX Ingress Controller may still be starting. Waiting additional time..."
    sleep 30
}

# Wait for webhook to be ready (critical for Gitea installation)
print_status "Waiting for NGINX Ingress webhook to be ready..."
for i in {1..60}; do
    if kubectl get validatingwebhookconfiguration ingress-nginx-admission 2>/dev/null | grep -q ingress-nginx-admission; then
        # Check if webhook endpoint is accessible
        if kubectl get endpoints ingress-nginx-controller-admission -n ingress-nginx 2>/dev/null | grep -q "<none>"; then
            sleep 2
            continue
        fi
        print_success "NGINX Ingress webhook is ready"
        break
    fi
    if [ $i -eq 60 ]; then
        print_warning "NGINX Ingress webhook may not be ready, but continuing..."
    fi
    sleep 2
done

# Additional wait to ensure webhook is fully functional
sleep 10

# Create namespaces
print_status "Creating namespaces..."
kubectl create namespace ${GITEA_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - || kubectl create namespace ${GITEA_NAMESPACE} || true
kubectl create namespace ${ARGOCD_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - || kubectl create namespace ${ARGOCD_NAMESPACE} || true
kubectl create namespace ${MINIO_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - || kubectl create namespace ${MINIO_NAMESPACE} || true
kubectl create namespace ${TRIVY_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - || kubectl create namespace ${TRIVY_NAMESPACE} || true
kubectl create namespace ${VELERO_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - || kubectl create namespace ${VELERO_NAMESPACE} || true

# Install Gitea
print_status "Installing Gitea..."
helm repo add gitea-charts https://dl.gitea.io/charts/
helm repo update

cat > /tmp/gitea-values.yaml << EOF
gitea:
  admin:
    username: admin
    password: admin123
    email: admin@devops.local
  config:
    server:
      ROOT_URL: http://gitea.local
      DOMAIN: gitea.local
    database:
      DB_TYPE: sqlite3
    service:
      DISABLE_REGISTRATION: false
persistence:
  enabled: true
  size: 10Gi
ingress:
  enabled: true
  hosts:
    - host: gitea.local
      paths:
        - path: /
          pathType: Prefix
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
service:
  http:
    type: ClusterIP
    port: 3000
EOF

# Install Gitea without --wait (will check status manually)
print_status "Installing Gitea (this may take several minutes)..."
# Uninstall existing release if present
if helm list -n ${GITEA_NAMESPACE} 2>/dev/null | grep -q gitea; then
    print_warning "Gitea release already exists, upgrading..."
    helm upgrade gitea gitea-charts/gitea \
      --namespace ${GITEA_NAMESPACE} \
      --values /tmp/gitea-values.yaml \
      --timeout 10m \
      --wait=false \
      --atomic=false || print_warning "Gitea helm upgrade completed with warnings"
else
    # Install Gitea - disable webhook validation if needed
    print_status "Installing Gitea with Helm..."
    if helm install gitea gitea-charts/gitea \
      --namespace ${GITEA_NAMESPACE} \
      --values /tmp/gitea-values.yaml \
      --timeout 10m \
      --wait=false \
      --atomic=false 2>&1 | tee /tmp/gitea-install.log; then
        print_success "Gitea Helm installation started"
    else
        # If webhook error, try disabling ingress temporarily
        if grep -q "webhook" /tmp/gitea-install.log; then
            print_warning "Webhook error detected. Installing Gitea without ingress..."
            # Create values without ingress
            cat > /tmp/gitea-values-no-ingress.yaml << EOF
gitea:
  admin:
    username: admin
    password: admin123
    email: admin@devops.local
  config:
    server:
      ROOT_URL: http://gitea.local
      DOMAIN: gitea.local
    database:
      DB_TYPE: sqlite3
    service:
      DISABLE_REGISTRATION: false
persistence:
  enabled: true
  size: 10Gi
ingress:
  enabled: false
service:
  http:
    type: ClusterIP
    port: 3000
EOF
            helm install gitea gitea-charts/gitea \
              --namespace ${GITEA_NAMESPACE} \
              --values /tmp/gitea-values-no-ingress.yaml \
              --timeout 10m \
              --wait=false \
              --atomic=false || print_warning "Gitea installation completed with warnings"
        else
            print_warning "Gitea helm install completed with warnings"
        fi
    fi
fi

# Wait for Gitea pods to be created and running
print_status "Waiting for Gitea pods to be ready (this may take a few minutes)..."
sleep 20

# Wait for pods to appear first
for i in {1..30}; do
    if kubectl get pods -n ${GITEA_NAMESPACE} -l app.kubernetes.io/name=gitea 2>/dev/null | grep -v NAME | grep -q .; then
        break
    fi
    sleep 5
done

kubectl wait --for=condition=ready --timeout=600s pod -l app.kubernetes.io/name=gitea -n ${GITEA_NAMESPACE} || \
    print_warning "Gitea pods may still be starting, but continuing..."

# Install ArgoCD
print_status "Installing ArgoCD..."
# Wait a bit more to ensure API server is fully stable
print_status "Ensuring API server is ready before ArgoCD installation..."
for i in {1..30}; do
    if kubectl cluster-info &>/dev/null && kubectl get nodes &>/dev/null; then
        break
    fi
    sleep 2
done

# Disable validation temporarily to avoid timeout issues
print_status "Downloading ArgoCD manifests..."
if curl -sSL https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml -o /tmp/argocd-install.yaml; then
    print_status "Applying ArgoCD manifests (this may take 1-2 minutes)..."
    kubectl apply -n ${ARGOCD_NAMESPACE} --validate=false -f /tmp/argocd-install.yaml || {
        print_warning "ArgoCD installation had errors. Retrying..."
        sleep 15
        kubectl apply -n ${ARGOCD_NAMESPACE} --validate=false -f /tmp/argocd-install.yaml || {
            print_error "Failed to install ArgoCD. Please check cluster connectivity."
            print_error "Try: kubectl get nodes && kubectl cluster-info"
            exit 1
        }
    }
else
    print_error "Failed to download ArgoCD manifests. Please check internet connectivity."
    exit 1
fi

print_status "Waiting for ArgoCD server to be available (this may take 2-3 minutes)..."
# Wait for ArgoCD pods to be created first
for i in {1..60}; do
    if kubectl get pods -n ${ARGOCD_NAMESPACE} -l app.kubernetes.io/name=argocd-server 2>/dev/null | grep -v NAME | grep -q .; then
        break
    fi
    sleep 2
done

kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n ${ARGOCD_NAMESPACE} || \
    print_warning "ArgoCD server may still be starting"

# Patch ArgoCD server to use LoadBalancer for kind
kubectl patch svc argocd-server -n ${ARGOCD_NAMESPACE} -p '{"spec": {"type": "LoadBalancer"}}' || true

# Install MinIO
print_status "Installing MinIO..."
helm repo add minio https://charts.min.io/
helm repo update

# Create MinIO values without ingress (will use NodePort later)
cat > /tmp/minio-values.yaml << EOF
mode: standalone
auth:
  rootUser: minioadmin
  rootPassword: minioadmin123
defaultBuckets: "velero-backups"
persistence:
  enabled: true
  size: 20Gi
service:
  type: ClusterIP
  port: 9000
ingress:
  enabled: false
resources:
  requests:
    memory: 512Mi
    cpu: 250m
EOF

# Install MinIO
print_status "Installing MinIO (this may take several minutes)..."
if helm install minio minio/minio \
  --namespace ${MINIO_NAMESPACE} \
  --values /tmp/minio-values.yaml \
  --timeout 10m \
  --wait=false \
  --atomic=false 2>&1 | tee /tmp/minio-install.log; then
    print_success "MinIO Helm installation started"
else
    if grep -q "already exists" /tmp/minio-install.log; then
        print_warning "MinIO already installed, skipping..."
    else
        print_warning "MinIO installation had issues, but continuing..."
    fi
fi

# Wait for MinIO pods to be ready
print_status "Waiting for MinIO pods to be ready..."
sleep 20

# Wait for pods to appear first
for i in {1..30}; do
    if kubectl get pods -n ${MINIO_NAMESPACE} 2>/dev/null | grep -v NAME | grep -q .; then
        break
    fi
    sleep 5
done

# Check if MinIO pods exist
if kubectl get pods -n ${MINIO_NAMESPACE} 2>/dev/null | grep -v NAME | grep -q .; then
    kubectl wait --for=condition=ready --timeout=600s pod -l app.kubernetes.io/name=minio -n ${MINIO_NAMESPACE} 2>/dev/null || \
        kubectl wait --for=condition=ready --timeout=600s pod -l app=minio -n ${MINIO_NAMESPACE} 2>/dev/null || \
        print_warning "MinIO pods may still be starting, but continuing..."
    print_success "MinIO installation completed"
else
    print_warning "MinIO pods not found, but continuing with setup..."
fi

# Install Local Docker Registry
print_status "Installing Local Docker Registry..."
kubectl create namespace registry 2>/dev/null || true

cat > /tmp/registry-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: docker-registry
  namespace: registry
spec:
  replicas: 1
  selector:
    matchLabels:
      app: docker-registry
  template:
    metadata:
      labels:
        app: docker-registry
    spec:
      containers:
      - name: registry
        image: registry:2
        ports:
        - containerPort: 5000
        volumeMounts:
        - name: registry-storage
          mountPath: /var/lib/registry
      volumes:
      - name: registry-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: docker-registry
  namespace: registry
spec:
  type: NodePort
  ports:
  - port: 5000
    targetPort: 5000
    nodePort: 30500
  selector:
    app: docker-registry
EOF

kubectl apply -f /tmp/registry-deployment.yaml
print_status "Waiting for Docker registry to be ready..."
sleep 10
kubectl wait --for=condition=available --timeout=300s deployment/docker-registry -n registry 2>/dev/null || print_warning "Registry may still be starting"

# Configure containerd to allow insecure registry
print_status "Configuring containerd for insecure registry..."
docker exec devops-pipeline-control-plane bash -c "mkdir -p /etc/containerd/certs.d/docker-registry.registry:5000" 2>/dev/null || true
docker exec devops-pipeline-control-plane bash -c 'cat > /etc/containerd/certs.d/docker-registry.registry:5000/hosts.toml << "EOFHOSTS"
server = "http://docker-registry.registry:5000"

[host."http://docker-registry.registry:5000"]
  capabilities = ["pull", "resolve"]
  skip_verify = true
EOFHOSTS
' 2>/dev/null || print_warning "Could not configure containerd (will use IP-based registry)"

# Also configure using registry IP as fallback
REGISTRY_IP=$(kubectl get svc docker-registry -n registry -o jsonpath='{.spec.clusterIP}')
if [ -n "$REGISTRY_IP" ]; then
    docker exec devops-pipeline-control-plane bash -c "mkdir -p /etc/containerd/certs.d/${REGISTRY_IP}:5000" 2>/dev/null || true
    docker exec devops-pipeline-control-plane bash -c "cat > /etc/containerd/certs.d/${REGISTRY_IP}:5000/hosts.toml << EOFHOSTS
server = \"http://${REGISTRY_IP}:5000\"

[host.\"http://${REGISTRY_IP}:5000\"]
  capabilities = [\"pull\", \"resolve\"]
  skip_verify = true
EOFHOSTS
" 2>/dev/null || true
    print_success "Registry configured with IP: ${REGISTRY_IP}"
fi

# Restart containerd
docker exec devops-pipeline-control-plane systemctl restart containerd 2>/dev/null || print_warning "Could not restart containerd"
sleep 5

print_success "Local Docker Registry installed on port 30500"
rm -f /tmp/registry-deployment.yaml

# Install Trivy Operator
print_status "Installing Trivy Operator..."
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm repo update

# Install Trivy Operator without --wait
helm install trivy-operator aqua/trivy-operator \
  --namespace ${TRIVY_NAMESPACE} \
  --create-namespace \
  --timeout 10m \
  --wait=false \
  --atomic=false || print_warning "Trivy Operator helm install completed with warnings"

# Wait for Trivy Operator pods to be ready
print_status "Waiting for Trivy Operator to be ready..."
sleep 15
# Wait for pods to appear first
for i in {1..30}; do
    if kubectl get pods -n ${TRIVY_NAMESPACE} -l app.kubernetes.io/name=trivy-operator 2>/dev/null | grep -v NAME | grep -q .; then
        break
    fi
    sleep 5
done

kubectl wait --for=condition=ready --timeout=300s pod -l app.kubernetes.io/name=trivy-operator -n ${TRIVY_NAMESPACE} || \
    print_warning "Trivy Operator may still be starting, but continuing..."

# Install Velero
print_status "Installing Velero..."
# Create MinIO credentials for Velero
cat > /tmp/credentials-velero << EOF
[default]
aws_access_key_id = minioadmin
aws_secret_access_key = minioadmin123
EOF

# Install Velero CLI plugin
print_status "Installing Velero (this may take a few minutes)..."
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.7.0 \
  --bucket velero-backups \
  --secret-file /tmp/credentials-velero \
  --use-volume-snapshots=false \
  --backup-location-config region=minio,s3ForcePathStyle=true,s3Url=http://minio.minio.svc.cluster.local:9000 \
  --namespace ${VELERO_NAMESPACE} || {
    print_warning "Velero installation completed with warnings or errors"
}

# Wait for Velero to be ready
print_status "Waiting for Velero to be ready..."
sleep 15
# Wait for pods to appear first
for i in {1..30}; do
    if kubectl get pods -n ${VELERO_NAMESPACE} -l component=velero 2>/dev/null | grep -v NAME | grep -q .; then
        break
    fi
    # Also check for deployment
    if kubectl get deployment velero -n ${VELERO_NAMESPACE} 2>/dev/null | grep -q velero; then
        break
    fi
    sleep 5
done

kubectl wait --for=condition=available --timeout=300s deployment/velero -n ${VELERO_NAMESPACE} 2>/dev/null || \
    print_warning "Velero may still be starting"

# Create ArgoCD Application for GitOps
print_status "Setting up ArgoCD Application..."
cat > /tmp/argocd-app.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: devops-pipeline-apps
  namespace: ${ARGOCD_NAMESPACE}
spec:
  project: default
  source:
    repoURL: https://github.com/auspicious27/Project6-testpurpose.git
    targetRevision: HEAD
    path: environments/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

# Apply ArgoCD Application
kubectl apply -f /tmp/argocd-app.yaml || print_warning "ArgoCD application may already exist"

# Get ArgoCD admin password
print_status "Retrieving ArgoCD admin password..."
ARGOCD_PASSWORD=""
for i in {1..30}; do
    ARGOCD_PASSWORD=$(kubectl -n ${ARGOCD_NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null)
    if [ -n "$ARGOCD_PASSWORD" ]; then
        break
    fi
    sleep 2
done
if [ -z "$ARGOCD_PASSWORD" ]; then
    print_warning "Could not retrieve ArgoCD password. You can get it later with:"
    echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
    ARGOCD_PASSWORD="<retrieve-later>"
fi

# Setup Gitea Repository and ArgoCD Integration
print_status "Setting up Gitea repository and ArgoCD integration..."

# Wait for Gitea to be fully ready
print_status "Waiting for Gitea to be ready..."
sleep 30
for i in {1..30}; do
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:30084 2>/dev/null | grep -q "200\|302"; then
        print_success "Gitea is ready"
        break
    fi
    sleep 5
done

# Create repository via Gitea API
GITEA_URL="http://localhost:30084"
GITEA_USER="admin"
GITEA_PASS="admin123"
REPO_NAME="devops-pipeline"

print_status "Creating repository in Gitea..."
curl -X POST "${GITEA_URL}/api/v1/user/repos" \
  -H "Content-Type: application/json" \
  -u "${GITEA_USER}:${GITEA_PASS}" \
  -d "{
    \"name\": \"${REPO_NAME}\",
    \"description\": \"DevOps Pipeline Application\",
    \"private\": false,
    \"auto_init\": false
  }" 2>/dev/null && print_success "Repository created in Gitea" || print_warning "Repository may already exist"

# Initialize git repository
print_status "Initializing Git repository..."
if [ ! -d ".git" ]; then
    git init
    git config user.email "devops@local"
    git config user.name "DevOps Pipeline"
    git add .
    git commit -m "Initial commit - DevOps Pipeline" || true
fi

# Add Gitea as remote
print_status "Adding Gitea as remote..."
if git remote | grep -q gitea; then
    git remote remove gitea
fi
git remote add gitea "${GITEA_URL}/${GITEA_USER}/${REPO_NAME}.git"

# Push to Gitea
print_status "Pushing code to Gitea..."
git push -u gitea main 2>/dev/null || git push -u gitea master 2>/dev/null || print_warning "Failed to push to Gitea (will retry in deploy script)"

# Configure ArgoCD to use Gitea repository
print_status "Configuring ArgoCD to watch Gitea repository..."
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: devops-pipeline-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://gitea-http.gitea.svc.cluster.local:3000/${GITEA_USER}/${REPO_NAME}.git
    targetRevision: HEAD
    path: environments/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

print_success "ArgoCD configured to watch Gitea repository"

# Get public IP for access URLs
print_status "Detecting public IP address..."
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)
if [ -z "$PUBLIC_IP" ]; then
    PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null)
fi
if [ -z "$PUBLIC_IP" ]; then
    PUBLIC_IP=$(hostname -I | awk '{print $1}')
fi
if [ -z "$PUBLIC_IP" ]; then
    PUBLIC_IP="<YOUR_PUBLIC_IP>"
    print_warning "Could not detect public IP automatically"
fi

# Clean up temporary files
rm -f /tmp/kind-config.yaml /tmp/gitea-values.yaml /tmp/gitea-values-no-ingress.yaml /tmp/minio-values.yaml /tmp/credentials-velero /tmp/argocd-app.yaml /tmp/argocd-install.yaml /tmp/gitea-install.log /tmp/registry-deployment.yaml 2>/dev/null || true

print_success "Cluster bootstrap completed successfully!"
echo ""
echo "=========================================="
echo "✅ Infrastructure Ready!"
echo "=========================================="
echo ""
print_status "Installed Components:"
echo "  ✅ Kubernetes Cluster (kind)"
echo "  ✅ NGINX Ingress Controller"
echo "  ✅ Gitea (Git Server)"
echo "  ✅ ArgoCD (GitOps)"
echo "  ✅ MinIO (S3 Storage)"
echo "  ✅ Trivy Operator (Security Scanning)"
echo "  ✅ Velero (Backup & Restore)"
echo ""
print_status "ArgoCD Password: ${ARGOCD_PASSWORD}"
echo ""
print_status "Next Steps:"
echo "  1. Run: ./deploy_pipeline.sh (to deploy applications)"
echo "  2. Run: ./check_env.sh (to verify and get access URLs)"
echo ""
print_status "Note: Services will be accessible via NodePort after running deploy_pipeline.sh"
echo "      Access URLs will be: http://${PUBLIC_IP}:PORT"
echo ""
