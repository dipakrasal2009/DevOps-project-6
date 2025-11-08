# GitOps Sync Runbook

This runbook covers GitOps synchronization procedures using ArgoCD.

## GitOps Overview

GitOps is a methodology that uses Git as the single source of truth for declarative infrastructure and applications. ArgoCD continuously monitors Git repositories and automatically syncs applications to match the desired state.

## ArgoCD Configuration

### Project Setup
```yaml
# argocd/project.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: devops-pipeline-project
  namespace: argocd
spec:
  description: DevOps Pipeline Project
  sourceRepos:
  - '*'
  destinations:
  - namespace: '*'
    server: https://kubernetes.default.svc
  roles:
  - name: admin
    description: Admin role
    policies:
    - p, proj:devops-pipeline-project:admin, applications, *, devops-pipeline-project/*, allow
    groups:
    - argocd-admins
  - name: developer
    description: Developer role
    policies:
    - p, proj:devops-pipeline-project:developer, applications, get, devops-pipeline-project/*, allow
    - p, proj:devops-pipeline-project:developer, applications, sync, devops-pipeline-project/dev-*, allow
    groups:
    - argocd-developers
```

### Application Configuration
```yaml
# argocd/argocd-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: devops-pipeline-dev
  namespace: argocd
spec:
  project: devops-pipeline-project
  source:
    repoURL: https://github.com/your-org/devops-pipeline
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
    - PrunePropagationPolicy=foreground
    - PruneLast=true
```

## Sync Procedures

### Manual Sync

#### Sync Single Application
```bash
# Sync development environment
argocd app sync devops-pipeline-dev

# Sync staging environment
argocd app sync devops-pipeline-staging

# Sync production environment
argocd app sync devops-pipeline-prod
```

#### Force Sync
```bash
# Force sync with conflict resolution
argocd app sync devops-pipeline-dev --force

# Force sync with prune
argocd app sync devops-pipeline-dev --force --prune
```

#### Sync Specific Resources
```bash
# Sync only deployments
argocd app sync devops-pipeline-dev --resource deployments

# Sync specific deployment
argocd app sync devops-pipeline-dev --resource deployments:flask-app
```

### Automated Sync

#### Enable Automated Sync
```bash
# Enable automated sync for development
kubectl patch application devops-pipeline-dev -n argocd --type merge --patch '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'

# Enable automated sync for staging
kubectl patch application devops-pipeline-staging -n argocd --type merge --patch '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":false}}}}'
```

#### Disable Automated Sync
```bash
# Disable automated sync
kubectl patch application devops-pipeline-dev -n argocd --type merge --patch '{"spec":{"syncPolicy":{"automated":null}}}'
```

## Sync Monitoring

### Check Sync Status
```bash
# Check application status
kubectl get applications -n argocd

# Get detailed application status
argocd app get devops-pipeline-dev

# Check sync history
argocd app history devops-pipeline-dev
```

### Monitor Sync Progress
```bash
# Watch application status
kubectl get applications -n argocd -w

# Check application events
kubectl describe application devops-pipeline-dev -n argocd

# Check application logs
kubectl logs -n argocd deployment/argocd-server
```

## Sync Troubleshooting

### Common Sync Issues

#### Application Out of Sync
```bash
# Check application status
argocd app get devops-pipeline-dev

# Check sync status
argocd app sync devops-pipeline-dev --dry-run

# Force sync
argocd app sync devops-pipeline-dev --force
```

#### Sync Failures
```bash
# Check application events
kubectl describe application devops-pipeline-dev -n argocd

# Check application logs
kubectl logs -n argocd deployment/argocd-server

# Check resource status
kubectl get all -n dev
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

### Sync Recovery Procedures

#### Reset Application
```bash
# Reset application to desired state
argocd app rollback devops-pipeline-dev

# Hard reset application
argocd app delete devops-pipeline-dev --cascade
kubectl apply -f argocd/argocd-apps.yaml
```

#### Recreate Application
```bash
# Delete application
kubectl delete application devops-pipeline-dev -n argocd

# Recreate application
kubectl apply -f argocd/argocd-apps.yaml
```

## Sync Best Practices

### Repository Management

#### Branch Strategy
- **main**: Production-ready code
- **develop**: Integration branch
- **feature/***: Feature development
- **hotfix/***: Critical fixes

#### Commit Strategy
```bash
# Feature development
git checkout -b feature/new-feature
git add .
git commit -m "feat: add new feature"
git push origin feature/new-feature

# Integration
git checkout develop
git merge feature/new-feature
git push origin develop

# Production release
git checkout main
git merge develop
git tag v1.0.0
git push origin main --tags
```

### Manifest Management

#### Kustomize Structure
```
environments/
├── base/
│   ├── kustomization.yaml
│   └── resources/
├── dev/
│   ├── kustomization.yaml
│   └── patches/
├── staging/
│   ├── kustomization.yaml
│   └── patches/
└── prod/
    ├── kustomization.yaml
    └── patches/
```

#### Environment-Specific Configurations
```yaml
# environments/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../base

