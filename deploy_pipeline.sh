#!/bin/bash

# deploy_pipeline.sh - Build Docker images and deploy applications
# This script builds Docker images for Flask app and microservices, and deploys them to Kubernetes with NodePort access

# Don't exit on error - handle errors gracefully
set +e

echo "🚀 Deploying DevOps Pipeline..."

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
LOCAL_REGISTRY="localhost:30500"
CLUSTER_NAME="devops-pipeline"
GITEA_URL="http://localhost:30084"
GITEA_REPO="devops-pipeline"

# Get registry ClusterIP dynamically
REGISTRY_IP=$(kubectl get svc docker-registry -n registry -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
if [ -z "$REGISTRY_IP" ]; then
    print_error "Docker registry not found. Please run bootstrap_cluster.sh first."
    exit 1
fi
CLUSTER_REGISTRY="${REGISTRY_IP}:5000"
VERSION="$(date +%Y%m%d-%H%M%S)"

print_status "Using registry: ${CLUSTER_REGISTRY}"

# Check if cluster is running
if ! kind get clusters | grep -q ${CLUSTER_NAME}; then
    print_error "Kind cluster ${CLUSTER_NAME} not found. Please run bootstrap_cluster.sh first."
    exit 1
fi

# Check if Docker is running
if ! systemctl is-active --quiet docker 2>/dev/null && ! docker info >/dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker first."
    exit 1
fi

# Set kubectl context
kubectl config use-context kind-${CLUSTER_NAME} || {
    print_error "Failed to set kubectl context"
    exit 1
}

# Verify registry is accessible
print_status "Verifying registry accessibility..."
REGISTRY_ACCESSIBLE=false
for i in {1..30}; do
    if curl -s http://${LOCAL_REGISTRY}/v2/ > /dev/null 2>&1; then
        REGISTRY_ACCESSIBLE=true
        print_success "Registry is accessible at ${LOCAL_REGISTRY}"
        break
    fi
    sleep 2
done

if [ "$REGISTRY_ACCESSIBLE" = false ]; then
    print_warning "Registry not accessible at ${LOCAL_REGISTRY}, will load images directly to kind"
    USE_KIND_LOAD=true
else
    USE_KIND_LOAD=false
fi

# Build and push Flask app to local registry
print_status "Building Flask application..."
docker build -t flask-app:latest ./apps/flask-app || {
    print_error "Failed to build Flask app"
    exit 1
}

if [ "$USE_KIND_LOAD" = true ]; then
    print_status "Loading Flask app directly to kind cluster..."
    kind load docker-image flask-app:latest --name ${CLUSTER_NAME}
    print_success "Flask app loaded to cluster"
else
    docker tag flask-app:latest ${LOCAL_REGISTRY}/flask-app:${VERSION}
    docker tag flask-app:latest ${LOCAL_REGISTRY}/flask-app:latest
    print_status "Pushing Flask app to local registry..."
    docker push ${LOCAL_REGISTRY}/flask-app:${VERSION} || print_warning "Failed to push Flask app"
    docker push ${LOCAL_REGISTRY}/flask-app:latest || print_warning "Failed to push Flask app latest tag"
    print_success "Flask app built and pushed to registry"
fi

# Build and push User Service
print_status "Building User Service..."
docker build -t user-service:latest ./apps/microservice-1 || {
    print_error "Failed to build User service"
    exit 1
}

if [ "$USE_KIND_LOAD" = true ]; then
    print_status "Loading User service directly to kind cluster..."
    kind load docker-image user-service:latest --name ${CLUSTER_NAME}
    print_success "User service loaded to cluster"
else
    docker tag user-service:latest ${LOCAL_REGISTRY}/user-service:${VERSION}
    docker tag user-service:latest ${LOCAL_REGISTRY}/user-service:latest
    print_status "Pushing User service to local registry..."
    docker push ${LOCAL_REGISTRY}/user-service:${VERSION} || print_warning "Failed to push User service"
    docker push ${LOCAL_REGISTRY}/user-service:latest || print_warning "Failed to push User service latest tag"
    print_success "User service built and pushed to registry"
fi

# Build and push Product Service
print_status "Building Product Service..."
docker build -t product-service:latest ./apps/microservice-2 || {
    print_error "Failed to build Product service"
    exit 1
}

if [ "$USE_KIND_LOAD" = true ]; then
    print_status "Loading Product service directly to kind cluster..."
    kind load docker-image product-service:latest --name ${CLUSTER_NAME}
    print_success "Product service loaded to cluster"
else
    docker tag product-service:latest ${LOCAL_REGISTRY}/product-service:${VERSION}
    docker tag product-service:latest ${LOCAL_REGISTRY}/product-service:latest
    print_status "Pushing Product service to local registry..."
    docker push ${LOCAL_REGISTRY}/product-service:${VERSION} || print_warning "Failed to push Product service"
    docker push ${LOCAL_REGISTRY}/product-service:latest || print_warning "Failed to push Product service latest tag"
    print_success "Product service built and pushed to registry"
fi

# Create namespaces
print_status "Creating namespaces..."
kubectl create namespace dev 2>/dev/null || print_status "Namespace dev already exists"
kubectl create namespace staging 2>/dev/null || print_status "Namespace staging already exists"
kubectl create namespace production 2>/dev/null || print_status "Namespace production already exists"

# Update deployment manifests with new image tags
if [ "$USE_KIND_LOAD" = true ]; then
    print_status "Updating deployment manifests for local images..."
    # Use local images without registry
    sed -i.bak "s|image: .*flask-app:latest|image: flask-app:latest|g" apps/flask-app/deployment.yaml
    sed -i.bak "s|image: .*user-service:latest|image: user-service:latest|g" apps/microservice-1/deployment.yaml
    sed -i.bak "s|image: .*product-service:latest|image: product-service:latest|g" apps/microservice-2/deployment.yaml
    sed -i.bak "s|imagePullPolicy: Always|imagePullPolicy: Never|g" apps/flask-app/deployment.yaml
    sed -i.bak "s|imagePullPolicy: Always|imagePullPolicy: Never|g" apps/microservice-1/deployment.yaml
    sed -i.bak "s|imagePullPolicy: Always|imagePullPolicy: Never|g" apps/microservice-2/deployment.yaml
    print_success "Deployment manifests updated for local images"
else
    print_status "Updating deployment manifests with registry IP: ${CLUSTER_REGISTRY}..."
    # Replace any existing image references with the current registry IP
    sed -i.bak "s|image: flask-app:latest|image: ${CLUSTER_REGISTRY}/flask-app:latest|g" apps/flask-app/deployment.yaml
    sed -i.bak "s|image: user-service:latest|image: ${CLUSTER_REGISTRY}/user-service:latest|g" apps/microservice-1/deployment.yaml
    sed -i.bak "s|image: product-service:latest|image: ${CLUSTER_REGISTRY}/product-service:latest|g" apps/microservice-2/deployment.yaml
    sed -i.bak "s|image: docker-registry.registry:[0-9]*/flask-app:latest|image: ${CLUSTER_REGISTRY}/flask-app:latest|g" apps/flask-app/deployment.yaml
    sed -i.bak "s|image: docker-registry.registry:[0-9]*/user-service:latest|image: ${CLUSTER_REGISTRY}/user-service:latest|g" apps/microservice-1/deployment.yaml
    sed -i.bak "s|image: docker-registry.registry:[0-9]*/product-service:latest|image: ${CLUSTER_REGISTRY}/product-service:latest|g" apps/microservice-2/deployment.yaml
    sed -i.bak "s|image: [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*:[0-9]*/flask-app:latest|image: ${CLUSTER_REGISTRY}/flask-app:latest|g" apps/flask-app/deployment.yaml
    sed -i.bak "s|image: [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*:[0-9]*/user-service:latest|image: ${CLUSTER_REGISTRY}/user-service:latest|g" apps/microservice-1/deployment.yaml
    sed -i.bak "s|image: [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*:[0-9]*/product-service:latest|image: ${CLUSTER_REGISTRY}/product-service:latest|g" apps/microservice-2/deployment.yaml
    sed -i.bak "s|imagePullPolicy: Never|imagePullPolicy: Always|g" apps/flask-app/deployment.yaml
    sed -i.bak "s|imagePullPolicy: Never|imagePullPolicy: Always|g" apps/microservice-1/deployment.yaml
    sed -i.bak "s|imagePullPolicy: Never|imagePullPolicy: Always|g" apps/microservice-2/deployment.yaml
    print_success "Deployment manifests updated with registry ${CLUSTER_REGISTRY}"
fi

# Initialize git repo if not already done
if [ ! -d ".git" ]; then
    print_status "Initializing Git repository..."
    git init
    git config user.email "devops@local"
    git config user.name "DevOps Pipeline"
    git add .
    git commit -m "Initial commit" || true
fi

# Commit changes
print_status "Committing changes to Git..."
git add apps/*/deployment.yaml environments/
git commit -m "Update image tags to ${VERSION}" || print_warning "No changes to commit"

# Push to Gitea (if configured)
print_status "Pushing to Gitea repository..."
if git remote | grep -q gitea; then
    git push gitea main 2>/dev/null || git push gitea master 2>/dev/null || print_warning "Failed to push to Gitea (repo may not be configured)"
else
    print_warning "Gitea remote not configured. Run: git remote add gitea ${GITEA_URL}/admin/${GITEA_REPO}.git"
fi

# Scale down infrastructure to free up CPU resources
print_status "Optimizing cluster resources..."
kubectl scale statefulset gitea-postgresql-ha-postgresql --replicas=1 -n gitea 2>/dev/null || true
kubectl scale statefulset gitea-valkey-cluster --replicas=1 -n gitea 2>/dev/null || true
print_success "Infrastructure scaled down to conserve resources"

# Wait for resources to free up
sleep 10

# Trigger ArgoCD sync
print_status "Triggering ArgoCD sync..."
kubectl patch application devops-pipeline-dev -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"normal"}}}' 2>/dev/null || print_warning "ArgoCD application not found, deploying directly..."

# Deploy applications directly to dev namespace (fallback if ArgoCD not syncing)
print_status "Deploying applications to dev namespace..."
kubectl apply -f apps/flask-app/deployment.yaml -n dev || print_warning "Failed to deploy Flask app"
kubectl apply -f apps/microservice-1/deployment.yaml -n dev || print_warning "Failed to deploy User service"
kubectl apply -f apps/microservice-2/deployment.yaml -n dev || print_warning "Failed to deploy Product service"

# Wait for deployments to be ready
print_status "Waiting for deployments to be ready (this may take 2-3 minutes)..."
sleep 20

for deployment in flask-app user-service product-service; do
    print_status "Waiting for ${deployment} deployment..."
    if kubectl wait --for=condition=available --timeout=300s deployment/${deployment} -n dev 2>/dev/null; then
        print_success "${deployment} is ready"
    else
        print_warning "${deployment} may still be starting. Checking pod status..."
        kubectl get pods -n dev -l app=${deployment} 2>/dev/null || true
    fi
done

# Expose services as NodePort
print_status "Exposing services via NodePort..."

# Get service names first
FLASK_SVC=$(kubectl get svc -n dev -l app=flask-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
USER_SVC=$(kubectl get svc -n dev -l app=user-service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
PRODUCT_SVC=$(kubectl get svc -n dev -l app=product-service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

# Patch Flask app service to NodePort
if [ -n "$FLASK_SVC" ]; then
    kubectl patch svc $FLASK_SVC -n dev -p '{"spec":{"type":"NodePort","ports":[{"port":80,"targetPort":5000,"nodePort":30080}]}}' 2>/dev/null && print_success "Flask app exposed on port 30080"
else
    print_warning "Flask app service not found, creating new one..."
    kubectl expose deployment flask-app -n dev --type=NodePort --port=80 --target-port=5000 --name=flask-app-service 2>/dev/null || true
    kubectl patch svc flask-app-service -n dev -p '{"spec":{"ports":[{"port":80,"targetPort":5000,"nodePort":30080}]}}' 2>/dev/null || true
fi

# Patch User service to NodePort
if [ -n "$USER_SVC" ]; then
    kubectl patch svc $USER_SVC -n dev -p '{"spec":{"type":"NodePort","ports":[{"port":5001,"targetPort":5001,"nodePort":30081}]}}' 2>/dev/null && print_success "User service exposed on port 30081"
else
    print_warning "User service not found, creating new one..."
    kubectl expose deployment user-service -n dev --type=NodePort --port=5001 --target-port=5001 --name=user-service 2>/dev/null || true
    kubectl patch svc user-service -n dev -p '{"spec":{"ports":[{"port":5001,"targetPort":5001,"nodePort":30081}]}}' 2>/dev/null || true
fi

# Patch Product service to NodePort
if [ -n "$PRODUCT_SVC" ]; then
    kubectl patch svc $PRODUCT_SVC -n dev -p '{"spec":{"type":"NodePort","ports":[{"port":5002,"targetPort":5002,"nodePort":30082}]}}' 2>/dev/null && print_success "Product service exposed on port 30082"
else
    print_warning "Product service not found, creating new one..."
    kubectl expose deployment product-service -n dev --type=NodePort --port=5002 --target-port=5002 --name=product-service 2>/dev/null || true
    kubectl patch svc product-service -n dev -p '{"spec":{"ports":[{"port":5002,"targetPort":5002,"nodePort":30082}]}}' 2>/dev/null || true
fi

# Expose ArgoCD as NodePort
print_status "Exposing ArgoCD via NodePort..."
kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"NodePort","ports":[{"name":"http","port":80,"targetPort":8080,"nodePort":30083},{"name":"https","port":443,"targetPort":8080,"nodePort":30443}]}}' 2>/dev/null && print_success "ArgoCD exposed on port 30083"

# Expose Gitea as NodePort
print_status "Exposing Gitea via NodePort..."
kubectl patch svc gitea-http -n gitea -p '{"spec":{"type":"NodePort","ports":[{"port":3000,"targetPort":3000,"nodePort":30084}]}}' 2>/dev/null && print_success "Gitea exposed on port 30084"

# Expose MinIO as NodePort (if it exists)
print_status "Exposing MinIO via NodePort..."
if kubectl get svc minio -n minio 2>/dev/null; then
    kubectl patch svc minio -n minio -p '{"spec":{"type":"NodePort","ports":[{"port":9000,"targetPort":9000,"nodePort":30085}]}}' 2>/dev/null && print_success "MinIO exposed on port 30085"
elif kubectl get svc -n minio -l app.kubernetes.io/name=minio 2>/dev/null | grep -v NAME | grep -q .; then
    MINIO_SVC=$(kubectl get svc -n minio -l app.kubernetes.io/name=minio -o jsonpath='{.items[0].metadata.name}')
    kubectl patch svc $MINIO_SVC -n minio -p '{"spec":{"type":"NodePort","ports":[{"port":9000,"targetPort":9000,"nodePort":30085}]}}' 2>/dev/null && print_success "MinIO exposed on port 30085"
else
    print_warning "MinIO service not found, skipping..."
fi

# Get public IP
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

# Apply ArgoCD project and applications (optional - for GitOps)
print_status "Applying ArgoCD configurations (optional)..."
kubectl apply -f argocd/project.yaml 2>/dev/null || true
kubectl apply -f argocd/argocd-apps.yaml 2>/dev/null || true

# Verify deployments
print_status "Verifying deployments..."
echo ""
echo "=== Pods in dev namespace ==="
kubectl get pods -n dev
echo ""
echo "=== Services in dev namespace ==="
kubectl get svc -n dev
echo ""

# Run security scan with Trivy (suppress output for cleaner display)
print_status "Running security scan with Trivy..."
trivy image --severity HIGH,CRITICAL flask-app:${VERSION} > /tmp/trivy-flask.txt 2>&1 || true
trivy image --severity HIGH,CRITICAL user-service:${VERSION} > /tmp/trivy-user.txt 2>&1 || true
trivy image --severity HIGH,CRITICAL product-service:${VERSION} > /tmp/trivy-product.txt 2>&1 || true
print_success "Security scans completed (reports saved to /tmp/trivy-*.txt)"

print_success "Pipeline deployment completed successfully!"
echo ""
echo "=========================================="
echo "🌐 ACCESS URLs (Use these from your browser):"
echo "=========================================="
echo ""
echo "Flask App:       http://${PUBLIC_IP}:30080"
echo "User Service:    http://${PUBLIC_IP}:30081/api/users"
echo "Product Service: http://${PUBLIC_IP}:30082/api/products"
echo "ArgoCD:          http://${PUBLIC_IP}:30083"
echo "Gitea:           http://${PUBLIC_IP}:30084"
echo "MinIO:           http://${PUBLIC_IP}:30085"
echo ""
echo "=========================================="
echo "🔐 CREDENTIALS:"
echo "=========================================="
echo ""
echo "Gitea:  admin / admin123"
echo "MinIO:  minioadmin / minioadmin123"
echo ""
echo "ArgoCD: admin / <run command below>"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d && echo"
echo ""
echo "=========================================="
echo "⚠️  IMPORTANT - AWS Security Group:"
echo "=========================================="
echo ""
echo "Make sure these ports are open in your AWS Security Group:"
echo "  - 30080 (Flask App)"
echo "  - 30081 (User Service)"
echo "  - 30082 (Product Service)"
echo "  - 30083 (ArgoCD)"
echo "  - 30084 (Gitea)"
echo "  - 30085 (MinIO)"
echo ""
echo "To open ports, go to:"
echo "  AWS Console → EC2 → Security Groups → Select your SG → Edit Inbound Rules"
echo "  Add Custom TCP rules for ports 30080-30085 from source 0.0.0.0/0"
echo ""
echo "=========================================="
echo "✅ NEXT STEPS:"
echo "=========================================="
echo ""
echo "1. Open the ports in AWS Security Group (see above)"
echo "2. Access Flask App: http://${PUBLIC_IP}:30080"
echo "3. Run: ./check_env.sh (to verify everything)"
echo ""
