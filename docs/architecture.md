# Architecture Overview

This document provides a comprehensive overview of the DevOps Pipeline architecture, including all components, their interactions, and deployment strategies.

## System Architecture

```mermaid
graph TB
    subgraph "Source Control"
        A[GitHub Repository]
        B[Gitea Server]
    end
    
    subgraph "CI/CD Pipeline"
        C[GitHub Actions]
        D[Docker Build]
        E[Trivy Security Scan]
        F[Image Registry]
    end
    
    subgraph "GitOps"
        G[ArgoCD]
        H[Application Manifests]
        I[Kustomize Overlays]
    end
    
    subgraph "Kubernetes Cluster"
        subgraph "Infrastructure"
            J[NGINX Ingress]
            K[MinIO S3]
            L[Trivy Operator]
            M[Velero]
        end
        
        subgraph "Applications"
            N[Flask Web App]
            O[User Service]
            P[Product Service]
        end
        
        subgraph "Environments"
            Q[Development]
            R[Staging]
            S[Production]
        end
    end
    
    subgraph "Monitoring & Security"
        T[Health Checks]
        U[Vulnerability Reports]
        V[Backup Status]
    end
    
    A --> C
    B --> C
    C --> D
    D --> E
    E --> F
    F --> G
    G --> H
    H --> I
    I --> Q
    I --> R
    I --> S
    
    Q --> N
    Q --> O
    Q --> P
    
    J --> N
    K --> M
    L --> U
    M --> V
    
    N --> T
    O --> T
    P --> T
```

## Component Details

### 1. Source Control & GitOps

#### GitHub Repository
- **Purpose**: Primary source control for application code and infrastructure
- **Structure**: Organized with apps, environments, and configuration directories
- **Branches**: `main` (production), `develop` (staging), feature branches

#### Gitea Server
- **Purpose**: Self-hosted Git server for PoC and internal repositories
- **Access**: http://gitea.local (admin/admin123)
- **Features**: Web UI, API access, webhook support

### 2. CI/CD Pipeline

#### GitHub Actions Workflow
- **Trigger**: Push to main/develop branches, pull requests
- **Stages**:
  1. Security scan with Trivy
  2. Build Docker images for all applications
  3. Push to container registry
  4. Update image tags in manifests
  5. Deploy to appropriate environment
  6. Run blue-green deployment
  7. Execute backup/restore tests
  8. Perform health checks

#### Docker Images
- **Flask App**: Python web application with Bootstrap UI
- **User Service**: REST API for user management
- **Product Service**: REST API for product management
- **Base Image**: Python 3.11-slim
- **Security**: Non-root user, health checks, resource limits

### 3. GitOps with ArgoCD

#### ArgoCD Configuration
- **Project**: `devops-pipeline-project` with RBAC
- **Applications**:
  - `devops-pipeline-dev`: Automated sync
  - `devops-pipeline-staging`: Manual sync
  - `devops-pipeline-prod`: Manual sync
  - `devops-pipeline-blue-green`: Blue-green deployments

#### Kustomize Overlays
- **Base**: Common application manifests
- **Dev**: Minimal resources, debug logging
- **Staging**: Production-like resources, info logging
- **Prod**: Full resources, warning logging, production optimizations

### 4. Kubernetes Infrastructure

#### Cluster Setup
- **Type**: kind (Kubernetes in Docker)
- **Nodes**: 1 control-plane + 2 workers
- **Ingress**: NGINX Ingress Controller
- **Storage**: Local persistent volumes

#### Namespaces
- `argocd`: ArgoCD components
- `gitea`: Gitea server
- `minio`: MinIO S3 storage
- `trivy-system`: Trivy Operator
- `velero`: Velero backup system
- `dev`: Development environment
- `staging`: Staging environment
- `production`: Production environment

### 5. Applications

#### Flask Web Application
- **Port**: 5000
- **Features**: Dashboard, user management, product management
- **Dependencies**: User Service, Product Service
- **Health Check**: `/api/health` endpoint

#### User Service
- **Port**: 5001
- **API**: RESTful CRUD operations for users
- **Data**: Mock user data with roles and permissions
- **Health Check**: `/api/health` endpoint

#### Product Service
- **Port**: 5002
- **API**: RESTful CRUD operations for products
- **Data**: Mock product data with categories and pricing
- **Health Check**: `/api/health` endpoint

### 6. Security & Monitoring

#### Trivy Integration
- **CLI**: Security scanning in CI/CD pipeline
- **Operator**: In-cluster vulnerability scanning
- **Reports**: SARIF format for GitHub Security tab
- **Severity**: HIGH and CRITICAL vulnerabilities fail builds

#### RBAC Configuration
- **ArgoCD**: Project-based access control
- **Kubernetes**: Service accounts with minimal privileges
- **Secrets**: Kubernetes secrets for sensitive data

### 7. Backup & Disaster Recovery

#### Velero Configuration
- **Provider**: AWS S3-compatible (MinIO)
- **Backup Location**: MinIO bucket `velero-backups`
- **Schedules**: Automated backups (configurable)
- **Restore**: Full namespace restore capability

#### MinIO Storage
- **Purpose**: S3-compatible object storage
- **Access**: http://minio.local (minioadmin/minioadmin123)
- **Buckets**: `velero-backups` for Velero

## Deployment Strategies

### Blue-Green Deployment

```mermaid
graph LR
    subgraph "Blue Environment"
        A[Blue Deployment]
        B[Blue Service]
    end
    
    subgraph "Green Environment"
        C[Green Deployment]
        D[Green Service]
    end
    
    subgraph "Traffic Management"
        E[Main Service]
        F[Load Balancer]
    end
    
    A --> B
    C --> D
    B --> E
    D --> E
    E --> F
    F --> G[Users]
```

