### Kubernetes in This Lab (Beginner Friendly)

This folder contains the Kubernetes manifests that power the lab. Read this first to understand how the pieces fit together and how to experiment safely.

Links to examples in this repo:
- Namespace: `./namespace.yaml`
- Global Config: `./configmap.yaml`
- API (Go): `./api/deployment.yaml`, `./api/service.yaml`, `./api/hpa.yaml`, `./api/configmap.yaml`
- Database (PostgreSQL): `./database/deployment.yaml`, `./database/service.yaml`, `./database/pvc.yaml`, `./database/configmap.yaml`
- Load testing (Locust): `./load-test/deployment.yaml`, `./load-test/service.yaml`, `./load-test/configmap.yaml`
- Monitoring: `./monitoring/prometheus/*`, `./monitoring/grafana/*`, `./monitoring/kube-state-metrics.yaml`, `./monitoring/node-exporter.yaml`
- Dashboard: `./dashboard/*`

Use the command below to apply the full set idempotently:
```bash
make update-k8s
```

## YAML Primer (Enough to Be Dangerous)

YAML is indentation-sensitive. You declare keys and values with `key: value`. Lists use `-` dashes. Strings can be quoted or unquoted.

Example structure used by almost every Kubernetes manifest:
```yaml
apiVersion: apps/v1        # Which API and version defines this object
kind: Deployment           # The resource type (Deployment, Service, ConfigMap, ...)
metadata:                  # Identity, labels, annotations
  name: api
  namespace: test-lab
  labels:
    app: api
spec:                      # The desired state (what you want)
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: api
        image: k8s-test-lab/api:latest
        ports:
        - containerPort: 8000
```

Tips:
- Indentation: 2 spaces is common. Never use tabs.
- Lists: a dash `-` starts each item.
- Strings: quote when in doubt, especially for values like `"true"` or `"8000"` in annotations.
- Use `kubectl explain <resource> --recursive` to discover fields.

## Core Kubernetes Concepts in This Lab

### Namespace
Groups objects into a logical environment.
- Example: `./namespace.yaml` creates `test-lab`.
- Why: isolating resources, easier cleanup.

### Labels and Selectors
Key/value pairs for grouping and selecting objects.
- Where: `metadata.labels` on pods/deployments and `spec.selector` on services/HPAs.
- Why: Services and HPAs must know which pods to target.

### ConfigMap
Key/value pairs for configuration, not secrets.
- Examples: `./configmap.yaml` (global), `./api/configmap.yaml`, `./database/configmap.yaml`.
- How used: via `envFrom.configMapRef` or mounted as files.
- Try: change `DATABASE_URL` in `./api/configmap.yaml` and run `make update-k8s`.

### Deployment (API, DB, Locust)
Keeps a set of identical pods running and handles rollouts.
- API Deployment: `./api/deployment.yaml`
  - Important fields: `replicas`, `resources.requests/limits`, `livenessProbe/readinessProbe`, `annotations` for Prometheus scraping.
  - Try: change `resources.limits.cpu` or probes’ delays; apply and watch.
- Postgres Deployment: `./database/deployment.yaml` uses a PVC for storage.
- Locust Deployment: `./load-test/deployment.yaml` exposes UI on 8089.

### Service
Stable network entrypoint for a set of pods.
- API Service: `./api/service.yaml` (type `LoadBalancer`) forwards 80 → pod 8000.
- DB Service: `./database/service.yaml` (type `ClusterIP`) is cluster-internal.
- Try: change `type: LoadBalancer` to `NodePort` for API and see the difference.

### Horizontal Pod Autoscaler (HPA)
Automatically adjusts replicas based on metrics.
- `./api/hpa.yaml` targets the API Deployment.
- In this lab: CPU 60% and memory 70% utilization; min 2, max 15 replicas.
- Try: change `averageUtilization` thresholds and run a load test (Locust) to observe scaling.

### Persistent Volumes and Claims (PVC)
Durable storage for stateful apps.
- Postgres PVC: `./database/pvc.yaml` binds storage and is mounted at `/var/lib/postgresql/data`.
- Try: decrease storage size (carefully) or change `storageClassName` if you know your cluster’s storage classes.

### Monitoring via Prometheus and Grafana
- Prometheus scrapes `/metrics` from API pods. The annotations in `./api/deployment.yaml` enable scraping.
- Grafana is pre-provisioned with a data source and dashboard.
- Try: open Grafana at http://localhost:3000 and run queries like `api_requests_total`.

## How to Apply, Inspect, and Revert

Apply everything safely (idempotent):
```bash
make update-k8s
```

Apply one file or folder:
```bash
kubectl apply -f k8s/api/deployment.yaml
kubectl apply -f k8s/monitoring/
```

Check what’s running:
```bash
kubectl get pods -n test-lab
kubectl get svc -n test-lab
kubectl get hpa -n test-lab
```

Describe and debug:
```bash
kubectl describe deployment api -n test-lab | less
kubectl logs -n test-lab deployment/api --tail=100
kubectl get events -n test-lab --sort-by=.lastTimestamp | tail -20
```

Roll out changes:
```bash
kubectl rollout restart deployment/api -n test-lab
kubectl rollout status deployment/api -n test-lab
```

Delete what you applied:
```bash
kubectl delete -f k8s/api/deployment.yaml
```

## Required vs Optional Fields (Mental Model)
- Required: `apiVersion`, `kind`, `metadata.name`, and a valid top-level `spec` for that resource.
- Usually required in Deployments: `spec.selector`, `spec.template.metadata.labels` (must match selector), at least one container with `image`.
- Optional but recommended: `resources`, `probes`, `labels`, `annotations`, `imagePullPolicy`.

## Common Options You Can Tweak
- Replicas: scale manually in a Deployment vs. letting HPA own it.
- Resources: set `requests` and `limits` to influence scheduling and HPA behavior.
- Probes: adjust `initialDelaySeconds`, `periodSeconds`, and `timeoutSeconds` to match app startup.
- Service type: `ClusterIP` (internal), `NodePort`, or `LoadBalancer` (used here with k3d LB).
- HPA targets: CPU, memory; min/max replicas; scale up/down behavior.

## Learning Scenarios (Try These)
1. Scale API manually to 5 replicas. Observe pod spread across nodes.
2. Increase CPU limit, then run Locust and watch HPA behavior change.
3. Break readiness by pointing `DATABASE_URL` to a wrong host. See how probes react.
4. Change API Service from `LoadBalancer` to `NodePort`. Confirm access method changes.
5. Add a new label `tier: backend` to API pod template and select with `kubectl get pods -l tier=backend`.
6. Lower HPA CPU threshold to 30%. Generate load and watch faster scale-up.
7. Remove Prometheus annotations from the API pod template. Confirm metrics disappear in Prometheus.
8. Increase Postgres PVC size. Confirm pod recreation behavior and storage status.
9. Add a second container (sidecar) to API Deployment that prints a heartbeat. Tail logs.
10. Use `kubectl explain deployment.spec.template.spec.containers.resources --recursive` to explore every field.

## Quick Reference Commands
```bash
# Explain fields
kubectl explain deployment --recursive | less

# Apply all project k8s manifests
make update-k8s

# Live watch
watch -n 2 "kubectl get pods -n test-lab && echo '---' && kubectl get hpa -n test-lab"

# Access URLs (k3d load balancer)
API:         http://localhost:8080
Locust:      http://localhost:8089
Grafana:     http://localhost:3000 (admin/admin)
Prometheus:  http://localhost:9090
Dashboard:   http://localhost:8001
```

If you get stuck, see the top-level `TROUBLESHOOTING.md`.

