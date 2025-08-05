#!/bin/bash

# Multi-platform bağımlılık kontrol script'i

set -e

# Renkler
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# OS Detection
OS_TYPE=""
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_TYPE="linux"
    DISTRO=$(lsb_release -si 2>/dev/null || cat /etc/os-release | grep "^ID=" | cut -d= -f2 | tr -d '"' 2>/dev/null || echo "Unknown")
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macos"
else
    echo -e "${RED}❌ Desteklenmeyen işletim sistemi: $OSTYPE${NC}"
    exit 1
fi

echo "🔍 Bağımlılıklar kontrol ediliyor..."
echo -e "🖥️  Platform: ${BLUE}$OS_TYPE${NC} $([ "$OS_TYPE" == "linux" ] && echo "($DISTRO)")"
echo ""

# Fonksiyon: Komut varlığını kontrol et
check_command() {
    local cmd=$1
    local install_msg_mac=$2
    local install_msg_linux=$3
    
    if command -v $cmd &> /dev/null; then
        echo -e "${GREEN}✓${NC} $cmd kurulu"
        return 0
    else
        echo -e "${RED}✗${NC} $cmd kurulu değil"
        if [ "$OS_TYPE" == "macos" ]; then
            echo -e "  ${YELLOW}Kurulum:${NC} $install_msg_mac"
        else
            echo -e "  ${YELLOW}Kurulum:${NC} $install_msg_linux"
        fi
        return 1
    fi
}

# Fonksiyon: Docker çalışıyor mu kontrol et
check_docker_running() {
    if docker info &> /dev/null; then
        echo -e "${GREEN}✓${NC} Docker çalışıyor"
        return 0
    else
        echo -e "${RED}✗${NC} Docker çalışmıyor"
        if [ "$OS_TYPE" == "macos" ]; then
            echo -e "  ${YELLOW}Çözüm:${NC} Docker Desktop'ı başlatın"
        else
            echo -e "  ${YELLOW}Çözüm:${NC} sudo systemctl start docker"
        fi
        return 1
    fi
}

# Fonksiyon: Docker bellek kontrolü
check_docker_memory() {
    if [[ "$OS_TYPE" == "macos" ]]; then
        # macOS için Docker Desktop bellek kontrolü
        local memory=$(docker system info --format '{{.MemTotal}}' 2>/dev/null || echo "0")
        local memory_gb=$((memory / 1073741824))
        
        if [ $memory_gb -ge 8 ]; then
            echo -e "${GREEN}✓${NC} Docker belleği yeterli (${memory_gb}GB)"
            return 0
        else
            echo -e "${YELLOW}⚠${NC} Docker belleği düşük (${memory_gb}GB)"
            echo -e "  ${YELLOW}Öneri:${NC} Docker Desktop > Settings > Resources'dan en az 8GB ayırın"
            return 0
        fi
    else
        # Linux için sistem bellek kontrolü
        local total_mem=$(free -g | awk '/^Mem:/{print $2}')
        if [ $total_mem -ge 8 ]; then
            echo -e "${GREEN}✓${NC} Sistem belleği yeterli (${total_mem}GB)"
        else
            echo -e "${YELLOW}⚠${NC} Sistem belleği düşük (${total_mem}GB)"
            echo -e "  ${YELLOW}Öneri:${NC} En az 8GB RAM önerilir"
        fi
        return 0
    fi
}

# Fonksiyon: Port kontrolü
check_port() {
    local port=$1
    if lsof -i :$port &> /dev/null || netstat -tln 2>/dev/null | grep -q ":$port "; then
        echo -e "${YELLOW}⚠${NC} Port $port kullanımda"
        echo -e "  ${YELLOW}Çözüm:${NC} lsof -i :$port veya sudo netstat -tlnp | grep :$port"
        return 1
    else
        return 0
    fi
}

# Ana kontroller
errors=0

# 1. Docker kontrolü
if ! check_command "docker" \
    "https://docs.docker.com/desktop/install/mac-install/" \
    "sudo apt update && sudo apt install -y docker.io docker-compose"; then
    ((errors++))
fi

if ! check_docker_running; then
    ((errors++))
fi

check_docker_memory

# 2. kubectl kontrolü
if ! check_command "kubectl" \
    "brew install kubectl" \
    "curl -LO \"https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\" && chmod +x kubectl && sudo mv kubectl /usr/local/bin/"; then
    ((errors++))
fi

# 3. k3d kontrolü
if ! check_command "k3d" \
    "brew install k3d" \
    "curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash"; then
    ((errors++))
fi

# 4. jq kontrolü (opsiyonel ama faydalı)
if ! check_command "jq" \
    "brew install jq" \
    "sudo apt install -y jq"; then
    echo -e "  ${YELLOW}Not:${NC} jq opsiyonel, ancak JSON parsing için faydalı"
fi

# 5. curl kontrolü
if ! check_command "curl" \
    "brew install curl" \
    "sudo apt install -y curl"; then
    ((errors++))
fi

# 6. make kontrolü
if ! check_command "make" \
    "xcode-select --install" \
    "sudo apt install -y build-essential"; then
    ((errors++))
fi

# 7. Port kontrolü
echo ""
echo "📡 Port kontrolü yapılıyor..."
ports=(8080 8089 3000 9090 8001)
port_issues=0

for port in "${ports[@]}"; do
    if ! check_port $port; then
        ((port_issues++))
    fi
done

if [ $port_issues -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Tüm portlar uygun"
fi

# 8. Cluster kontrolü
echo ""
echo "☸️  Mevcut k3d cluster kontrolü..."
if k3d cluster list 2>/dev/null | grep -q "k8s-test-lab"; then
    echo -e "${YELLOW}⚠${NC} 'k8s-test-lab' cluster'ı zaten mevcut"
    echo -e "  ${YELLOW}İpucu:${NC} 'make clean' ile temizleyebilirsiniz"
fi

# Linux-specific Docker group check
if [ "$OS_TYPE" == "linux" ]; then
    if ! groups $USER | grep -q docker; then
        echo ""
        echo -e "${YELLOW}⚠️  Docker grup üyeliği:${NC}"
        echo "  Kullanıcınız docker grubunda değil."
        echo "  Eklemek için: sudo usermod -aG docker $USER"
        echo "  Sonra logout/login yapın."
    fi
fi

# Sonuç
echo ""
if [ $errors -eq 0 ]; then
    echo -e "${GREEN}✅ Tüm bağımlılıklar hazır!${NC}"
    
    # Platform-specific öneriler
    if [ "$OS_TYPE" == "linux" ]; then
        echo ""
        echo -e "${BLUE}📝 Linux için öneriler:${NC}"
        echo "  • Docker daemon başlatılmış olmalı: sudo systemctl enable --now docker"
        echo "  • Firewall kurallarını kontrol edin"
    elif [ "$OS_TYPE" == "macos" ]; then
        echo ""
        echo -e "${BLUE}📝 macOS için öneriler:${NC}"
        echo "  • Docker Desktop uygulamasının açık olduğundan emin olun"
    fi
    
    exit 0
else
    echo -e "${RED}❌ $errors bağımlılık eksik!${NC}"
    echo -e "${YELLOW}Eksik bağımlılıkları kurun ve tekrar deneyin.${NC}"
    exit 1
fi