#### Process:
1. Deploy new version to inactive environment
2. Wait for health checks to pass
3. Switch traffic to new environment
4. Monitor for issues
5. Clean up old environment

### Environment Promotion

```mermaid
graph TD
    A[Code Commit] --> B[CI/CD Pipeline]
    B --> C[Build & Test]
    C --> D[Security Scan]
    D --> E[Deploy to Dev]
    E --> F[Automated Tests]
    F --> G[Deploy to Staging]
    G --> H[Manual Approval]
    H --> I[Deploy to Production]
    I --> J[Blue-Green Switch]
    J --> K[Health Check]
```

## Network Architecture

### Service Communication

```mermaid
graph TB
    subgraph "External"
        A[Users]
        B[Developers]
        C[Admins]
    end
    
    subgraph "Ingress Layer"
        D[NGINX Ingress]
    end
    
    subgraph "Application Layer"
        E[Flask App]
        F[User Service]
        G[Product Service]
    end
    
    subgraph "Infrastructure Layer"
        H[Gitea]
        I[ArgoCD]
        J[MinIO]
        K[Trivy Operator]
        L[Velero]
    end
    
    A --> D
    B --> D
    C --> D
    
    D --> E
    E --> F
    E --> G
    
    B --> H
    C --> I
    L --> J
    K --> E
    K --> F
    K --> G
```

### Port Configuration

| Service | Port | Type | Purpose |
|---------|------|------|---------|
| Flask App | 5000 | HTTP | Web application |
| User Service | 5001 | HTTP | User API |
| Product Service | 5002 | HTTP | Product API |
| Gitea | 3000 | HTTP | Git server |
| ArgoCD | 8080 | HTTP | GitOps UI |
| MinIO | 9000 | HTTP | S3 storage |
| NGINX Ingress | 80/443 | HTTP/HTTPS | Traffic routing |

## Security Architecture

### Container Security

```mermaid
graph TB
    subgraph "Build Time"
        A[Source Code] --> B[Docker Build]
        B --> C[Trivy Scan]
        C --> D{Vulnerabilities?}
        D -->|Yes| E[Fail Build]
        D -->|No| F[Push Image]
    end
    
    subgraph "Runtime"
        F --> G[Deploy to Cluster]
        G --> H[Trivy Operator]
        H --> I[Scan Running Images]
        I --> J[Generate Reports]
    end
    
    subgraph "Monitoring"
        K[Security Dashboard]
        L[Alert Manager]
        M[Compliance Reports]
    end
    
    J --> K
    J --> L
    J --> M
```

### Network Security

- **Network Policies**: Restrict pod-to-pod communication
- **Ingress Security**: TLS termination and rate limiting
- **Service Mesh**: Future enhancement with Istio
- **Secrets Management**: Kubernetes secrets with encryption

## Scalability Considerations

### Horizontal Scaling

```mermaid
graph TB
    subgraph "Load Balancing"
        A[Ingress Controller]
        B[Service Load Balancer]
    end
    
    subgraph "Application Scaling"
        C[Flask App Replicas]
        D[User Service Replicas]
        E[Product Service Replicas]
    end
    
    subgraph "Infrastructure Scaling"
        F[Cluster Autoscaler]
        G[Node Groups]
    end
    
    A --> C
    B --> D
    B --> E
    
    C --> F
    D --> F
    E --> F
    F --> G
```

### Resource Management

- **Requests**: Minimum resource requirements
- **Limits**: Maximum resource usage
- **HPA**: Horizontal Pod Autoscaler (future)
- **VPA**: Vertical Pod Autoscaler (future)

## Monitoring & Observability

### Health Checks

- **Liveness Probes**: Container health monitoring
- **Readiness Probes**: Service availability
- **Startup Probes**: Application startup time

### Metrics Collection

- **Application Metrics**: Custom metrics endpoints
- **Infrastructure Metrics**: Node and pod metrics
- **Business Metrics**: User and product counts

### Logging

- **Application Logs**: Structured logging with levels
- **Infrastructure Logs**: Kubernetes and system logs
- **Audit Logs**: Security and compliance logs

## Disaster Recovery

### Backup Strategy

```mermaid
graph TB
    subgraph "Backup Sources"
        A[Application Data]
        B[Configuration]
        C[Secrets]
    end
    
    subgraph "Backup Process"
        D[Velero Backup]
        E[MinIO Storage]
        F[Backup Verification]
    end
    
    subgraph "Recovery Process"
        G[Disaster Detection]
        H[Restore from Backup]
        I[Service Validation]
        J[Traffic Restoration]
    end
    
    A --> D
    B --> D
    C --> D
    
    D --> E
    E --> F
    
    F --> G
    G --> H
    H --> I
    I --> J
```

### Recovery Procedures

1. **RTO (Recovery Time Objective)**: < 30 minutes
2. **RPO (Recovery Point Objective)**: < 1 hour
3. **Testing**: Monthly disaster recovery drills
4. **Documentation**: Detailed recovery procedures

## Future Enhancements

### Planned Features

- **Service Mesh**: Istio integration for advanced traffic management
- **Observability**: Prometheus, Grafana, and Jaeger integration
- **GitOps**: Multi-cluster ArgoCD setup
- **Security**: Falco runtime security monitoring
- **Storage**: External storage solutions (AWS EBS, GCP Persistent Disk)

### Scalability Improvements

- **Multi-Cluster**: Cross-cluster deployments
- **Auto-Scaling**: HPA and VPA implementation
- **Load Testing**: Automated performance testing
- **Chaos Engineering**: Fault injection and resilience testing
