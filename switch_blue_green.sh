#!/bin/bash

# switch_blue_green.sh - Blue-green deployment switching script
# This script demonstrates blue-green deployment strategy by switching traffic between blue and green versions

set -e

echo "🔄 Blue-Green Deployment Switch..."

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
NAMESPACE="blue-green"
CURRENT_VERSION=""
NEW_VERSION=""

# Check if namespace exists
if ! kubectl get namespace ${NAMESPACE} &> /dev/null; then
    print_status "Creating blue-green namespace..."
    kubectl create namespace ${NAMESPACE}
fi

# Function to determine current version
get_current_version() {
    local service_name=$1
    local selector=$(kubectl get service ${service_name} -n ${NAMESPACE} -o jsonpath='{.spec.selector.version}' 2>/dev/null || echo "")
    echo ${selector}
}

# Function to get new version
get_new_version() {
    local current=$1
    if [ "$current" = "blue" ]; then
        echo "green"
    else
        echo "blue"
    fi
}

# Function to create blue-green deployment
create_blue_green_deployment() {
    local app_name=$1
    local port=$2
    local version=$3
    
    print_status "Creating ${version} deployment for ${app_name}..."
    
    cat > ${app_name}-${version}.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${app_name}-${version}
  namespace: ${NAMESPACE}
  labels:
    app: ${app_name}
    version: ${version}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ${app_name}
      version: ${version}
  template:
    metadata:
      labels:
        app: ${app_name}
        version: ${version}
    spec:
      containers:
      - name: ${app_name}
        image: ${app_name}:latest
        ports:
        - containerPort: ${port}
        env:
        - name: VERSION
          value: "${version}"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /api/health
            port: ${port}
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /api/health
            port: ${port}
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: ${app_name}-${version}
  namespace: ${NAMESPACE}
  labels:
    app: ${app_name}
    version: ${version}
spec:
  selector:
    app: ${app_name}
    version: ${version}
  ports:
  - protocol: TCP
    port: ${port}
    targetPort: ${port}
  type: ClusterIP
EOF

    kubectl apply -f ${app_name}-${version}.yaml
    rm ${app_name}-${version}.yaml
}

# Function to create main service
create_main_service() {
    local app_name=$1
    local port=$2
    local version=$3
    
    print_status "Creating main service for ${app_name} pointing to ${version}..."
    
    cat > ${app_name}-service.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: ${app_name}
  namespace: ${NAMESPACE}
  labels:
    app: ${app_name}
spec:
  selector:
    app: ${app_name}
    version: ${version}
  ports:
  - protocol: TCP
    port: ${port}
    targetPort: ${port}
  type: ClusterIP
EOF

    kubectl apply -f ${app_name}-service.yaml
    rm ${app_name}-service.yaml
}

# Function to switch traffic
switch_traffic() {
    local app_name=$1
    local port=$2
    local new_version=$3
    
    print_status "Switching traffic for ${app_name} to ${new_version}..."
    
    # Update service selector
    kubectl patch service ${app_name} -n ${NAMESPACE} --type='merge' -p='{"spec":{"selector":{"version":"'${new_version}'"}}}'
    
    # Wait for rollout
    kubectl rollout status deployment/${app_name}-${new_version} -n ${NAMESPACE} --timeout=300s
    
    print_success "Traffic switched to ${new_version} for ${app_name}"
}

# Function to cleanup old version
cleanup_old_version() {
    local app_name=$1
    local old_version=$2
    
    print_status "Cleaning up old ${old_version} version for ${app_name}..."
    
    # Scale down old deployment
    kubectl scale deployment ${app_name}-${old_version} --replicas=0 -n ${NAMESPACE}
    
    # Delete old service
    kubectl delete service ${app_name}-${old_version} -n ${NAMESPACE} --ignore-not-found=true
    
    print_success "Cleaned up old ${old_version} version"
}

# Main blue-green deployment logic
main() {
    local app_name=$1
    local port=$2
    
    if [ -z "$app_name" ] || [ -z "$port" ]; then
        print_error "Usage: $0 <app_name> <port>"
        print_error "Example: $0 flask-app 5000"
        exit 1
    fi
    
    print_status "Starting blue-green deployment for ${app_name}..."
    
    # Determine current version
    CURRENT_VERSION=$(get_current_version ${app_name})
    if [ -z "$CURRENT_VERSION" ]; then
        CURRENT_VERSION="blue"
        print_status "No current version found, starting with blue"
    fi
    
    # Determine new version
    NEW_VERSION=$(get_new_version ${CURRENT_VERSION})
    print_status "Current version: ${CURRENT_VERSION}, Switching to: ${NEW_VERSION}"
    
    # Create new version deployment
    create_blue_green_deployment ${app_name} ${port} ${NEW_VERSION}
    
    # Wait for new deployment to be ready
    print_status "Waiting for ${NEW_VERSION} deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/${app_name}-${NEW_VERSION} -n ${NAMESPACE}
    
    # Create main service if it doesn't exist
    if ! kubectl get service ${app_name} -n ${NAMESPACE} &> /dev/null; then
        create_main_service ${app_name} ${port} ${CURRENT_VERSION}
    fi
    
    # Switch traffic
    switch_traffic ${app_name} ${port} ${NEW_VERSION}
    
    # Wait a bit for traffic to stabilize
    print_status "Waiting for traffic to stabilize..."
    sleep 30
    
    # Verify switch
    print_status "Verifying traffic switch..."
    kubectl get pods -n ${NAMESPACE} -l app=${app_name}
    
    # Cleanup old version
    cleanup_old_version ${app_name} ${CURRENT_VERSION}
    
    print_success "Blue-green deployment completed successfully!"
    print_status "Current active version: ${NEW_VERSION}"
}

# Demo function for all applications
demo_all_apps() {
    print_status "Running blue-green demo for all applications..."
    
    # Flask app
    main "flask-app" "5000"
    
    # User service
    main "user-service" "5001"
    
    # Product service
    main "product-service" "5002"
    
    print_success "Blue-green deployment demo completed for all applications!"
}

# Check if running demo mode
if [ "$1" = "demo" ]; then
    demo_all_apps
else
    main "$1" "$2"
fi
