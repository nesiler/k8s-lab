### Kubernetes Test Lab 🚀

Kubernetes playground to learn autoscaling, monitoring, and load testing with a minimal microservices stack.

What you get:
- Kubernetes (k3d), API (Go + chi), PostgreSQL, Locust, Prometheus, Grafana, Kubernetes Dashboard
- One-command start and ready-to-use dashboards and metrics

### Prerequisites
- Docker, kubectl, k3d, make, curl (jq optional)

Install automatically:
```bash
./scripts/install-dependencies.sh
```

### Quick start
```bash
make start      # create cluster, deploy, wait, show URLs
make status     # check pods/services/HPA
make stop       # remove namespace (keep cluster)
make clean      # delete cluster and clean up
```

### Access URLs
| Service | URL | Notes |
|---|---|---|
| API | http://localhost:8080 | Exposes /, /health, /metrics |
| Locust | http://localhost:8089 | Start load tests |
| Grafana | http://localhost:3000 | admin/admin |
| Prometheus | http://localhost:9090 | Web UI |
| K8s Dashboard | http://localhost:8001 | Via k3d LB |

### Common commands
```bash
make logs       # tail API and DB logs
make watch      # live view of pods and HPA
make load-test  # open Locust UI
```

### Documentation
- [PROJECT.md](PROJECT.md)
- [API.md](API.md)
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

### Clone
```bash
git clone https://github.com/nesiler/k8s-lab.git
cd k8s-lab
```

### License
MIT — see [LICENSE](LICENSE).