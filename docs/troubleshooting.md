# Troubleshooting Guide

This guide helps you diagnose and resolve common issues with the DevOps Pipeline.

## Quick Diagnostics

### Health Check
```bash
# Run comprehensive health check
./check_env.sh

# Check specific components
kubectl get pods -A
kubectl get applications -n argocd
kubectl get ingress -A
```

### Common Commands
```bash
# Check cluster status
kubectl cluster-info

# Check node status
kubectl get nodes

# Check all resources
kubectl get all -A
```

## Installation Issues

### Prerequisites Installation Fails

#### Docker Installation Issues
```bash
# Check Docker daemon
sudo systemctl status docker

# Restart Docker
sudo systemctl restart docker

# Check Docker group
groups $USER

# Add user to docker group
sudo usermod -aG docker $USER
# Log out and log back in
```

#### Kind Cluster Creation Fails
```bash
# Check if Docker is running
sudo systemctl status docker

# Check available memory
free -h

# Check disk space
df -h

# Delete existing cluster
kind delete cluster --name devops-pipeline

# Recreate cluster
kind create cluster --name devops-pipeline
```

#### Helm Installation Issues
```bash
# Check Helm version
helm version

# Update Helm repositories
helm repo update

# Check repository list
helm repo list
```

### Bootstrap Issues

#### ArgoCD Installation Fails
```bash
# Check ArgoCD namespace
kubectl get namespace argocd

# Check ArgoCD pods
kubectl get pods -n argocd

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-server

# Restart ArgoCD
kubectl rollout restart deployment/argocd-server -n argocd
```

#### Gitea Installation Fails
```bash
# Check Gitea namespace
kubectl get namespace gitea

# Check Gitea pods
kubectl get pods -n gitea

# Check Gitea logs
kubectl logs -n gitea deployment/gitea

# Check Gitea persistent volume
kubectl get pv
kubectl get pvc -n gitea
```

#### MinIO Installation Fails
```bash
# Check MinIO namespace
kubectl get namespace minio

# Check MinIO pods
kubectl get pods -n minio

# Check MinIO logs
kubectl logs -n minio deployment/minio

# Check MinIO persistent volume
kubectl get pvc -n minio
```

## Application Issues

### Pod Startup Issues

#### Pod Stuck in Pending
```bash
# Check pod status
kubectl get pods -n dev

# Check pod events
kubectl describe pod -n dev <pod-name>

# Check node resources
kubectl describe nodes

# Check persistent volume claims
kubectl get pvc -n dev
```

#### Pod CrashLoopBackOff
```bash
# Check pod logs
kubectl logs -n dev <pod-name>

# Check previous logs
kubectl logs -n dev <pod-name> --previous

# Check pod events
kubectl describe pod -n dev <pod-name>

# Check resource limits
kubectl describe pod -n dev <pod-name> | grep -A 5 "Limits:"
```

#### Image Pull Errors
```bash
# Check image availability
docker images | grep flask-app

# Check image tags
kubectl get pods -n dev -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}'

# Load image into cluster
kind load docker-image flask-app:latest --name devops-pipeline
```

### Service Issues

#### Service Not Accessible
```bash
# Check service status
kubectl get services -n dev

# Check service endpoints
kubectl get endpoints -n dev

# Check service selector
kubectl describe service -n dev <service-name>

# Check pod labels
kubectl get pods -n dev --show-labels
```

#### Ingress Issues
```bash
# Check ingress status
kubectl get ingress -n dev

# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Check ingress events
kubectl describe ingress -n dev <ingress-name>
```

## ArgoCD Issues

### Application Sync Issues

#### Application Out of Sync
```bash
# Check application status
kubectl get applications -n argocd

# Check application details
argocd app get devops-pipeline-dev

# Force sync application
argocd app sync devops-pipeline-dev --force

# Check application logs
kubectl logs -n argocd deployment/argocd-server
```

#### Application Failed
```bash
# Check application events
kubectl describe application -n argocd devops-pipeline-dev

# Check application logs
kubectl logs -n argocd deployment/argocd-server

# Check application resources
kubectl get all -n dev

# Restart ArgoCD
kubectl rollout restart deployment/argocd-server -n argocd
```

