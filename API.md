### API Reference

Go HTTP API using `chi` with Prometheus metrics. Default container port is 8000. Exposed via k3d load balancer on http://localhost:8080.

### Base URLs
- Local: http://localhost:8080
- In-cluster service: `http://api-service.test-lab.svc.cluster.local`

### Endpoints

- GET `/` — Basic info
  - 200: `{ "message": "Kubernetes Test Lab Go API", "docs": "/metrics", "health": "/health" }`

- GET `/health` — Liveness/readiness probe target
  - 200: `{ "status": "healthy" }`

- GET `/metrics` — Prometheus metrics
  - Scraped by Prometheus via pod annotations

- POST `/cpu-intensive?iterations={int}` — CPU stress
  - Query: `iterations` (default 1000000)
  - 200: `{ "iterations": n, "hash": "..." }`

- POST `/memory-intensive?size_mb={int}` — Memory stress
  - Query: `size_mb` (1..100, default 10)
  - 200: `{ "allocated_mb": n }`

- POST `/simulate-delay?delay_seconds={float}` — Artificial delay
  - Query: `delay_seconds` (0..10, default 1.0)
  - 200: `{ "message": "ok", "delay_seconds": n }`

- GET `/stats` — DB stats snapshot
  - 200: `{ "db_rows": <int>, "db_size_bytes": <int> }`

### Curl examples
```bash
curl -s http://localhost:8080/health
curl -s http://localhost:8080/metrics | head
curl -s -X POST "http://localhost:8080/cpu-intensive?iterations=500000" | jq .
curl -s -X POST "http://localhost:8080/memory-intensive?size_mb=50" | jq .
curl -s -X POST "http://localhost:8080/simulate-delay?delay_seconds=2" | jq .
curl -s http://localhost:8080/stats | jq .
```

### Metrics
Exported Prometheus metrics include:
- `api_requests_total{method,endpoint,status}`
- `api_requests_success_total`, `api_requests_failed_total`
- `api_request_duration_seconds{method,endpoint}` (histogram)
- `api_active_requests`
- `db_operations_total{operation}`
- `db_rows`, `db_size_bytes`

### Configuration
- Env: `DATABASE_URL` from `ConfigMap` `api-config`
- Pod annotations: `prometheus.io/scrape: "true"`, `prometheus.io/port: "8000"`, `prometheus.io/path: "/metrics"`

