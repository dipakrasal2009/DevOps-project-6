#!/bin/bash

# check_env.sh - Health checks for all components
# This script validates that all components (ArgoCD, Gitea, Velero, Trivy, apps) are healthy

# Don't exit on error - handle errors gracefully
set +e

echo "🔍 Checking DevOps Pipeline Environment Health..."

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
NAMESPACES=("argocd" "gitea" "minio" "trivy-system" "velero" "dev" "staging" "production")

# Function to check if command exists
check_command() {
    if command -v $1 &> /dev/null; then
        print_success "$1 is installed"
        return 0
    else
        print_error "$1 is not installed"
        return 1
    fi
}

# Function to check cluster status
check_cluster() {
    print_status "Checking Kubernetes cluster..."
    
    if kind get clusters | grep -q ${CLUSTER_NAME}; then
        print_success "Kind cluster ${CLUSTER_NAME} is running"
    else
        print_error "Kind cluster ${CLUSTER_NAME} is not running"
        return 1
    fi
    
    # Check cluster nodes
    local nodes=$(kubectl get nodes --no-headers | wc -l)
    print_status "Cluster has ${nodes} nodes"
    
    # Check if all nodes are ready
    local ready_nodes=$(kubectl get nodes --no-headers | grep Ready | wc -l)
    if [ "$ready_nodes" -eq "$nodes" ]; then
        print_success "All nodes are ready"
    else
        print_error "Some nodes are not ready"
        return 1
    fi
}

# Function to check namespace
check_namespace() {
    local namespace=$1
    
    if kubectl get namespace ${namespace} &> /dev/null; then
        print_success "Namespace ${namespace} exists"
        
        # Check pods in namespace
        local pods=$(kubectl get pods -n ${namespace} --no-headers 2>/dev/null | wc -l)
        local ready_pods=$(kubectl get pods -n ${namespace} --no-headers 2>/dev/null | grep Running | wc -l)
        
        if [ "$pods" -gt 0 ]; then
            print_status "Namespace ${namespace}: ${ready_pods}/${pods} pods running"
            
            if [ "$ready_pods" -eq "$pods" ]; then
                print_success "All pods in ${namespace} are running"
            else
                print_warning "Some pods in ${namespace} are not running"
            fi
        else
            print_warning "No pods found in ${namespace}"
        fi
    else
        print_error "Namespace ${namespace} does not exist"
        return 1
    fi
}

# Function to check ArgoCD
check_argocd() {
    print_status "Checking ArgoCD..."
    
    # Check ArgoCD server
    if kubectl get deployment argocd-server -n argocd &> /dev/null; then
        local replicas=$(kubectl get deployment argocd-server -n argocd -o jsonpath='{.status.readyReplicas}')
        local desired=$(kubectl get deployment argocd-server -n argocd -o jsonpath='{.spec.replicas}')
        
        if [ "$replicas" -eq "$desired" ]; then
            print_success "ArgoCD server is running (${replicas}/${desired})"
        else
            print_error "ArgoCD server is not ready (${replicas}/${desired})"
            return 1
        fi
    else
        print_error "ArgoCD server deployment not found"
        return 1
    fi
    
    # Check ArgoCD applications
    local apps=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l)
    print_status "ArgoCD has ${apps} applications"
    
    # Check application health
    kubectl get applications -n argocd --no-headers | while read line; do
        local app_name=$(echo $line | awk '{print $1}')
        local health=$(echo $line | awk '{print $3}')
        local sync=$(echo $line | awk '{print $4}')
        
        if [ "$health" = "Healthy" ] && [ "$sync" = "Synced" ]; then
            print_success "Application ${app_name} is healthy and synced"
        else
            print_warning "Application ${app_name} health: ${health}, sync: ${sync}"
        fi
    done
}