#### Repository Access Issues
```bash
# Check repository configuration
argocd repo list

# Test repository access
argocd repo get https://github.com/your-org/devops-pipeline

# Check repository credentials
kubectl get secret -n argocd
```

### ArgoCD UI Issues

#### Cannot Access ArgoCD UI
```bash
# Check ArgoCD service
kubectl get service -n argocd argocd-server

# Check ArgoCD ingress
kubectl get ingress -n argocd

# Port forward to ArgoCD
kubectl port-forward -n argocd service/argocd-server 8080:443

# Get ArgoCD password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Security Issues

### Trivy Operator Issues

#### Vulnerability Reports Not Generated
```bash
# Check Trivy Operator status
kubectl get pods -n trivy-system

# Check Trivy Operator logs
kubectl logs -n trivy-system deployment/trivy-operator

# Check vulnerability reports
kubectl get vulnerabilityreports -A

# Check Trivy Operator configuration
kubectl get configmap -n trivy-system
```

#### Security Scan Failures
```bash
# Check Trivy CLI installation
trivy --version

# Test Trivy scan
trivy image --severity HIGH,CRITICAL flask-app:latest

# Check Trivy database
trivy image --download-db-only

# Update Trivy database
trivy image --update-db
```

### RBAC Issues

#### Permission Denied Errors
```bash
# Check service account
kubectl get serviceaccount -n dev

# Check role binding
kubectl get rolebinding -n dev

# Check cluster role binding
kubectl get clusterrolebinding

# Check user permissions
kubectl auth can-i get pods --as=system:serviceaccount:dev:default
```

## Backup and Recovery Issues

### Velero Issues

#### Backup Failures
```bash
# Check Velero status
kubectl get pods -n velero

# Check Velero logs
kubectl logs -n velero deployment/velero

# Check backup status
velero backup get

# Check backup details
velero backup describe <backup-name>
```

#### Restore Failures
```bash
# Check restore status
velero restore get

# Check restore details
velero restore describe <restore-name>

# Check restore logs
velero restore logs <restore-name>
```

#### MinIO Connection Issues
```bash
# Check MinIO status
kubectl get pods -n minio

# Check MinIO logs
kubectl logs -n minio deployment/minio

# Test MinIO connection
kubectl exec -n minio deployment/minio -- mc ls local/

# Check MinIO credentials
kubectl get secret -n minio
```

## Network Issues

### DNS Resolution Issues
```bash
# Check DNS configuration
kubectl get configmap -n kube-system coredns

# Check DNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default
```

### Service Discovery Issues
```bash
# Check service discovery
kubectl get endpoints -A

# Check service mesh (if applicable)
kubectl get pods -n istio-system

# Check network policies
kubectl get networkpolicies -A
```

## Performance Issues

### Resource Constraints

#### High CPU Usage
```bash
# Check CPU usage
kubectl top pods -A --sort-by=cpu

# Check node CPU usage
kubectl top nodes

# Check resource limits
kubectl describe pods -A | grep -A 5 "Limits:"
```

#### High Memory Usage
```bash
# Check memory usage
kubectl top pods -A --sort-by=memory

# Check node memory usage
kubectl top nodes

# Check memory limits
kubectl describe pods -A | grep -A 5 "Limits:"
```

#### Storage Issues
```bash
# Check storage usage
kubectl get pv
kubectl get pvc -A

# Check disk space
df -h

# Check storage classes
kubectl get storageclass
```

### Slow Performance

#### Slow Pod Startup
```bash
# Check pod startup time
kubectl get pods -n dev -o wide

# Check image pull time
kubectl describe pod -n dev <pod-name> | grep -A 5 "Events:"

# Check resource allocation
kubectl describe nodes
```

#### Slow Application Response
```bash
# Check application logs
kubectl logs -n dev deployment/flask-app

# Check service endpoints
kubectl get endpoints -n dev

# Check ingress performance
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

## Debugging Techniques

### Log Analysis

#### Application Logs
```bash
# Follow logs in real-time
kubectl logs -f -n dev deployment/flask-app

# Get logs from specific container
kubectl logs -n dev deployment/flask-app -c flask-app

# Get logs from previous container
kubectl logs -n dev deployment/flask-app --previous
```

