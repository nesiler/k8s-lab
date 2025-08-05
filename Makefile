# Kubernetes Test Lab Makefile
# Tek komutla tüm sistemi yönetmek için

.PHONY: help start stop clean status logs watch check cluster deploy shell

# Varsayılan hedef
.DEFAULT_GOAL := help

# Değişkenler
CLUSTER_NAME = k8s-test-lab
NAMESPACE = test-lab
KUBECONFIG = $(HOME)/.kube/config
K3D_VERSION = rancher/k3s:v1.28.5-k3s1

# Renkler
GREEN = \033[0;32m
RED = \033[0;31m
YELLOW = \033[0;33m
NC = \033[0m # No Color

# Help
help: ## Bu yardım mesajını göster
	@echo "Kubernetes Test Lab - Komutlar:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "Kullanım: make <komut>"

# Ana komutlar
start: check ## Tüm sistemi başlat (cluster + uygulamalar)
	@echo "$(GREEN)🚀 Kubernetes Test Lab başlatılıyor...$(NC)"
	@bash scripts/check-deps.sh
	@$(MAKE) cluster
	@$(MAKE) deploy
	@$(MAKE) wait-ready
	@$(MAKE) show-urls
	@echo "$(GREEN)✅ Sistem hazır!$(NC)"

stop: ## Sistemi durdur (uygulamaları kaldır, cluster'ı koru)
	@echo "$(YELLOW)🛑 Sistem durduruluyor...$(NC)"
	@kubectl delete namespace $(NAMESPACE) --ignore-not-found=true
	@echo "$(GREEN)✅ Sistem durduruldu$(NC)"

clean: ## Her şeyi temizle (cluster dahil)
	@echo "$(RED)🧹 Temizlik yapılıyor...$(NC)"
	@k3d cluster delete $(CLUSTER_NAME) 2>/dev/null || true
	@docker rm -f $$(docker ps -aq --filter "label=app=k8s-test-lab") 2>/dev/null || true
	@echo "$(GREEN)✅ Temizlik tamamlandı$(NC)"

# Cluster yönetimi
cluster: ## K3d cluster'ı oluştur
	@echo "$(GREEN)🔧 K3d cluster oluşturuluyor...$(NC)"
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
	@echo "$(GREEN)✅ Cluster hazır$(NC)"
	@echo "$(YELLOW)⏳ Cluster'ın tamamen hazır olması bekleniyor...$(NC)"
	@sleep 10
	@kubectl wait --for=condition=ready nodes --all --timeout=60s || true

# Deployment
deploy: ## Tüm uygulamaları deploy et
	@echo "$(GREEN)📦 Uygulamalar deploy ediliyor...$(NC)"
	@bash scripts/setup.sh
	@echo "$(GREEN)✅ Deployment tamamlandı$(NC)"

# Monitoring komutları
status: ## Sistem durumunu göster
	@echo "$(GREEN)📊 Sistem Durumu:$(NC)"
	@echo ""
	@echo "Cluster:"
	@k3d cluster list | grep $(CLUSTER_NAME) || echo "Cluster bulunamadı"
	@echo ""
	@echo "Pods ($(NAMESPACE) namespace):"
	@kubectl get pods -n $(NAMESPACE) 2>/dev/null || echo "Namespace bulunamadı"
	@echo ""
	@echo "Services:"
	@kubectl get svc -n $(NAMESPACE) 2>/dev/null || true
	@echo ""
	@echo "HPA:"
	@kubectl get hpa -n $(NAMESPACE) 2>/dev/null || true

logs: ## Tüm pod loglarını göster
	@echo "$(GREEN)📜 Pod logları:$(NC)"
	@kubectl logs -n $(NAMESPACE) -l app=api --tail=50 || true
	@echo "---"
	@kubectl logs -n $(NAMESPACE) -l app=postgres --tail=50 || true

watch: ## Pod durumlarını canlı izle
	@watch -n 2 "kubectl get pods -n $(NAMESPACE) && echo '---' && kubectl get hpa -n $(NAMESPACE)"

# Yardımcı komutlar
check: ## Bağımlılıkları kontrol et
	@bash scripts/check-deps.sh

shell: ## API pod'una shell erişimi
	@kubectl exec -it -n $(NAMESPACE) $$(kubectl get pod -n $(NAMESPACE) -l app=api -o jsonpath="{.items[0].metadata.name}") -- /bin/bash

db-shell: ## Database pod'una shell erişimi
	@kubectl exec -it -n $(NAMESPACE) $$(kubectl get pod -n $(NAMESPACE) -l app=postgres -o jsonpath="{.items[0].metadata.name}") -- psql -U postgres -d testdb

port-forward: ## Manuel port forwarding
	@echo "$(GREEN)🔌 Port forwarding başlatılıyor...$(NC)"
	@kubectl port-forward -n $(NAMESPACE) svc/api-service 8080:80 &
	@kubectl port-forward -n $(NAMESPACE) svc/locust-service 8089:8089 &
	@kubectl port-forward -n $(NAMESPACE) svc/grafana 3000:3000 &
	@kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard 8001:443 &

# Test komutları
test-api: ## API'yi test et
	@echo "$(GREEN)🧪 API test ediliyor...$(NC)"
	@curl -s http://localhost:8080/health | jq . || echo "API erişilemiyor"
	@curl -s http://localhost:8080/docs | head -n 5 || true

load-test: ## Basit load test başlat
	@echo "$(GREEN)🔥 Load test başlatılıyor...$(NC)"
	@echo "Locust UI: http://localhost:8089"
	@if command -v open >/dev/null 2>&1; then \
		open http://localhost:8089; \
	elif command -v xdg-open >/dev/null 2>&1; then \
		xdg-open http://localhost:8089; \
	else \
		echo "Browser'ı manuel olarak açın: http://localhost:8089"; \
	fi

# Build komutları
build-images: ## Docker image'lerini build et
	@echo "$(GREEN)🐳 Docker image'leri build ediliyor...$(NC)"
	@docker build -t k8s-test-lab/api:latest ./api
	@docker build -t k8s-test-lab/locust:latest ./load-test
	@k3d image import k8s-test-lab/api:latest -c $(CLUSTER_NAME)
	@k3d image import k8s-test-lab/locust:latest -c $(CLUSTER_NAME)

# Docker Compose komutları
docker-up: ## Docker Compose ile servisleri başlat
	@echo "$(GREEN)🐳 Docker Compose servisleri başlatılıyor...$(NC)"
	@docker-compose up -d
	@echo "$(GREEN)✅ Docker Compose hazır$(NC)"
	@echo ""
	@echo "Docker Compose Portları:"
	@echo "  API: http://localhost:18000"
	@echo "  Locust: http://localhost:18089"
	@echo "  Grafana: http://localhost:13000"
	@echo "  Prometheus: http://localhost:19090"

docker-down: ## Docker Compose servislerini durdur
	@echo "$(YELLOW)🛑 Docker Compose servisleri durduruluyor...$(NC)"
	@docker-compose down
	@echo "$(GREEN)✅ Docker Compose durduruldu$(NC)"

docker-logs: ## Docker Compose loglarını göster
	@docker-compose logs -f

# Yardımcı fonksiyonlar
wait-ready: ## Tüm pod'ların hazır olmasını bekle
	@echo "$(YELLOW)⏳ Pod'lar hazır olana kadar bekleniyor...$(NC)"
	@bash scripts/wait-for-ready.sh

show-urls: ## Erişim URL'lerini göster
	@echo ""
	@echo "$(GREEN)🔗 Erişim Noktaları:$(NC)"
	@echo ""
	@echo "  API:                http://localhost:8080"
	@echo "  API Docs:           http://localhost:8080/docs"
	@echo "  Locust UI:          http://localhost:8089"
	@echo "  Grafana:            http://localhost:3000 (admin/admin)"
	@echo "  Prometheus:         http://localhost:9090"
	@echo "  K8s Dashboard:      http://localhost:8001"
	@echo ""
	@echo "$(YELLOW)💡 İpucu: 'make load-test' ile test başlatın$(NC)"

# Hata ayıklama
debug: ## Debug bilgilerini göster
	@echo "$(YELLOW)🔍 Debug bilgileri:$(NC)"
	@echo "Cluster: $(CLUSTER_NAME)"
	@echo "Namespace: $(NAMESPACE)"
	@echo "Kubeconfig: $(KUBECONFIG)"
	@echo ""
	@kubectl cluster-info
	@echo ""
	@kubectl get nodes
	@echo ""
	@docker ps --filter "label=app=k8s-test-lab"

debug-pods: ## Pod hatalarını göster
	@echo "$(YELLOW)🔍 Pod durumları:$(NC)"
	@kubectl get pods -n $(NAMESPACE) -o wide
	@echo ""
	@echo "$(YELLOW)📜 Hatalı pod'lar:$(NC)"
	@kubectl get pods -n $(NAMESPACE) --field-selector=status.phase!=Running,status.phase!=Succeeded
	@echo ""
	@echo "$(YELLOW)📋 Pod olayları:$(NC)"
	@kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp' | tail -20

troubleshoot: ## Sorun giderme bilgileri
	@echo "$(YELLOW)🔍 Sorun giderme bilgileri:$(NC)"
	@echo ""
	@echo "1. Pod durumları:"
	@kubectl get pods -n $(NAMESPACE) -o wide
	@echo ""
	@echo "2. Pod describe (API):"
	@kubectl describe pod -l app=api -n $(NAMESPACE) | grep -A 10 "Events:"
	@echo ""
	@echo "3. Pod logları (API):"
	@kubectl logs -l app=api -n $(NAMESPACE) --tail=20 || echo "Log yok"
	@echo ""
	@echo "4. Docker images:"
	@docker images | grep k8s-test-lab || echo "Local image bulunamadı"
	@echo ""
	@echo "5. k3d images:"
	@docker exec k3d-$(CLUSTER_NAME)-server-0 crictl images | grep k8s-test-lab || echo "k3d'de image bulunamadı"

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