# Function to check Gitea
check_gitea() {
    print_status "Checking Gitea..."
    
    if kubectl get deployment gitea -n gitea &> /dev/null; then
        local replicas=$(kubectl get deployment gitea -n gitea -o jsonpath='{.status.readyReplicas}')
        local desired=$(kubectl get deployment gitea -n gitea -o jsonpath='{.spec.replicas}')
        
        if [ "$replicas" -eq "$desired" ]; then
            print_success "Gitea is running (${replicas}/${desired})"
        else
            print_error "Gitea is not ready (${replicas}/${desired})"
            return 1
        fi
    else
        print_error "Gitea deployment not found"
        return 1
    fi
}

# Function to check MinIO
check_minio() {
    print_status "Checking MinIO..."
    
    if kubectl get deployment minio -n minio &> /dev/null; then
        local replicas=$(kubectl get deployment minio -n minio -o jsonpath='{.status.readyReplicas}')
        local desired=$(kubectl get deployment minio -n minio -o jsonpath='{.spec.replicas}')
        
        if [ "$replicas" -eq "$desired" ]; then
            print_success "MinIO is running (${replicas}/${desired})"
        else
            print_error "MinIO is not ready (${replicas}/${desired})"
            return 1
        fi
    else
        print_error "MinIO deployment not found"
        return 1
    fi
}

# Function to check Trivy Operator
check_trivy() {
    print_status "Checking Trivy Operator..."
    
    if kubectl get deployment trivy-operator -n trivy-system &> /dev/null; then
        local replicas=$(kubectl get deployment trivy-operator -n trivy-system -o jsonpath='{.status.readyReplicas}')
        local desired=$(kubectl get deployment trivy-operator -n trivy-system -o jsonpath='{.spec.replicas}')
        
        if [ "$replicas" -eq "$desired" ]; then
            print_success "Trivy Operator is running (${replicas}/${desired})"
        else
            print_error "Trivy Operator is not ready (${replicas}/${desired})"
            return 1
        fi
    else
        print_error "Trivy Operator deployment not found"
        return 1
    fi
    
    # Check vulnerability reports
    local reports=$(kubectl get vulnerabilityreports -A --no-headers 2>/dev/null | wc -l)
    print_status "Trivy has generated ${reports} vulnerability reports"
}

# Function to check Velero
check_velero() {
    print_status "Checking Velero..."
    
    if kubectl get deployment velero -n velero &> /dev/null; then
        local replicas=$(kubectl get deployment velero -n velero -o jsonpath='{.status.readyReplicas}')
        local desired=$(kubectl get deployment velero -n velero -o jsonpath='{.spec.replicas}')
        
        if [ "$replicas" -eq "$desired" ]; then
            print_success "Velero is running (${replicas}/${desired})"
        else
            print_error "Velero is not ready (${replicas}/${desired})"
            return 1
        fi
    else
        print_error "Velero deployment not found"
        return 1
    fi
    
    # Check backup location
    if command -v velero &>/dev/null && velero backup-location get &> /dev/null; then
        print_success "Velero backup location is configured"
    else
        print_warning "Velero backup location not configured or Velero CLI not available"
    fi
}

# Function to check applications
check_applications() {
    print_status "Checking applications..."
    
    local apps=("flask-app" "user-service" "product-service")
    
    for app in "${apps[@]}"; do
        # Check in dev namespace
        if kubectl get deployment ${app} -n dev &> /dev/null; then
            local replicas=$(kubectl get deployment ${app} -n dev -o jsonpath='{.status.readyReplicas}')
            local desired=$(kubectl get deployment ${app} -n dev -o jsonpath='{.spec.replicas}')
            
            if [ "$replicas" -eq "$desired" ]; then
                print_success "${app} is running in dev (${replicas}/${desired})"
            else
                print_warning "${app} is not ready in dev (${replicas}/${desired})"
            fi
        else
            print_warning "${app} deployment not found in dev"
        fi
    done
}

