#!/bin/bash

# Pod'ların hazır olmasını bekleyen script

set -e

NAMESPACE="test-lab"
TIMEOUT=300
INTERVAL=5

# Renkler
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}⏳ Pod'ların hazır olması bekleniyor...${NC}"

# Fonksiyon: Pod durumunu kontrol et
check_pod_ready() {
    local label=$1
    local app_name=$2
    
    # Pod var mı kontrol et
    local pod_count=$(kubectl get pods -n $NAMESPACE -l $label --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "$pod_count" -eq "0" ]; then
        echo -e "${RED}✗${NC} $app_name pod'u bulunamadı"
        return 1
    fi
    
    # Pod ready mi kontrol et
    local ready_pods=$(kubectl get pods -n $NAMESPACE -l $label -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -o "True" | wc -l | tr -d ' ')
    
    if [ "$ready_pods" -eq "$pod_count" ] && [ "$pod_count" -gt "0" ]; then
        echo -e "${GREEN}✓${NC} $app_name hazır ($ready_pods/$pod_count pod)"
        return 0
    else
        echo -e "${YELLOW}⏳${NC} $app_name bekleniyor ($ready_pods/$pod_count pod hazır)"
        return 1
    fi
}

# Fonksiyon: Service endpoint kontrolü
check_service_endpoints() {
    local service=$1
    local endpoints=$(kubectl get endpoints $service -n $NAMESPACE -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)
    
    if [ $endpoints -gt 0 ]; then
        return 0
    else
        return 1
    fi
}

# Ana bekleme döngüsü
start_time=$(date +%s)
all_ready=false

while [ $(($(date +%s) - start_time)) -lt $TIMEOUT ]; do
    echo ""
    echo "🔍 Durum kontrolü yapılıyor..."
    
    # Pod kontrollerini yap
    postgres_ready=false
    api_ready=false
    locust_ready=false
    prometheus_ready=false
    grafana_ready=false
    
    # PostgreSQL
    if check_pod_ready "app=postgres" "PostgreSQL"; then
        postgres_ready=true
    fi
    
    # API (sadece PostgreSQL hazırsa)
    if [ "$postgres_ready" = true ]; then
        if check_pod_ready "app=api" "API"; then
            api_ready=true
        fi
    fi
    
    # Locust
    if check_pod_ready "app=locust" "Locust"; then
        locust_ready=true
    fi
    
    # Prometheus
    if check_pod_ready "app=prometheus" "Prometheus"; then
        prometheus_ready=true
    fi
    
    # Grafana
    if check_pod_ready "app=grafana" "Grafana"; then
        grafana_ready=true
    fi
    
    # Metrics Server kontrolü
    metrics_ready=false
    if kubectl get deployment metrics-server -n kube-system &>/dev/null; then
        metrics_status=$(kubectl get deployment metrics-server -n kube-system -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
        if [ "$metrics_status" = "True" ]; then
            echo -e "${GREEN}✓${NC} Metrics Server hazır"
            metrics_ready=true
        else
            echo -e "${YELLOW}⏳${NC} Metrics Server bekleniyor"
        fi
    fi
    
    # Tüm servisler hazır mı?
    if [ "$postgres_ready" = true ] && \
       [ "$api_ready" = true ] && \
       [ "$locust_ready" = true ] && \
       [ "$prometheus_ready" = true ] && \
       [ "$grafana_ready" = true ] && \
       [ "$metrics_ready" = true ]; then
        all_ready=true
        break
    fi
    
    # İlerleme göster
    elapsed=$(($(date +%s) - start_time))
    remaining=$((TIMEOUT - elapsed))
    echo -e "${YELLOW}⏱️  Geçen süre: ${elapsed}s / Kalan: ${remaining}s${NC}"
    
    sleep $INTERVAL
done

# Sonuç
if [ "$all_ready" = true ]; then
    echo ""
    echo -e "${GREEN}✅ Tüm servisler hazır!${NC}"
    
    # Service endpoint kontrolü
    echo ""
    echo "🔗 Service endpoint kontrolü..."
    
    services=("api-service" "postgres-service" "locust-service" "prometheus" "grafana")
    for service in "${services[@]}"; do
        if check_service_endpoints $service; then
            echo -e "${GREEN}✓${NC} $service endpoint'leri aktif"
        else
            echo -e "${YELLOW}⚠${NC} $service endpoint'leri bekleniyor"
        fi
    done
    
    # HPA durumu
    echo ""
    echo "📊 HPA durumu:"
    kubectl get hpa -n $NAMESPACE 2>/dev/null || echo "HPA henüz hazır değil"
    
    # Özet bilgi
    echo ""
    echo -e "${GREEN}📋 Özet:${NC}"
    kubectl get pods -n $NAMESPACE
    
    exit 0
else
    echo ""
    echo -e "${RED}❌ Timeout! Bazı servisler hazır değil.${NC}"
    echo ""
    echo "🔍 Pod durumları:"
    kubectl get pods -n $NAMESPACE
    echo ""
    echo "📜 Sorunlu pod logları:"
    
    # Hazır olmayan pod'ların loglarını göster
    kubectl get pods -n $NAMESPACE --no-headers | grep -v "Running\|Completed" | awk '{print $1}' | while read pod; do
        echo -e "${YELLOW}Log: $pod${NC}"
        kubectl logs $pod -n $NAMESPACE --tail=20 2>/dev/null || true
        echo "---"
    done
    
    exit 1
fi