# Installation Runbook

This runbook provides step-by-step instructions for installing and setting up the DevOps Pipeline on a clean Ubuntu/Debian system.

## Prerequisites

- Ubuntu 20.04+ or Debian 11+
- Sudo privileges
- Internet connectivity
- At least 4GB RAM and 20GB disk space

## Installation Steps

### 1. System Preparation

```bash
# Update system packages
sudo apt-get update -y
sudo apt-get upgrade -y

# Install basic dependencies
sudo apt-get install -y curl wget git unzip jq python3 python3-pip
```

### 2. Run Prerequisites Script

```bash
# Make script executable
chmod +x setup_prereqs.sh

# Run prerequisites installation
./setup_prereqs.sh
```

This script installs:
- Docker and Docker Compose
- kubectl
- kind (Kubernetes in Docker)
- Helm
- ArgoCD CLI
- Trivy
- Velero
- Kustomize
- MkDocs

### 3. Bootstrap Kubernetes Cluster

```bash
# Make script executable
chmod +x bootstrap_cluster.sh

# Bootstrap the cluster
./bootstrap_cluster.sh
```

This script:
- Creates a kind Kubernetes cluster
- Installs NGINX Ingress Controller
- Deploys Gitea
- Installs ArgoCD
- Sets up MinIO
- Installs Trivy Operator
- Configures Velero
- Creates ArgoCD applications

### 4. Deploy Applications

```bash
# Make script executable
chmod +x deploy_pipeline.sh

# Deploy the pipeline
./deploy_pipeline.sh
```

This script:
- Builds Docker images for all applications
- Loads images into the cluster
- Updates Kubernetes manifests
- Applies ArgoCD configurations
- Creates ingress resources
- Runs security scans

### 5. Verify Installation

```bash
# Make script executable
chmod +x check_env.sh

# Run health checks
./check_env.sh
```

## Post-Installation Configuration

### Access URLs

After successful installation, you can access:

- **Flask App**: http://flask-app.local
- **Gitea**: http://gitea.local (admin/admin123)
- **MinIO**: http://minio.local (minioadmin/minioadmin123)
- **ArgoCD**: http://argocd.local (admin/[password])

### Get ArgoCD Password

```bash
# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Configure Git Repository

1. Access Gitea at http://gitea.local
2. Login with admin/admin123
3. Create a new repository for your applications
4. Update ArgoCD applications to point to your repository

## Troubleshooting

### Common Issues

#### Docker Permission Denied
```bash
# Add user to docker group
sudo usermod -aG docker $USER
# Log out and log back in
```

#### Kind Cluster Creation Fails
```bash
# Check if Docker is running
sudo systemctl status docker
# Restart Docker if needed
sudo systemctl restart docker
```

#### ArgoCD Sync Issues
```bash
# Check ArgoCD application status
kubectl get applications -n argocd
# Check application logs
kubectl logs -n argocd deployment/argocd-server
```

#### Ingress Not Working
```bash
# Check ingress controller
kubectl get pods -n ingress-nginx
# Check ingress resources
kubectl get ingress -A
```

### Log Locations

- **ArgoCD**: `kubectl logs -n argocd deployment/argocd-server`
- **Gitea**: `kubectl logs -n gitea deployment/gitea`
- **MinIO**: `kubectl logs -n minio deployment/minio`
- **Trivy Operator**: `kubectl logs -n trivy-system deployment/trivy-operator`
- **Velero**: `kubectl logs -n velero deployment/velero`

### Reset Installation

If you need to start over:

```bash
# Delete kind cluster
kind delete cluster --name devops-pipeline

# Remove Docker images
docker system prune -a

# Run bootstrap again
./bootstrap_cluster.sh
```

## Security Considerations

### Production Deployment

For production deployment, consider:

1. **Replace MinIO** with cloud storage (AWS S3, GCS)
2. **Use external secrets management** (AWS Secrets Manager, HashiCorp Vault)
3. **Enable TLS** for all services
4. **Configure network policies** for pod-to-pod communication
5. **Set up monitoring** (Prometheus, Grafana)
6. **Implement log aggregation** (ELK stack, Fluentd)

### Secrets Management

```bash
# Create production secrets
kubectl create secret generic prod-secrets \
  --from-literal=secret-key=your-production-secret-key \
  --namespace=production

# Update applications to use production secrets
kubectl patch deployment flask-app -n production -p '{"spec":{"template":{"spec":{"containers":[{"name":"flask-app","env":[{"name":"SECRET_KEY","valueFrom":{"secretKeyRef":{"name":"prod-secrets","key":"secret-key"}}}]}]}}}}'
```

## Next Steps

After successful installation:

1. **Review the Architecture**: Read [Architecture Overview](architecture.md)
2. **Explore Runbooks**: Check other runbooks for operational procedures
3. **Test Blue-Green Deployment**: Run `./switch_blue_green.sh demo`
4. **Test Backup/Restore**: Run `./backup_restore_demo.sh demo`
5. **Monitor Health**: Use `./check_env.sh` regularly

## Support

If you encounter issues:

1. Check the [Troubleshooting Guide](troubleshooting.md)
2. Review logs using the commands above
3. Create an issue in the GitHub repository
4. Check the [FAQ](troubleshooting.md#frequently-asked-questions)