# Function to check ingress
check_ingress() {
    print_status "Checking ingress..."
    
    # Check NGINX ingress controller
    if kubectl get deployment ingress-nginx-controller -n ingress-nginx &> /dev/null; then
        local replicas=$(kubectl get deployment ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.readyReplicas}')
        local desired=$(kubectl get deployment ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.replicas}')
        
        if [ "$replicas" -eq "$desired" ]; then
            print_success "NGINX Ingress Controller is running (${replicas}/${desired})"
        else
            print_error "NGINX Ingress Controller is not ready (${replicas}/${desired})"
            return 1
        fi
    else
        print_error "NGINX Ingress Controller deployment not found"
        return 1
    fi
    
    # Check ingress resources
    local ingresses=$(kubectl get ingress -A --no-headers 2>/dev/null | wc -l)
    print_status "Found ${ingresses} ingress resources"
}

# Function to check services
check_services() {
    print_status "Checking services..."
    
    local total_services=0
    local cluster_ip_services=0
    local load_balancer_services=0
    
    for namespace in "${NAMESPACES[@]}"; do
        if kubectl get namespace ${namespace} &> /dev/null; then
            local services=$(kubectl get services -n ${namespace} --no-headers 2>/dev/null | wc -l)
            total_services=$((total_services + services))
            
            local cluster_ip=$(kubectl get services -n ${namespace} --no-headers 2>/dev/null | grep ClusterIP | wc -l)
            cluster_ip_services=$((cluster_ip_services + cluster_ip))
            
            local load_balancer=$(kubectl get services -n ${namespace} --no-headers 2>/dev/null | grep LoadBalancer | wc -l)
            load_balancer_services=$((load_balancer_services + load_balancer))
        fi
    done
    
    print_status "Total services: ${total_services}"
    print_status "ClusterIP services: ${cluster_ip_services}"
    print_status "LoadBalancer services: ${load_balancer_services}"
}

# Function to generate health report
generate_health_report() {
    print_status "Generating health report..."
    
    local report_file="health-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "DevOps Pipeline Health Report"
        echo "Generated: $(date)"
        echo "================================"
        echo ""
        
        echo "Cluster Status:"
        kubectl cluster-info
        echo ""
        
        echo "Node Status:"
        kubectl get nodes
        echo ""
        
        echo "Namespace Status:"
        kubectl get namespaces
        echo ""
        
        echo "Pod Status:"
        kubectl get pods -A
        echo ""
        
        echo "Service Status:"
        kubectl get services -A
        echo ""
        
        echo "Ingress Status:"
        kubectl get ingress -A
        echo ""
        
        echo "ArgoCD Applications:"
        kubectl get applications -n argocd
        echo ""
        
        echo "Velero Backups:"
        velero backup get 2>/dev/null || echo "No backups found"
        echo ""
        
        echo "Trivy Vulnerability Reports:"
        kubectl get vulnerabilityreports -A 2>/dev/null || echo "No vulnerability reports found"
        
    } > ${report_file}
    
    print_success "Health report generated: ${report_file}"
}

# Main function
main() {
    print_status "Starting comprehensive health check..."
    
    local exit_code=0
    
    # Check required commands
    print_status "Checking required commands..."
    check_command kubectl || exit_code=1
    check_command kind || exit_code=1
    check_command helm || exit_code=1
    check_command argocd || exit_code=1
    check_command trivy || exit_code=1
    check_command velero || exit_code=1
    
    # Check cluster
    check_cluster || exit_code=1
    
    # Check namespaces
    print_status "Checking namespaces..."
    for namespace in "${NAMESPACES[@]}"; do
        check_namespace ${namespace} || exit_code=1
    done
    
    # Check components
    check_argocd || exit_code=1
    check_gitea || exit_code=1
    check_minio || exit_code=1
    check_trivy || exit_code=1
    check_velero || exit_code=1
    check_applications || exit_code=1
    check_ingress || exit_code=1
    check_services || exit_code=1
    
    # Generate health report
    generate_health_report
    
    if [ $exit_code -eq 0 ]; then
        print_success "All health checks passed! 🎉"
    else
        print_error "Some health checks failed. Please review the output above."
    fi
    
    return $exit_code
}

# Run main function
main
