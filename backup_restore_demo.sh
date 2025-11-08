#!/bin/bash

# backup_restore_demo.sh - Velero backup and restore demonstration
# This script demonstrates backup and restore functionality using Velero with MinIO

set -e

echo "💾 Backup and Restore Demo with Velero..."

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
BACKUP_NAME="devops-pipeline-backup-$(date +%Y%m%d-%H%M%S)"
RESTORE_NAME="devops-pipeline-restore-$(date +%Y%m%d-%H%M%S)"
NAMESPACE="dev"
VELERO_NAMESPACE="velero"

# Check if Velero is installed
if ! kubectl get deployment velero -n ${VELERO_NAMESPACE} &> /dev/null; then
    print_error "Velero is not installed. Please run bootstrap_cluster.sh first."
    exit 1
fi

# Check if namespace exists
if ! kubectl get namespace ${NAMESPACE} &> /dev/null; then
    print_error "Namespace ${NAMESPACE} does not exist. Please run deploy_pipeline.sh first."
    exit 1
fi

# Function to create test data
create_test_data() {
    print_status "Creating test data in ${NAMESPACE} namespace..."
    
    # Create a test configmap
    kubectl create configmap test-data --from-literal=message="This is test data for backup demo" -n ${NAMESPACE}
    
    # Create a test secret
    kubectl create secret generic test-secret --from-literal=password="backup-demo-password" -n ${NAMESPACE}
    
    # Scale up deployments to have more data
    kubectl scale deployment flask-app --replicas=3 -n ${NAMESPACE}
    kubectl scale deployment user-service --replicas=3 -n ${NAMESPACE}
    kubectl scale deployment product-service --replicas=3 -n ${NAMESPACE}
    
    # Wait for pods to be ready
    kubectl wait --for=condition=ready pod -l app=flask-app -n ${NAMESPACE} --timeout=60s
    kubectl wait --for=condition=ready pod -l app=user-service -n ${NAMESPACE} --timeout=60s
    kubectl wait --for=condition=ready pod -l app=product-service -n ${NAMESPACE} --timeout=60s
    
    print_success "Test data created successfully"
}

# Function to show current state
show_current_state() {
    print_status "Current state of ${NAMESPACE} namespace:"
    echo "Pods:"
    kubectl get pods -n ${NAMESPACE}
    echo ""
    echo "ConfigMaps:"
    kubectl get configmaps -n ${NAMESPACE}
    echo ""
    echo "Secrets:"
    kubectl get secrets -n ${NAMESPACE}
    echo ""
}

# Function to create backup
create_backup() {
    print_status "Creating backup: ${BACKUP_NAME}"
    
    # Create backup
    velero backup create ${BACKUP_NAME} \
        --include-namespaces ${NAMESPACE} \
        --wait
    
    # Check backup status
    velero backup describe ${BACKUP_NAME} --details
    
    print_success "Backup created successfully: ${BACKUP_NAME}"
}

# Function to simulate disaster
simulate_disaster() {
    print_status "Simulating disaster by deleting namespace..."
    
    # Delete the namespace (simulating disaster)
    kubectl delete namespace ${NAMESPACE} --ignore-not-found=true
    
    # Wait for namespace to be deleted
    while kubectl get namespace ${NAMESPACE} &> /dev/null; do
        print_status "Waiting for namespace to be deleted..."
        sleep 5
    done
    
    print_warning "Disaster simulated - namespace ${NAMESPACE} has been deleted"
}

# Function to restore from backup
restore_from_backup() {
    print_status "Restoring from backup: ${BACKUP_NAME}"
    
    # Create restore
    velero restore create ${RESTORE_NAME} \
        --from-backup ${BACKUP_NAME} \
        --wait
    
    # Check restore status
    velero restore describe ${RESTORE_NAME} --details
    
    print_success "Restore completed successfully: ${RESTORE_NAME}"
}

# Function to verify restore
verify_restore() {
    print_status "Verifying restore..."
    
    # Wait for namespace to be recreated
    while ! kubectl get namespace ${NAMESPACE} &> /dev/null; do
        print_status "Waiting for namespace to be recreated..."
        sleep 5
    done
    
    # Wait for deployments to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/flask-app -n ${NAMESPACE}
    kubectl wait --for=condition=available --timeout=300s deployment/user-service -n ${NAMESPACE}
    kubectl wait --for=condition=available --timeout=300s deployment/product-service -n ${NAMESPACE}
    
    # Show restored state
    show_current_state
    
    print_success "Restore verification completed"
}

# Function to cleanup
cleanup() {
    print_status "Cleaning up test data..."
    
    # Delete test configmap and secret
    kubectl delete configmap test-data -n ${NAMESPACE} --ignore-not-found=true
    kubectl delete secret test-secret -n ${NAMESPACE} --ignore-not-found=true
    
    # Scale back to original replicas
    kubectl scale deployment flask-app --replicas=2 -n ${NAMESPACE}
    kubectl scale deployment user-service --replicas=2 -n ${NAMESPACE}
    kubectl scale deployment product-service --replicas=2 -n ${NAMESPACE}
    
    print_success "Cleanup completed"
}

# Function to show backup history
show_backup_history() {
    print_status "Backup history:"
    velero backup get
    echo ""
    print_status "Restore history:"
    velero restore get
}

# Main demo function
main() {
    print_status "Starting Velero backup and restore demo..."
    
    # Step 1: Create test data
    create_test_data
    
    # Step 2: Show current state
    show_current_state
    
    # Step 3: Create backup
    create_backup
    
    # Step 4: Simulate disaster
    simulate_disaster
    
    # Step 5: Restore from backup
    restore_from_backup
    
    # Step 6: Verify restore
    verify_restore
    
    # Step 7: Cleanup
    cleanup
    
    # Step 8: Show history
    show_backup_history
    
    print_success "Backup and restore demo completed successfully!"
    print_status "Backup created: ${BACKUP_NAME}"
    print_status "Restore completed: ${RESTORE_NAME}"
}

# Check if running in demo mode
if [ "$1" = "demo" ]; then
    main
else
    print_error "Usage: $0 demo"
    print_error "This script runs a complete backup and restore demonstration."
    exit 1
fi
