# Quick Start Guide

Get your DevOps Pipeline up and running in minutes with this quick start guide.

## Prerequisites

- Ubuntu 20.04+ or Debian 11+
- Sudo privileges
- Internet connectivity
- At least 4GB RAM and 20GB disk space

## One-Command Setup

```bash
# Clone the repository
git clone https://github.com/your-org/devops-pipeline.git
cd devops-pipeline

# Run the complete setup
chmod +x setup_prereqs.sh bootstrap_cluster.sh deploy_pipeline.sh check_env.sh
./setup_prereqs.sh && ./bootstrap_cluster.sh && ./deploy_pipeline.sh && ./check_env.sh
```

## What Gets Installed

### Infrastructure Components
- **Kubernetes Cluster**: kind-based cluster with 3 nodes
- **NGINX Ingress**: Traffic routing and load balancing
- **Gitea**: Self-hosted Git server
- **ArgoCD**: GitOps continuous deployment
- **MinIO**: S3-compatible object storage
- **Trivy Operator**: Container security scanning
- **Velero**: Backup and disaster recovery

### Applications
- **Flask Web App**: Modern Python web application
- **User Service**: REST API for user management
- **Product Service**: REST API for product management

## Access Your Applications

After successful installation, access your applications:

| Service | URL | Credentials |
|---------|-----|-------------|
| Flask App | http://flask-app.local | - |
| Gitea | http://gitea.local | admin/admin123 |
| MinIO | http://minio.local | minioadmin/minioadmin123 |
| ArgoCD | http://argocd.local | admin/[see below] |

### Get ArgoCD Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Verify Installation

Run the health check to ensure everything is working:

```bash
./check_env.sh
```

Expected output:
```
✅ All health checks passed! 🎉
```

## Test the Pipeline

### 1. Blue-Green Deployment Demo

```bash
./switch_blue_green.sh demo
```

### 2. Backup and Restore Demo

```bash
./backup_restore_demo.sh demo
```

### 3. Security Scan Demo

```bash
# Scan Flask app
trivy image --severity HIGH,CRITICAL flask-app:latest

# Scan User service
trivy image --severity HIGH,CRITICAL user-service:latest

# Scan Product service
trivy image --severity HIGH,CRITICAL product-service:latest
```

## Next Steps

1. **Explore the Architecture**: Read [Architecture Overview](architecture.md)
2. **Review Runbooks**: Check operational procedures in [Runbooks](runbooks/)
3. **Customize Configuration**: Modify environment-specific settings
4. **Add Your Applications**: Follow the guide to add new services

## Troubleshooting

If you encounter issues:

1. **Check Logs**: Use `kubectl logs` to investigate
2. **Restart Services**: Use `kubectl rollout restart`
3. **Reset Cluster**: Run `kind delete cluster --name devops-pipeline`
4. **Review Documentation**: Check [Troubleshooting Guide](troubleshooting.md)

## Production Considerations

For production deployment:

1. **Replace MinIO** with cloud storage (AWS S3, GCS)
2. **Use external secrets management** (AWS Secrets Manager, HashiCorp Vault)
3. **Enable TLS** for all services
4. **Configure monitoring** (Prometheus, Grafana)
5. **Set up log aggregation** (ELK stack, Fluentd)

## Support

- **Documentation**: This site
- **Issues**: [GitHub Issues](https://github.com/your-org/devops-pipeline/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/devops-pipeline/discussions)
