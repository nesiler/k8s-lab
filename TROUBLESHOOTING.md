# Troubleshooting Guide

## Grafana/Prometheus Metrics Issues

### 🔍 **Problem Diagnosis**

If you can access Grafana but don't see metrics, follow these steps:

### 1. **Test API Metrics Endpoint**
```bash
# Test if API metrics are working
curl http://localhost:8080/metrics

# Expected output should include:
# api_requests_total
# api_request_duration_seconds
# db_operations_total
```

### 2. **Check Prometheus Targets**
```bash
# Check if Prometheus can scrape the API
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health}'
```

### 3. **Verify Pod Annotations**
```bash
# Check if API pods have correct annotations
kubectl get pods -n test-lab -o yaml | grep -A 5 -B 5 prometheus.io
```

### 4. **Check Prometheus Configuration**
```bash
# View Prometheus config
kubectl get configmap prometheus-config -n test-lab -o yaml
```

### 5. **Test Metrics Collection**
```bash
# Run the metrics test script
make test-metrics
```

## 🛠️ **Common Issues & Solutions**

### **Issue 1: No API Metrics in Prometheus**

**Symptoms:**
- Prometheus targets show API job as "down"
- No `api_requests_total` metrics in Prometheus

**Solutions:**
1. **Check API pod annotations:**
   ```bash
   kubectl get pods -n test-lab -l app=api -o yaml | grep -A 10 annotations
   ```

2. **Verify API metrics endpoint:**
   ```bash
   kubectl port-forward -n test-lab svc/api-service 8080:80 &
   curl http://localhost:8080/metrics
   ```

3. **Check Prometheus configuration:**
   ```bash
   kubectl get configmap prometheus-config -n test-lab -o yaml
   ```

### **Issue 2: Missing Kubernetes Metrics**

**Symptoms:**
- No `kube_deployment_status_replicas` metrics
- Dashboard shows "No data"

**Solutions:**
1. **Deploy kube-state-metrics:**
   ```bash
   kubectl apply -f k8s/monitoring/kube-state-metrics.yaml
   ```

2. **Deploy node-exporter:**
   ```bash
   kubectl apply -f k8s/monitoring/node-exporter.yaml
   ```

3. **Restart Prometheus:**
   ```bash
   kubectl rollout restart deployment prometheus -n test-lab
   ```

### **Issue 3: Grafana Dashboard Issues**

**Symptoms:**
- Dashboard loads but shows no data
- "No data" errors in panels

**Solutions:**
1. **Check data source:**
   - Go to Grafana → Configuration → Data Sources
   - Verify Prometheus URL is `http://prometheus:9090`

2. **Test queries manually:**
   - Go to Grafana → Explore
   - Try query: `api_requests_total`

3. **Check time range:**
   - Ensure time range includes recent data
   - Try "Last 15 minutes"

### **Issue 4: Prometheus Configuration Issues**

**Symptoms:**
- Prometheus shows configuration errors
- Targets not being scraped

**Solutions:**
1. **Reload Prometheus config:**
   ```bash
   kubectl exec -n test-lab deployment/prometheus -- wget --post-data='' http://localhost:9090/-/reload
   ```

2. **Check Prometheus logs:**
   ```bash
   kubectl logs -n test-lab deployment/prometheus
   ```

3. **Verify service discovery:**
   ```bash
   kubectl get endpoints -n test-lab
   ```

## 🔧 **Quick Fixes**

### **Complete Reset (if nothing works):**
```bash
# Clean everything
make clean

# Start fresh
make start

# Wait for all pods to be ready
kubectl wait --for=condition=ready pods -n test-lab --all --timeout=300s

# Test metrics
make test-metrics
```

### **Manual Metrics Test:**
```bash
# Generate some API traffic
for i in {1..10}; do
  curl http://localhost:8080/health
  curl http://localhost:8080/stats
  sleep 1
done

# Check if metrics appear
curl http://localhost:8080/metrics | grep api_requests_total
```

### **Prometheus Reload:**
```bash
# Reload Prometheus configuration
kubectl exec -n test-lab deployment/prometheus -- wget --post-data='' http://localhost:9090/-/reload
```

## 📊 **Expected Metrics**

After successful setup, you should see these metrics in Prometheus:

### **API Metrics:**
- `api_requests_total` - Total API requests
- `api_request_duration_seconds` - Request duration
- `api_active_requests` - Active requests
- `db_operations_total` - Database operations

### **Kubernetes Metrics:**
- `kube_deployment_status_replicas_available` - Available replicas
- `container_cpu_usage_seconds_total` - CPU usage
- `container_memory_usage_bytes` - Memory usage

### **System Metrics:**
- `node_cpu_seconds_total` - Node CPU
- `node_memory_MemAvailable_bytes` - Available memory

## 🎯 **Verification Steps**

1. **API is working:**
   ```bash
   curl http://localhost:8080/health
   ```

2. **API metrics are exposed:**
   ```bash
   curl http://localhost:8080/metrics | grep api_requests_total
   ```

3. **Prometheus can scrape API:**
   ```bash
   curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="test-lab-api")'
   ```

4. **Grafana can query Prometheus:**
   - Go to Grafana → Explore
   - Select Prometheus data source
   - Query: `api_requests_total`

5. **Dashboard shows data:**
   - Go to Grafana → Dashboards
   - Open "Kubernetes Test Lab Dashboard"
   - Should show graphs with data

## 📞 **Still Having Issues?**

If you're still experiencing problems:

1. **Check logs:**
   ```bash
   kubectl logs -n test-lab deployment/api
   kubectl logs -n test-lab deployment/prometheus
   kubectl logs -n test-lab deployment/grafana
   ```

2. **Check events:**
   ```bash
   kubectl get events -n test-lab --sort-by='.lastTimestamp'
   ```

3. **Verify network connectivity:**
   ```bash
   kubectl exec -n test-lab deployment/prometheus -- wget -qO- http://api-service:80/health
   ```

4. **Create an issue** with:
   - Your operating system
   - Kubernetes version (`kubectl version`)
   - Complete error messages
   - Output of `make test-metrics` 

---

## Quick Diagnostics
```bash
# Test all metrics endpoints
make test-metrics

# Check system status
make status

# View logs
make logs
```

## Additional Common Issues

### Port Conflicts
```bash
lsof -i :8080,8089,3000,9090,8001
kill -9 <PID>
```

### Cluster Issues
```bash
make clean
make start
```

### Resource Limits
- Memory: 8GB+
- CPU: 4 cores+
- Disk: 20GB+ free

### Pods Not Starting
```bash
kubectl get pods -n test-lab
kubectl logs -n test-lab <pod-name>
kubectl get events -n test-lab
```

### Load Balancer Issues
```bash
kubectl get svc -n test-lab
kubectl port-forward -n test-lab svc/api-service 8080:80
```