#### System Logs
```bash
# Check system logs
sudo journalctl -u docker
sudo journalctl -u kubelet

# Check audit logs
sudo tail -f /var/log/audit/audit.log
```

### Resource Inspection

#### Pod Inspection
```bash
# Describe pod
kubectl describe pod -n dev <pod-name>

# Get pod YAML
kubectl get pod -n dev <pod-name> -o yaml

# Execute into pod
kubectl exec -it -n dev <pod-name> -- /bin/bash
```

#### Service Inspection
```bash
# Describe service
kubectl describe service -n dev <service-name>

# Get service YAML
kubectl get service -n dev <service-name> -o yaml

# Test service connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- <service-name>:<port>
```

### Network Debugging

#### Network Connectivity
```bash
# Test pod-to-pod connectivity
kubectl exec -it -n dev <pod-name> -- ping <other-pod-ip>

# Test service connectivity
kubectl exec -it -n dev <pod-name> -- curl <service-name>:<port>

# Check network policies
kubectl get networkpolicies -A
```

## Recovery Procedures

### Application Recovery

#### Restart Application
```bash
# Restart deployment
kubectl rollout restart deployment/flask-app -n dev

# Check rollout status
kubectl rollout status deployment/flask-app -n dev

# Rollback deployment
kubectl rollout undo deployment/flask-app -n dev
```

#### Scale Application
```bash
# Scale up deployment
kubectl scale deployment flask-app --replicas=3 -n dev

# Check scaling status
kubectl get pods -n dev

# Scale down deployment
kubectl scale deployment flask-app --replicas=1 -n dev
```

### Infrastructure Recovery

#### Restart Infrastructure Components
```bash
# Restart ArgoCD
kubectl rollout restart deployment/argocd-server -n argocd

# Restart Gitea
kubectl rollout restart deployment/gitea -n gitea

# Restart MinIO
kubectl rollout restart deployment/minio -n minio
```

#### Recreate Resources
```bash
# Delete and recreate pod
kubectl delete pod -n dev <pod-name>
kubectl get pods -n dev

# Delete and recreate service
kubectl delete service -n dev <service-name>
kubectl apply -f <service-manifest>
```

## Prevention Strategies

### Monitoring Setup

#### Health Monitoring
```bash
# Set up health checks
kubectl get pods -A --field-selector=status.phase=Running

# Monitor resource usage
kubectl top pods -A

# Check application health
curl http://flask-app.local/api/health
```

#### Alerting Setup
```bash
# Check for failed pods
kubectl get pods -A --field-selector=status.phase=Failed

# Check for pending pods
kubectl get pods -A --field-selector=status.phase=Pending

# Check for crash loop backoff
kubectl get pods -A | grep CrashLoopBackOff
```

### Maintenance Procedures

#### Regular Maintenance
```bash
# Update system packages
sudo apt-get update && sudo apt-get upgrade -y

# Clean up Docker images
docker system prune -a

# Clean up Kubernetes resources
kubectl delete pods --field-selector=status.phase=Succeeded
kubectl delete pods --field-selector=status.phase=Failed
```

#### Backup Procedures
```bash
# Create backup
velero backup create daily-backup --include-namespaces dev,staging,production

# Check backup status
velero backup get

# Test restore
velero restore create test-restore --from-backup daily-backup
```

## Frequently Asked Questions

### Q: Why is my pod stuck in Pending?
A: Check node resources, persistent volume claims, and node selectors.

### Q: Why is my application not accessible?
A: Check service endpoints, ingress configuration, and network policies.

### Q: Why is ArgoCD not syncing?
A: Check repository access, application configuration, and ArgoCD logs.

### Q: Why are security scans failing?
A: Check Trivy installation, database updates, and image availability.

### Q: Why is backup failing?
A: Check Velero status, MinIO connection, and backup configuration.

## Getting Help

### Documentation
- [Architecture Overview](architecture.md)
- [Security Guide](security.md)
- [Monitoring Guide](monitoring.md)
- [Runbooks](runbooks/)

### Community Support
- [GitHub Issues](https://github.com/your-org/devops-pipeline/issues)
- [GitHub Discussions](https://github.com/your-org/devops-pipeline/discussions)

### Professional Support
- Contact your DevOps team
- Escalate to platform engineering
- Consider professional consulting services
