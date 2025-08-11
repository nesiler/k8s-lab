### Project Overview

This lab provisions a lightweight Kubernetes environment (k3d) with:
- API (Go/chi) exposing health, metrics, and stress endpoints
- PostgreSQL with persistent storage
- Locust for load generation
- Prometheus and Grafana for metrics and dashboards
- Kubernetes Dashboard for cluster UI

### High-level Architecture
```
Locust ──▶ API (Go) ──▶ PostgreSQL
   │            │             
   └────────▶ Prometheus ◀──────── Grafana
```

### Components
- API
  - Image: `k8s-test-lab/api:latest`
  - Port: 8000 (LB 80 → 8000)
  - HPA: CPU 60% / Memory 70% (min 2, max 15)
  - Probes: `/health`
  - Metrics: `/metrics`

- Database (PostgreSQL 15)
  - Service: `postgres-service:5432`
  - PVC: `postgres-pvc`
  - Config: `k8s/database/configmap.yaml`

- Load Testing (Locust)
  - Image: `k8s-test-lab/locust:latest`
  - Web UI: 8089
  - Config/Scenarios: `load-test/`

- Monitoring
  - Prometheus: `k8s/monitoring/prometheus/`
  - Grafana: `k8s/monitoring/grafana/` (admin/admin)
  - kube-state-metrics, node-exporter

- Kubernetes Dashboard
  - Exposed via k3d LB at 8001

### Kubernetes Objects
- Namespace: `test-lab`
- Services: `api-service` (LoadBalancer), `postgres-service` (ClusterIP)
- Deployments: `api`, `postgres`, `locust`, `prometheus`, `grafana`
- HPA: `api-hpa`

### Developer Workflow
```bash
# Build and import images
make build-images

# Update only k8s manifests without full restart
make update

# Update API (build + import + rollout)
make update-api
```

### API Gateway / Ingress
This lab intentionally avoids an ingress controller to keep the footprint small. External access is provided via the k3d load balancer with explicit port mappings:
- 8080 → API
- 8089 → Locust
- 3000 → Grafana
- 9090 → Prometheus
- 8001 → Kubernetes Dashboard

You can add an ingress controller later (e.g., NGINX Ingress or Traefik) if you want hostname-based routing.

### Repository Structure
```
k8s-lab/
├── api/            # Go API and Dockerfile
├── k8s/            # Kubernetes manifests (api, db, monitoring, dashboard, load-test)
├── load-test/      # Locust config and scenarios
├── scripts/        # Setup and diagnostics scripts
└── Makefile        # One-command orchestration
```