namespace: dev

patchesStrategicMerge:
- |-
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: flask-app
  spec:
    replicas: 1
    template:
      spec:
        containers:
        - name: flask-app
          resources:
            requests:
              memory: "64Mi"
              cpu: "50m"
            limits:
              memory: "128Mi"
              cpu: "100m"
```

### Sync Policies

#### Development Environment
- **Automated Sync**: Enabled
- **Self Heal**: Enabled
- **Prune**: Enabled
- **Sync Options**: CreateNamespace=true

#### Staging Environment
- **Automated Sync**: Enabled
- **Self Heal**: Disabled
- **Prune**: Enabled
- **Sync Options**: CreateNamespace=true

#### Production Environment
- **Automated Sync**: Disabled
- **Self Heal**: Disabled
- **Prune**: Disabled
- **Sync Options**: CreateNamespace=true

## Sync Automation

### CI/CD Integration

#### GitHub Actions
```yaml
# .github/workflows/ci-cd.yml
name: GitOps Sync

on:
  push:
    branches: [ main, develop ]

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Set up ArgoCD CLI
      run: |
        curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    
    - name: Sync application
      run: |
        if [ "${{ github.ref }}" = "refs/heads/develop" ]; then
          argocd app sync devops-pipeline-dev --server ${{ secrets.ARGOCD_SERVER }} --auth-token ${{ secrets.ARGOCD_TOKEN }}
        elif [ "${{ github.ref }}" = "refs/heads/main" ]; then
          argocd app sync devops-pipeline-staging --server ${{ secrets.ARGOCD_SERVER }} --auth-token ${{ secrets.ARGOCD_TOKEN }}
        fi
```

#### Webhook Integration
```yaml
# ArgoCD webhook configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  server.insecure: "true"
  server.enable.grpc.web: "true"
  server.enable.grpc.web.rootpath: "/"
```

### Sync Triggers

#### Manual Triggers
```bash
# Trigger sync via CLI
argocd app sync devops-pipeline-dev

# Trigger sync via API
curl -X POST "https://argocd.local/api/v1/applications/devops-pipeline-dev/sync" \
  -H "Authorization: Bearer $ARGOCD_TOKEN"
```

#### Automated Triggers
```bash
# Webhook trigger
curl -X POST "https://argocd.local/api/webhook" \
  -H "Content-Type: application/json" \
  -d '{"repository":{"url":"https://github.com/your-org/devops-pipeline"}}'
```

## Sync Monitoring and Alerting

### Health Monitoring
```bash
# Check application health
argocd app get devops-pipeline-dev --health

# Check sync status
argocd app get devops-pipeline-dev --sync

# Check resource status
kubectl get all -n dev
```

### Alerting Configuration
```yaml
# Prometheus alerting rules
groups:
- name: argocd
  rules:
  - alert: ArgoCDApplicationOutOfSync
    expr: argocd_app_info{sync_status!="Synced"} == 1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "ArgoCD application {{ $labels.name }} is out of sync"
      description: "Application {{ $labels.name }} has been out of sync for more than 5 minutes"
```

## Sync Security

### Access Control
```yaml
# RBAC configuration
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: argocd-developer
rules:
- apiGroups: [""]
  resources: ["applications"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["applications"]
  verbs: ["sync"]
  resourceNames: ["devops-pipeline-dev"]
```

### Secret Management
```bash
# Create repository secret
kubectl create secret generic repo-secret \
  --from-literal=username=git \
  --from-literal=password=token \
  --namespace=argocd

# Create ArgoCD secret
kubectl create secret generic argocd-secret \
  --from-literal=admin.password=admin123 \
  --namespace=argocd
```

## Sync Performance

### Optimization Techniques

#### Resource Filtering
```yaml
# Filter resources during sync
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: devops-pipeline-dev
spec:
  source:
    path: environments/dev
  syncPolicy:
    syncOptions:
    - PrunePropagationPolicy=foreground
    - PruneLast=true
    - CreateNamespace=true
```

#### Sync Options
```yaml
# Optimize sync performance
syncOptions:
- PrunePropagationPolicy=foreground
- PruneLast=true
- CreateNamespace=true
- RespectIgnoreDifferences=true
- ApplyOutOfSyncOnly=true
```

### Performance Monitoring
```bash
# Monitor sync performance
kubectl get applications -n argocd -o custom-columns="NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status"

# Check sync duration
argocd app get devops-pipeline-dev --sync
```

## Next Steps

1. **Review Architecture**: Understand the [Architecture Overview](architecture.md)
2. **CI/CD Pipeline**: Check [CI/CD Pipeline Runbook](cicd-pipeline.md)
3. **Blue-Green Deployment**: Review [Blue-Green Switch Runbook](blue-green-switch.md)
4. **Disaster Recovery**: Check [DR Restore Runbook](dr-restore.md)
5. **Monitoring**: Review [Monitoring Guide](monitoring.md)
6. **Troubleshooting**: Refer to [Troubleshooting Guide](troubleshooting.md)
