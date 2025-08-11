# Kubernetes Test Lab Makefile
# Manage the entire system with simple make commands

.PHONY: help start stop clean status logs watch check cluster deploy shell \
	update update-k8s update-api restart-api restart-monitoring

# Default target
.DEFAULT_GOAL := help

# Variables
CLUSTER_NAME = k8s-test-lab
NAMESPACE = test-lab
KUBECONFIG = $(HOME)/.kube/config
K3D_VERSION = rancher/k3s:v1.28.5-k3s1

# Colors
 GREEN = \033[0;32m
 RED = \033[0;31m
 YELLOW = \033[0;33m
 NC = \033[0m # No Color

# Help
help: ## Show this help message
	@echo "Kubernetes Test Lab - Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "Usage: make <command>"

# Ana komutlar
start: check ## Start the whole system (cluster + apps)
	@echo "$(GREEN)🚀 Starting Kubernetes Test Lab...$(NC)"
	@bash scripts/check-deps.sh
	@$(MAKE) cluster
	@$(MAKE) deploy
	@$(MAKE) wait-ready
	@$(MAKE) show-urls
	@echo "$(GREEN)✅ System is ready!$(NC)"

stop: ## Stop the system (delete apps, keep cluster)
	@echo "$(YELLOW)🛑 Stopping system...$(NC)"
	@kubectl delete namespace $(NAMESPACE) --ignore-not-found=true
	@echo "$(GREEN)✅ System stopped$(NC)"

clean: ## Clean everything (including cluster)
	@echo "$(RED)🧹 Cleaning up...$(NC)"
	@k3d cluster delete $(CLUSTER_NAME) 2>/dev/null || true
	@docker rm -f $$(docker ps -aq --filter "label=app=k8s-test-lab") 2>/dev/null || true
	@echo "$(GREEN)✅ Cleanup completed$(NC)"

# Cluster yönetimi
cluster: ## Create the k3d cluster
	@echo "$(GREEN)🔧 Creating k3d cluster...$(NC)"
	@k3d cluster create $(CLUSTER_NAME) \
		--api-port 6550 \
		--port "8080:80@loadbalancer" \
		--port "8089:8089@loadbalancer" \
		--port "3000:3000@loadbalancer" \
		--port "9090:9090@loadbalancer" \
		--port "8001:443@loadbalancer" \
		--agents 2 \
		--k3s-arg "--disable=traefik@server:0" \
		--image $(K3D_VERSION) \
		--wait
	@kubectl config use-context k3d-$(CLUSTER_NAME)
	@echo "$(GREEN)✅ Cluster is ready$(NC)"
	@echo "$(YELLOW)⏳ Waiting for cluster nodes to be ready...$(NC)"
	@sleep 10
	@kubectl wait --for=condition=ready nodes --all --timeout=60s || true

# Deployment
deploy: ## Deploy all applications
	@echo "$(GREEN)📦 Deploying applications...$(NC)"
	@bash scripts/setup.sh
	@echo "$(GREEN)✅ Deployment completed$(NC)"

# Fast update commands (without full restart)
update: update-k8s ## Idempotently apply changed YAML manifests
	@echo "$(GREEN)✅ Kubernetes manifests applied$(NC)"
	@$(MAKE) status

update-k8s: ## Apply all Kubernetes manifests idempotently
	@echo "$(GREEN)📦 Applying Kubernetes manifests...$(NC)"
	@kubectl apply -f k8s/namespace.yaml
	@kubectl apply -f k8s/configmap.yaml
	@kubectl apply -f k8s/database/
	@kubectl apply -f k8s/api/
	@kubectl apply -f k8s/load-test/
	@kubectl apply -f k8s/monitoring/prometheus/
	@kubectl apply -f k8s/monitoring/grafana/
	@kubectl apply -f k8s/monitoring/kube-state-metrics.yaml
	@kubectl apply -f k8s/monitoring/node-exporter.yaml
	@kubectl apply -f k8s/dashboard/

update-api: ## Update only the API (build image + import + rollout restart)
	@echo "$(GREEN)🐳 Building API image...$(NC)"
	@docker build -t k8s-test-lab/api:latest ./api
	@echo "$(GREEN)📦 Importing image into k3d cluster...$(NC)"
	@k3d image import k8s-test-lab/api:latest -c $(CLUSTER_NAME)
	@echo "$(GREEN)🔁 Rolling out API restart$(NC)"
	@kubectl rollout restart deployment/api -n $(NAMESPACE)
	@kubectl rollout status deployment/api -n $(NAMESPACE) --timeout=180s
	@echo "$(GREEN)✅ API updated$(NC)"

restart-api: ## Restart the API deployment
	@kubectl rollout restart deployment/api -n $(NAMESPACE)
	@kubectl rollout status deployment/api -n $(NAMESPACE) --timeout=180s

restart-monitoring: ## Restart Prometheus and Grafana
	@kubectl rollout restart deployment/prometheus -n $(NAMESPACE) || true
	@kubectl rollout restart deployment/grafana -n $(NAMESPACE) || true
	@kubectl rollout status deployment/grafana -n $(NAMESPACE) --timeout=180s || true

# Monitoring commands
status: ## Show system status
	@echo "$(GREEN)📊 System Status:$(NC)"
	@echo ""
	@echo "Cluster:"
	@k3d cluster list | grep $(CLUSTER_NAME) || echo "Cluster bulunamadı"
	@echo ""
	@echo "Pods ($(NAMESPACE) namespace):"
	@kubectl get pods -n $(NAMESPACE) 2>/dev/null || echo "Namespace not found"
	@echo ""
	@echo "Services:"
	@kubectl get svc -n $(NAMESPACE) 2>/dev/null || true
	@echo ""
	@echo "HPA:"
	@kubectl get hpa -n $(NAMESPACE) 2>/dev/null || true

logs: ## Show pod logs
	@echo "$(GREEN)📜 Pod logs:$(NC)"
	@kubectl logs -n $(NAMESPACE) -l app=api --tail=50 || true
	@echo "---"
	@kubectl logs -n $(NAMESPACE) -l app=postgres --tail=50 || true

watch: ## Live watch pod and HPA status
	@watch -n 2 "kubectl get pods -n $(NAMESPACE) && echo '---' && kubectl get hpa -n $(NAMESPACE)"

test-metrics: ## Test metrics endpoints
	@bash scripts/test-metrics.sh

# Utility commands
check: ## Check dependencies
	@bash scripts/check-deps.sh

shell: ## Shell into API pod
	@kubectl exec -it -n $(NAMESPACE) $$(kubectl get pod -n $(NAMESPACE) -l app=api -o jsonpath="{.items[0].metadata.name}") -- /bin/bash

db-shell: ## Shell into database pod
	@kubectl exec -it -n $(NAMESPACE) $$(kubectl get pod -n $(NAMESPACE) -l app=postgres -o jsonpath="{.items[0].metadata.name}") -- psql -U postgres -d testdb

port-forward: ## Manual port forwarding
	@echo "$(GREEN)🔌 Starting port forwarding...$(NC)"
	@kubectl port-forward -n $(NAMESPACE) svc/api-service 8080:80 &
	@kubectl port-forward -n $(NAMESPACE) svc/locust-service 8089:8089 &
	@kubectl port-forward -n $(NAMESPACE) svc/grafana 3000:3000 &
	@kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard 8001:443 &

# Test komutları
test-api: ## Test API
	@echo "$(GREEN)🧪 Testing API...$(NC)"
	@curl -s http://localhost:8080/health | jq . || echo "API not reachable"
	@curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets | length' || true

load-test: ## Start a simple load test
	@echo "$(GREEN)🔥 Starting load test...$(NC)"
	@echo "Locust UI: http://localhost:8089"
	@if command -v open >/dev/null 2>&1; then \
		open http://localhost:8089; \
	elif command -v xdg-open >/dev/null 2>&1; then \
		xdg-open http://localhost:8089; \
	else \
		echo "Open your browser: http://localhost:8089"; \
	fi

# Build commands
build-images: ## Build Docker images
	@echo "$(GREEN)🐳 Building Docker images...$(NC)"
	@docker build -t k8s-test-lab/api:latest ./api
	@docker build -t k8s-test-lab/locust:latest ./load-test
	@k3d image import k8s-test-lab/api:latest -c $(CLUSTER_NAME)
	@k3d image import k8s-test-lab/locust:latest -c $(CLUSTER_NAME)

# Docker Compose commands
docker-up: ## Start services with Docker Compose
	@echo "$(GREEN)🐳 Starting Docker Compose services...$(NC)"
	@docker-compose up -d
	@echo "$(GREEN)✅ Docker Compose ready$(NC)"
	@echo ""
	@echo "Docker Compose Ports:"
	@echo "  API: http://localhost:18000"
	@echo "  Locust: http://localhost:18089"
	@echo "  Grafana: http://localhost:13000"
	@echo "  Prometheus: http://localhost:19090"

docker-down: ## Stop Docker Compose services
	@echo "$(YELLOW)🛑 Stopping Docker Compose services...$(NC)"
	@docker-compose down
	@echo "$(GREEN)✅ Docker Compose stopped$(NC)"

docker-logs: ## Show Docker Compose logs
	@docker-compose logs -f

# Helper functions
wait-ready: ## Wait until all pods become ready
	@echo "$(YELLOW)⏳ Waiting for pods to become ready...$(NC)"
	@bash scripts/wait-for-ready.sh

show-urls: ## Show access URLs
	@echo ""
	@echo "$(GREEN)🔗 Access Points:$(NC)"
	@echo ""
	@echo "  API:                http://localhost:8080"
	@echo "  Locust UI:          http://localhost:8089"
	@echo "  Grafana:            http://localhost:3000 (admin/admin)"
	@echo "  Prometheus:         http://localhost:9090"
	@echo "  K8s Dashboard:      http://localhost:8001"
	@echo ""
	@echo "$(YELLOW)💡 Tip: run 'make load-test' to start testing$(NC)"

# Debugging
debug: ## Show debug info
	@echo "$(YELLOW)🔍 Debug info:$(NC)"
	@echo "Cluster: $(CLUSTER_NAME)"
	@echo "Namespace: $(NAMESPACE)"
	@echo "Kubeconfig: $(KUBECONFIG)"
	@echo ""
	@kubectl cluster-info
	@echo ""
	@kubectl get nodes
	@echo ""
	@docker ps --filter "label=app=k8s-test-lab"

debug-pods: ## Show pod errors/state
	@echo "$(YELLOW)🔍 Pod states:$(NC)"
	@kubectl get pods -n $(NAMESPACE) -o wide
	@echo ""
	@echo "$(YELLOW)📜 Non-running pods:$(NC)"
	@kubectl get pods -n $(NAMESPACE) --field-selector=status.phase!=Running,status.phase!=Succeeded
	@echo ""
	@echo "$(YELLOW)📋 Pod events:$(NC)"
	@kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp' | tail -20

troubleshoot: ## Troubleshooting information
	@echo "$(YELLOW)🔍 Troubleshooting info:$(NC)"
	@echo ""
	@echo "1. Pod states:"
	@kubectl get pods -n $(NAMESPACE) -o wide
	@echo ""
	@echo "2. Pod describe (API):"
	@kubectl describe pod -l app=api -n $(NAMESPACE) | grep -A 10 "Events:"
	@echo ""
	@echo "3. Pod logs (API):"
	@kubectl logs -l app=api -n $(NAMESPACE) --tail=20 || echo "No logs"
	@echo ""
	@echo "4. Docker images:"
	@docker images | grep k8s-test-lab || echo "Local image bulunamadı"
	@echo ""
	@echo "5. k3d images:"
	@docker exec k3d-$(CLUSTER_NAME)-server-0 crictl images | grep k8s-test-lab || echo "No images in k3d"

# Monitoring kurulumu
monitoring: ## Prometheus ve Grafana'yı kur
	@echo "$(GREEN)📊 Monitoring stack kuruluyor...$(NC)"
	@kubectl apply -f k8s/monitoring/prometheus/
	@kubectl apply -f k8s/monitoring/grafana/
	@echo "$(GREEN)✅ Monitoring hazır$(NC)"

# Dashboard kurulumu  
dashboard: ## Kubernetes Dashboard'u kur
	@echo "$(GREEN)🎨 Kubernetes Dashboard kuruluyor...$(NC)"
	@kubectl apply -f k8s/dashboard/
	@echo "$(GREEN)✅ Dashboard hazır$(NC)"