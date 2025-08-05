#!/bin/bash

# Multi-platform otomatik bağımlılık kurulum script'i

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

echo -e "${BLUE}🚀 Kubernetes Test Lab - Otomatik Kurulum${NC}"
echo -e "Platform: ${GREEN}$OS_TYPE${NC} $([ "$OS_TYPE" == "linux" ] && echo "($DISTRO)")"
echo ""

# Fonksiyon: Komut kurulu mu kontrol et
is_installed() {
    command -v "$1" &> /dev/null
}

# macOS kurulum fonksiyonu
install_macos() {
    echo -e "${BLUE}🍎 macOS için kurulum başlıyor...${NC}"
    
    # Homebrew kontrolü
    if ! is_installed brew; then
        echo "Homebrew kuruluyor..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    # Docker Desktop
    if ! is_installed docker; then
        echo "Docker Desktop kurun: https://docs.docker.com/desktop/install/mac-install/"
        echo "Kurulum sonrası Docker Desktop'ı başlatın ve bu script'i tekrar çalıştırın."
        exit 1
    fi
    
    # kubectl
    if ! is_installed kubectl; then
        echo "kubectl kuruluyor..."
        brew install kubectl
    fi
    
    # k3d
    if ! is_installed k3d; then
        echo "k3d kuruluyor..."
        brew install k3d
    fi
    
    # jq
    if ! is_installed jq; then
        echo "jq kuruluyor..."
        brew install jq
    fi
    
    # make
    if ! is_installed make; then
        echo "Xcode Command Line Tools kuruluyor..."
        xcode-select --install
    fi
}

# Linux kurulum fonksiyonu
install_linux() {
    echo -e "${BLUE}🐧 Linux için kurulum başlıyor...${NC}"
    
    # Update package list
    echo "Paket listesi güncelleniyor..."
    sudo apt update
    
    # Docker
    if ! is_installed docker; then
        echo "Docker kuruluyor..."
        sudo apt install -y docker.io docker-compose
        
        # Docker daemon'u başlat
        sudo systemctl enable --now docker
        
        # Kullanıcıyı docker grubuna ekle
        sudo usermod -aG docker $USER
        echo -e "${YELLOW}⚠️  Docker grubu için logout/login gerekli!${NC}"
    fi
    
    # kubectl
    if ! is_installed kubectl; then
        echo "kubectl kuruluyor..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
    fi
    
    # k3d
    if ! is_installed k3d; then
        echo "k3d kuruluyor..."
        curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
    fi
    
    # jq
    if ! is_installed jq; then
        echo "jq kuruluyor..."
        sudo apt install -y jq
    fi
    
    # make ve diğer build tools
    if ! is_installed make; then
        echo "Build tools kuruluyor..."
        sudo apt install -y build-essential
    fi
    
    # curl
    if ! is_installed curl; then
        echo "curl kuruluyor..."
        sudo apt install -y curl
    fi
    
    # lsof (port kontrolü için)
    if ! is_installed lsof; then
        echo "lsof kuruluyor..."
        sudo apt install -y lsof
    fi
}

# Ana kurulum akışı
echo -e "${YELLOW}⚠️  Bu script sistem değişiklikleri yapacak. Devam etmek istiyor musunuz? (y/N)${NC}"
read -r response
if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Kurulum iptal edildi."
    exit 0
fi

# Platform'a göre kurulum
if [ "$OS_TYPE" == "macos" ]; then
    install_macos
else
    install_linux
fi

echo ""
echo -e "${GREEN}✅ Kurulum tamamlandı!${NC}"
echo ""

# Kontrol
echo "Kurulum kontrolü yapılıyor..."
bash scripts/check-deps.sh

# Linux için özel notlar
if [ "$OS_TYPE" == "linux" ]; then
    echo ""
    echo -e "${YELLOW}📝 Önemli Linux Notları:${NC}"
    echo "1. Docker grubu için logout/login yapmanız gerekebilir"
    echo "2. Alternatif: 'newgrp docker' komutu ile grup değişikliğini aktif edin"
    echo "3. Docker daemon kontrolü: 'sudo systemctl status docker'"
fi

echo ""
echo -e "${GREEN}🚀 Artık 'make start' ile sistemi başlatabilirsiniz!${NC}"