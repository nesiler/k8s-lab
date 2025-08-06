# Kubernetes Test Lab 🚀

A comprehensive Kubernetes testing environment for learning auto-scaling, monitoring, and load testing with a complete microservices stack.

## 🎯 Features

- ✅ **One-command setup** (`make start`)
- ✅ **Kubernetes cluster** (k3d-based)
- ✅ **Auto-scaling** (Horizontal Pod Autoscaler)
- ✅ **Load testing** (Locust with multiple scenarios)
- ✅ **Monitoring stack** (Prometheus + Grafana)
- ✅ **Kubernetes Dashboard**
- ✅ **PostgreSQL database** with persistent storage
- ✅ **FastAPI backend** with comprehensive metrics
- ✅ **Real-time monitoring** and alerting

## 🏗️ Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Locust    │────▶│   FastAPI   │────▶│ PostgreSQL  │
│ Load Tester │     │     API     │     │  Database   │
└─────────────┘     └─────────────┘     └─────────────┘
       │                    │                    │
       ▼                    ▼                    ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Web UI     │     │     HPA     │     │ Persistent  │
│ Port: 8089  │     │Auto-scaling │     │   Volume    │
└─────────────┘     └─────────────┘     └─────────────┘
```

## 📋 Prerequisites

### 🖥️ Supported Platforms
- **Linux** (Ubuntu/Debian, CentOS/RHEL)
- **macOS** (Intel & Apple Silicon)
- **Windows** (WSL2)

### 🛠️ Required Software
- **Docker** (Desktop or Engine)
- **kubectl** (Kubernetes CLI)
- **k3d** (Kubernetes in Docker)
- **make** (Build automation)
- **curl** (HTTP client)
- **jq** (JSON processor, optional)

### 🚀 Automatic Installation

**Install all dependencies automatically:**
```bash
chmod +x scripts/install-dependencies.sh
./scripts/install-dependencies.sh
```

**Manual dependency check:**
```bash
bash scripts/check-deps.sh
```

## 🚀 Quick Start

```bash
# Start the entire system
make start

# Check system status
make status

# Stop the system
make stop

# Clean up everything
make clean
```

## 🔗 Access Points

Once the system is running, access the following services:

| Service | URL | Credentials | Description |
|---------|-----|-------------|-------------|
| **API** | http://localhost:8080 | - | FastAPI backend with Swagger docs |
| **Locust UI** | http://localhost:8089 | - | Load testing interface |
| **Grafana** | http://localhost:3000 | admin/admin | Monitoring dashboard |
| **K8s Dashboard** | http://localhost:8001 | - | Kubernetes management UI |
| **Prometheus** | http://localhost:9090 | - | Metrics collection |

## 📊 Load Testing

### Getting Started
1. Navigate to Locust UI: http://localhost:8089
2. Set number of users and spawn rate
3. Click "Start swarming"
4. Monitor pod scaling in Grafana

### Test Scenarios

#### 1. **Ramp-up Test**
- Gradually increasing user load
- Observe HPA response time
- Monitor resource utilization

#### 2. **Spike Test**
- Sudden load increase
- Test system resilience
- Verify auto-scaling behavior

#### 3. **Sustained Load**
- Constant load over time
- Memory leak detection
- Performance degradation analysis

## 🛠️ Available Commands

```bash
# System management
make start          # Start entire system
make stop           # Stop applications (keep cluster)
make clean          # Complete cleanup
make status         # Show system status

# Cluster management
make cluster        # Create k3d cluster only
make deploy         # Deploy applications only
make check          # Verify dependencies

