#!/bin/bash

# reset_and_setup.sh - Complete reset and setup with all fixes

set +e

echo "=========================================="
echo "🔄 Complete Reset and Setup"
echo "=========================================="
echo ""
echo "This will:"
echo "  1. Delete existing cluster"
echo "  2. Recreate with all ports mapped"
echo "  3. Install all infrastructure"
echo "  4. Deploy applications"
echo "  5. Verify everything"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Step 1: Delete existing cluster
print_status "Deleting existing cluster..."
kind delete cluster --name devops-pipeline
docker system prune -f
sleep 5
print_success "Cluster deleted"

# Step 2: Run bootstrap (will create cluster with all ports)
print_status "Running bootstrap with fixed configuration..."
./bootstrap_cluster.sh
if [ $? -ne 0 ]; then
    echo "❌ Bootstrap failed!"
    exit 1
fi

# Step 3: Deploy applications
print_status "Deploying applications..."
./deploy_pipeline.sh
if [ $? -ne 0 ]; then
    echo "❌ Deployment failed!"
    exit 1
fi

# Step 4: Verify
print_status "Verifying setup..."
./check_env.sh

print_success "Complete setup finished!"
echo ""
echo "=========================================="
echo "✅ All Done!"
echo "=========================================="
echo ""
echo "Your DevOps pipeline is ready!"
echo ""
echo "Next: Open ports 30080-30085 and 30500 in AWS Security Group"
echo ""
