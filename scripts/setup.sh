#!/bin/bash

# Kubernetes ortamını kuran ana script

set -e

# Değişkenler
NAMESPACE="test-lab"
TIMEOUT=300

# Renkler
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Kubernetes Test Lab kurulumu başlıyor...${NC}"

# 1. Namespace oluştur
echo -e "${GREEN}📁 Namespace oluşturuluyor...${NC}"
kubectl apply -f k8s/namespace.yaml

# 2. ConfigMap'leri oluştur
echo -e "${GREEN}🗂️  ConfigMap'ler oluşturuluyor...${NC}"
kubectl apply -f k8s/configmap.yaml

# 3. Database kurulumu
echo -e "${GREEN}🐘 PostgreSQL kurulumu...${NC}"
kubectl apply -f k8s/database/pvc.yaml
kubectl apply -f k8s/database/configmap.yaml
kubectl apply -f k8s/database/deployment.yaml
kubectl apply -f k8s/database/service.yaml

# Database'in hazır olmasını bekle
echo -e "${YELLOW}⏳ PostgreSQL başlatılıyor...${NC}"
# Pod'un oluşmasını bekle
for i in {1..30}; do
    if kubectl get pod -l app=postgres -n $NAMESPACE 2>/dev/null | grep -q postgres; then
        echo -e "${GREEN}✓ PostgreSQL pod'u oluşturuldu${NC}"
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

# Pod'un ready olmasını bekle
kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=${TIMEOUT}s || {
    echo -e "${RED}❌ PostgreSQL başlatılamadı${NC}"
    echo "Pod durumu:"
    kubectl get pods -l app=postgres -n $NAMESPACE
    echo "Pod logları:"
    kubectl logs -l app=postgres -n $NAMESPACE --tail=50
    exit 1
}

# 4. API kurulumu
echo -e "${GREEN}🔧 API uygulaması kurulumu...${NC}"

# Önce Docker image'ini build et ve import et
echo -e "${YELLOW}🐳 API Docker image build ediliyor...${NC}"
docker build -t k8s-test-lab/api:latest ./api || {
    echo -e "${RED}❌ API image build başarısız${NC}"
    exit 1
}

echo -e "${YELLOW}📦 Image k3d cluster'a import ediliyor...${NC}"
k3d image import k8s-test-lab/api:latest -c k8s-test-lab || {
    echo -e "${RED}❌ API image import başarısız${NC}"
    exit 1
}

kubectl apply -f k8s/api/configmap.yaml
kubectl apply -f k8s/api/deployment.yaml
kubectl apply -f k8s/api/service.yaml
kubectl apply -f k8s/api/hpa.yaml

# 5. Load Test kurulumu
echo -e "${GREEN}🔥 Locust load tester kurulumu...${NC}"

# Locust Docker image'ini build et ve import et
echo -e "${YELLOW}🐳 Locust Docker image build ediliyor...${NC}"
docker build -t k8s-test-lab/locust:latest ./load-test || {
    echo -e "${RED}❌ Locust image build başarısız${NC}"
    exit 1
}

echo -e "${YELLOW}📦 Image k3d cluster'a import ediliyor...${NC}"
k3d image import k8s-test-lab/locust:latest -c k8s-test-lab || {
    echo -e "${RED}❌ Locust image import başarısız${NC}"
    exit 1
}

kubectl apply -f k8s/load-test/configmap.yaml
kubectl apply -f k8s/load-test/deployment.yaml
kubectl apply -f k8s/load-test/service.yaml

# 6. Monitoring kurulumu
echo -e "${GREEN}📊 Monitoring stack kurulumu...${NC}"

# Prometheus
echo -e "${BLUE}  → Prometheus kuruluyor...${NC}"
kubectl apply -f k8s/monitoring/prometheus/rbac.yaml
kubectl apply -f k8s/monitoring/prometheus/configmap.yaml
kubectl apply -f k8s/monitoring/prometheus/deployment.yaml
kubectl apply -f k8s/monitoring/prometheus/service.yaml

# Grafana
echo -e "${BLUE}  → Grafana kuruluyor...${NC}"
kubectl apply -f k8s/monitoring/grafana/configmap.yaml
kubectl apply -f k8s/monitoring/grafana/datasource.yaml
kubectl apply -f k8s/monitoring/grafana/deployment.yaml
kubectl apply -f k8s/monitoring/grafana/service.yaml

# Kube-state-metrics
echo -e "${BLUE}  → Kube-state-metrics kuruluyor...${NC}"
kubectl apply -f k8s/monitoring/kube-state-metrics.yaml

# Node-exporter
echo -e "${BLUE}  → Node-exporter kuruluyor...${NC}"
kubectl apply -f k8s/monitoring/node-exporter.yaml

# 7. Kubernetes Dashboard kurulumu
echo -e "${GREEN}🎨 Kubernetes Dashboard kurulumu...${NC}"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Dashboard için ServiceAccount ve token oluştur
kubectl apply -f k8s/dashboard/rbac.yaml
kubectl apply -f k8s/dashboard/service.yaml

# 8. Metrics Server kurulumu (HPA için gerekli)
echo -e "${GREEN}📈 Metrics Server kurulumu...${NC}"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Metrics server için patch (k3d için gerekli)
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-insecure-tls"
  },
  {
    "op": "add", 
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname"
  }
]'

# 9. Port forwarding başlat (arka planda)
echo -e "${GREEN}🔌 Port forwarding başlatılıyor...${NC}"

# Mevcut port-forward process'lerini temizle
pkill -f "kubectl port-forward" || true
sleep 2

# Yeni port-forward'ları başlat
kubectl port-forward -n $NAMESPACE svc/api-service 8080:80 >/dev/null 2>&1 &
kubectl port-forward -n $NAMESPACE svc/locust-service 8089:8089 >/dev/null 2>&1 &
kubectl port-forward -n $NAMESPACE svc/grafana 3000:3000 >/dev/null 2>&1 &
kubectl port-forward -n $NAMESPACE svc/prometheus 9090:9090 >/dev/null 2>&1 &
kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard 8001:443 >/dev/null 2>&1 &

# Dashboard token'ı al ve göster
echo -e "${GREEN}🔑 Dashboard erişim token'ı alınıyor...${NC}"
SECRET_NAME=$(kubectl get serviceaccount dashboard-admin -n kubernetes-dashboard -o jsonpath='{.secrets[0].name}' 2>/dev/null || echo "")

if [ ! -z "$SECRET_NAME" ]; then
    # Platform-specific base64 decode
    if [[ "$OSTYPE" == "darwin"* ]]; then
        TOKEN=$(kubectl get secret $SECRET_NAME -n kubernetes-dashboard -o jsonpath='{.data.token}' | base64 --decode)
    else
        TOKEN=$(kubectl get secret $SECRET_NAME -n kubernetes-dashboard -o jsonpath='{.data.token}' | base64 -d)
    fi
    echo -e "${YELLOW}Dashboard Token:${NC}"
    echo "$TOKEN"
    echo ""
    echo -e "${YELLOW}Token'ı kopyalayın ve Dashboard'a giriş yaparken kullanın${NC}"
fi

echo -e "${GREEN}✅ Kurulum tamamlandı!${NC}"
echo ""
echo -e "${BLUE}Servisler başlatılıyor, lütfen bekleyin...${NC}"