# Monitoring
make logs           # View pod logs
make watch          # Live pod monitoring
make shell          # Access cluster shell
```

## 🧪 API Endpoints

The FastAPI backend provides comprehensive testing endpoints:

### Core Endpoints
- `GET /health` - Health check
- `GET /metrics` - Prometheus metrics
- `GET /docs` - Interactive API documentation

### Task Management
- `POST /tasks` - Create task
- `GET /tasks` - List tasks
- `GET /tasks/{id}` - Get specific task
- `PUT /tasks/{id}` - Update task
- `DELETE /tasks/{id}` - Delete task

### Load Testing Endpoints
- `POST /cpu-intensive` - CPU stress test
- `POST /memory-intensive` - Memory stress test
- `POST /simulate-delay` - Artificial delay
- `POST /random-error` - Error simulation

## 📈 Monitoring & Metrics

### Prometheus Metrics
- Request count and duration
- Database operation metrics
- CPU and memory usage
- Custom application metrics

### Grafana Dashboards
- Real-time system metrics
- Pod scaling visualization
- Performance analytics
- Resource utilization graphs

## 🏗️ Project Structure

```
k8s-lab/
├── api/                    # FastAPI backend
│   ├── main.py            # API endpoints
│   ├── models.py          # Database models
│   ├── database.py        # Database connection
│   └── requirements.txt   # Python dependencies
├── k8s/                   # Kubernetes manifests
│   ├── api/              # API deployment
│   ├── database/         # PostgreSQL setup
│   ├── monitoring/       # Prometheus & Grafana
│   ├── dashboard/        # K8s Dashboard
│   └── load-test/        # Locust deployment
├── load-test/            # Load testing
│   ├── locustfile.py     # Test scenarios
│   └── config.py         # Test configuration
├── scripts/              # Utility scripts
└── Makefile             # Build automation
```

## 🛠️ Troubleshooting

### Quick Diagnostics
```bash
# Test all metrics endpoints
make test-metrics

# Check system status
make status

# View logs
make logs
```

### Common Issues

#### Grafana/Prometheus Metrics Issues
If you can access Grafana but don't see metrics:

1. **Test API metrics:**
   ```bash
   curl http://localhost:8080/metrics
   ```

2. **Check Prometheus targets:**
   ```bash
   curl http://localhost:9090/api/v1/targets
   ```

3. **Verify pod annotations:**
   ```bash
   kubectl get pods -n test-lab -o yaml | grep -A 5 prometheus.io
   ```

4. **Complete troubleshooting guide:** See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

#### Port Conflicts
```bash
# Check used ports
lsof -i :8080,8089,3000,9090,8001

# Kill conflicting processes
kill -9 <PID>
```

#### Cluster Issues
```bash
# Restart cluster
make clean
make start
```

#### Resource Limits
Ensure Docker has adequate resources:
- **Memory**: Minimum 8GB
- **CPU**: Minimum 4 cores
- **Disk**: At least 20GB free space

#### Pods Not Starting
```bash
# Check pod status
kubectl get pods -n test-lab

# View pod logs
kubectl logs -n test-lab <pod-name>

# Check events
kubectl get events -n test-lab
```

#### Load Balancer Issues
```bash
# Check service status
kubectl get svc -n test-lab

# Verify port forwarding
kubectl port-forward -n test-lab svc/api-service 8080:80
```

## 📚 Documentation

- [API Documentation](http://localhost:8080/docs) - Interactive API docs
- [Kubernetes Manifests](./k8s/) - Deployment configurations
- [Load Test Scenarios](./load-test/) - Testing strategies

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup
```bash
# Clone the repository
git clone https://github.com/yourusername/k8s-lab.git
cd k8s-lab

# Install dependencies
./scripts/install-dependencies.sh

# Start development environment
make start
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [k3d](https://k3d.io/) - Kubernetes in Docker
- [Locust](https://locust.io/) - Load testing framework
- [Prometheus](https://prometheus.io/) - Monitoring system
- [Grafana](https://grafana.com/) - Visualization platform
- [FastAPI](https://fastapi.tiangolo.com/) - Modern web framework

## 📞 Support

If you encounter any issues or have questions:

1. Check the [troubleshooting section](#troubleshooting)
2. Review existing [issues](../../issues)
3. Create a new [issue](../../issues/new) with detailed information

---

**Happy Testing! 🚀**