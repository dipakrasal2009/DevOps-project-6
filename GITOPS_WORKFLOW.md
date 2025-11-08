# 🔄 Complete GitOps Workflow

This document explains the complete GitOps workflow implemented in this project.

## 📊 Architecture Flow

```
Developer
    ↓
Edit Code
    ↓
./deploy_pipeline.sh
    ↓
┌─────────────────────────────────────┐
│ 1. Build Docker Images              │
│    - Flask App                      │
│    - User Service                   │
│    - Product Service                │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ 2. Push to Local Registry           │
│    localhost:30500/flask-app:latest │
│    localhost:30500/user-service     │
│    localhost:30500/product-service  │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ 3. Update Deployment Manifests      │
│    - Update image tags              │
│    - Update imagePullPolicy         │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ 4. Git Commit & Push                │
│    git add .                        │
│    git commit -m "Update images"    │
│    git push gitea main              │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ 5. ArgoCD Watches Gitea             │
│    - Detects changes                │
│    - Syncs automatically            │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ 6. Kubernetes Deployment            │
│    - Pulls images from registry     │
│    - Deploys to dev namespace       │
│    - Exposes via NodePort           │
└─────────────────────────────────────┘
    ↓
Applications Running!
```

## 🔧 Components

### 1. Local Docker Registry
- **Location:** `localhost:30500`
- **Purpose:** Store Docker images locally
- **Access:** NodePort 30500
- **Usage:** `docker push localhost:30500/flask-app:latest`

### 2. Gitea (Git Server)
- **Location:** `http://localhost:30084`
- **Purpose:** Source code repository
- **Credentials:** admin / admin123
- **Repository:** `http://localhost:30084/admin/devops-pipeline`

### 3. ArgoCD (GitOps Controller)
- **Location:** `http://localhost:30083`
- **Purpose:** Automated deployment from Git
- **Watches:** Gitea repository
- **Syncs:** Automatically on code changes

### 4. Kubernetes Cluster
- **Type:** kind (Kubernetes in Docker)
- **Nodes:** 1 control-plane
- **Namespaces:** dev, staging, production

## 📝 Step-by-Step Workflow

### Initial Setup (One Time)

```bash
# 1. Install prerequisites
./setup_prereqs.sh

# 2. Bootstrap cluster (includes registry)
./bootstrap_cluster.sh

# 3. Setup Gitea and ArgoCD
./setup_gitea_repo.sh
```

### Development Workflow (Repeat)

```bash
# 1. Make code changes
vim apps/flask-app/app.py

# 2. Deploy (builds, pushes, commits, ArgoCD syncs)
./deploy_pipeline.sh

# 3. Verify deployment
./check_env.sh

# 4. Access application
curl http://localhost:30080
```

## 🔄 What Happens When You Run deploy_pipeline.sh

1. **Build Phase:**
   ```bash
   docker build -t flask-app:latest ./apps/flask-app
   docker build -t user-service:latest ./apps/microservice-1
   docker build -t product-service:latest ./apps/microservice-2
   ```

2. **Push Phase:**
   ```bash
   docker tag flask-app:latest localhost:30500/flask-app:latest
   docker push localhost:30500/flask-app:latest
   ```

3. **Update Phase:**
   ```bash
   sed -i "s|image: flask-app:latest|image: localhost:30500/flask-app:latest|g" \
     apps/flask-app/deployment.yaml
   ```

4. **Git Phase:**
   ```bash
   git add apps/*/deployment.yaml
   git commit -m "Update image tags"
   git push gitea main
   ```

5. **ArgoCD Phase:**
   - ArgoCD detects changes in Gitea
   - Automatically syncs (pulls latest manifests)
   - Applies to Kubernetes cluster
   - Kubernetes pulls images from local registry
   - Pods start with new images

## 🎯 Benefits of This Workflow

✅ **GitOps:** All changes tracked in Git  
✅ **Automated:** ArgoCD auto-deploys on Git push  
✅ **Local:** No external dependencies (GitHub, Docker Hub)  
✅ **Reproducible:** Git history = deployment history  
✅ **Rollback:** `git revert` + ArgoCD sync  
✅ **Audit:** Full Git log of all changes  

## 🔍 Monitoring the Workflow

### Check ArgoCD Application Status
```bash
kubectl get applications -n argocd
kubectl describe application devops-pipeline-dev -n argocd
```

### Check Registry Images
```bash
curl http://localhost:30500/v2/_catalog
curl http://localhost:30500/v2/flask-app/tags/list
```

### Check Gitea Repository
```bash
# Via web browser
http://localhost:30084/admin/devops-pipeline

# Via git
git remote -v
git log --oneline
```

### Check Deployed Applications
```bash
kubectl get pods -n dev
kubectl get svc -n dev
kubectl describe deployment flask-app -n dev
```

## 🚨 Troubleshooting

### ArgoCD Not Syncing?
```bash
# Check ArgoCD application
kubectl get application devops-pipeline-dev -n argocd -o yaml

# Manual sync
kubectl patch application devops-pipeline-dev -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"normal"}}}'
```

### Registry Push Failing?
```bash
# Check registry is running
kubectl get pods -n registry

# Test registry
curl http://localhost:30500/v2/
```

### Gitea Push Failing?
```bash
# Check Gitea is accessible
curl http://localhost:30084

# Check git remote
git remote -v

# Re-add remote
git remote remove gitea
git remote add gitea http://localhost:30084/admin/devops-pipeline.git
```

## 📊 Ports Summary

| Service | Port | Purpose |
|---------|------|---------|
| Flask App | 30080 | Web application |
| User Service | 30081 | User API |
| Product Service | 30082 | Product API |
| ArgoCD | 30083 | GitOps UI |
| Gitea | 30084 | Git server |
| MinIO | 30085 | S3 storage |
| **Docker Registry** | **30500** | **Image storage** |

## 🎉 Success Indicators

✅ Registry running: `curl http://localhost:30500/v2/`  
✅ Gitea accessible: `curl http://localhost:30084`  
✅ ArgoCD synced: `kubectl get app -n argocd`  
✅ Pods running: `kubectl get pods -n dev`  
✅ Apps accessible: `curl http://localhost:30080`  

## 🔄 Making Changes

```bash
# 1. Edit code
vim apps/flask-app/app.py

# 2. Deploy (automatic workflow)
./deploy_pipeline.sh

# 3. Watch ArgoCD sync
kubectl get application devops-pipeline-dev -n argocd -w

# 4. Verify pods updated
kubectl get pods -n dev

# 5. Test application
curl http://localhost:30080
```

**That's it! Complete GitOps workflow with local registry and Gitea!** 🚀
