#!/bin/bash

# Sistemi temizleyen script

set -e

CLUSTER_NAME="k8s-test-lab"
NAMESPACE="test-lab"

# Renkler
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🧹 Temizlik işlemi başlatılıyor...${NC}"

# 1. Port forward process'lerini temizle
echo -e "${GREEN}🔌 Port forward process'leri temizleniyor...${NC}"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux için
    pkill -f "kubectl port-forward" 2>/dev/null || true
else
    # macOS için
    pkill -f "kubectl port-forward" 2>/dev/null || true
fi

# 2. Namespace'i sil (tüm kaynakları silecek)
echo -e "${GREEN}📁 Namespace siliniyor...${NC}"
kubectl delete namespace $NAMESPACE --ignore-not-found=true --timeout=60s 2>/dev/null || true

# 3. Kubernetes Dashboard'u temizle
echo -e "${GREEN}🎨 Kubernetes Dashboard temizleniyor...${NC}"
kubectl delete namespace kubernetes-dashboard --ignore-not-found=true --timeout=60s 2>/dev/null || true

# 4. Metrics Server'ı temizle
echo -e "${GREEN}📈 Metrics Server temizleniyor...${NC}"
kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml 2>/dev/null || true

# 5. k3d cluster'ı kontrol et ve sor
if k3d cluster list | grep -q $CLUSTER_NAME; then
    echo ""
    echo -e "${YELLOW}⚠️  k3d cluster'ı bulundu: $CLUSTER_NAME${NC}"
    read -p "Cluster'ı da silmek istiyor musunuz? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}🗑️  k3d cluster siliniyor...${NC}"
        k3d cluster delete $CLUSTER_NAME
        
        # Docker image'lerini temizle
        echo -e "${GREEN}🐳 Docker image'leri temizleniyor...${NC}"
        docker rmi k8s-test-lab/api:latest 2>/dev/null || true
        docker rmi k8s-test-lab/locust:latest 2>/dev/null || true
    else
        echo -e "${GREEN}✓ Cluster korundu${NC}"
    fi
fi

# 6. Geçici dosyaları temizle
echo -e "${GREEN}📄 Geçici dosyalar temizleniyor...${NC}"
rm -f /tmp/k8s-test-lab-* 2>/dev/null || true

# 7. Docker temizliği (opsiyonel)
echo ""
read -p "Docker temizliği yapmak ister misiniz? (dangling images, volumes) (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}🐳 Docker temizliği yapılıyor...${NC}"
    docker system prune -f
    docker volume prune -f
fi

# 8. Özet rapor
echo ""
echo -e "${GREEN}📋 Temizlik Özeti:${NC}"
echo "  ✓ Port forward process'leri temizlendi"
echo "  ✓ Kubernetes kaynakları temizlendi"

if k3d cluster list | grep -q $CLUSTER_NAME; then
    echo -e "  ${YELLOW}⚠ k3d cluster hala mevcut${NC}"
else
    echo "  ✓ k3d cluster temizlendi"
fi

# Kalan Docker container'ları kontrol et
remaining_containers=$(docker ps -a --filter "label=app=k8s-test-lab" --format "{{.Names}}" | wc -l)
if [ $remaining_containers -gt 0 ]; then
    echo -e "  ${YELLOW}⚠ $remaining_containers Docker container hala mevcut${NC}"
else
    echo "  ✓ Docker container'ları temizlendi"
fi

echo ""
echo -e "${GREEN}✅ Temizlik tamamlandı!${NC}"