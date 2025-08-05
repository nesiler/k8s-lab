# Kubernetes Test Lab 🚀

MacBook Pro M3 üzerinde Kubernetes cluster'ı kurarak, auto-scaling, monitoring ve load testing yapabileceğiniz komple bir test ortamı.

## 🎯 Özellikler

- ✅ Tek komutla kurulum (`make start`)
- ✅ Kubernetes cluster (k3d)
- ✅ Auto-scaling (HPA) 
- ✅ Load Testing (Locust)
- ✅ Monitoring (Prometheus + Grafana)
- ✅ Kubernetes Dashboard
- ✅ PostgreSQL veritabanı
- ✅ FastAPI backend
- ✅ Gerçek zamanlı metrikler

## 📋 Gereksinimler

### 🖥️ Desteklenen Platformlar
- macOS (Intel & Apple Silicon)
- Ubuntu/Debian Linux
- WSL2 (Windows Subsystem for Linux)

### 🛠️ Gerekli Yazılımlar
- Docker (Desktop for Mac veya Docker Engine for Linux)
- kubectl
- k3d
- make
- curl
- jq (opsiyonel)

### 🚀 Otomatik Kurulum

**Tüm bağımlılıkları otomatik kurmak için:**
```bash
chmod +x install-dependencies.sh
./install-dependencies.sh
```

**Manuel kontrol için:**
```bash
bash scripts/check-deps.sh
```

## 🚀 Hızlı Başlangıç

```bash
# Tüm sistemi başlat
make start

# Durumu kontrol et
make status

# Sistemi durdur
make stop

# Temizlik yap
make clean
```

## 🔗 Erişim Noktaları

Sistem başladıktan sonra:

- **API**: http://localhost:8080
- **Locust UI**: http://localhost:8089
- **Grafana**: http://localhost:3000 (admin/admin)
- **Kubernetes Dashboard**: http://localhost:8001
- **Prometheus**: http://localhost:9090

## 📊 Load Testing

1. Locust UI'a gidin: http://localhost:8089
2. User sayısını ve spawn rate'i belirleyin
3. "Start swarming" butonuna tıklayın
4. Grafana'dan pod scaling'i izleyin

## 🏗️ Mimari

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

## 📝 Komutlar

```bash
# Kurulum kontrolü
make check

# Sadece k3d cluster başlat
make cluster

# Sadece uygulamaları deploy et
make deploy

# Logları görüntüle
make logs

# Pod durumlarını izle
make watch

# Sisteme shell erişimi
make shell
```

## 🧪 Test Senaryoları

### 1. Ramp-up Test
- Yavaş yavaş artan kullanıcı sayısı
- HPA'nın tepkisini gözlemleme

### 2. Spike Test  
- Ani yük artışı
- Sistem dayanıklılığı testi

### 3. Sustained Load
- Sabit yük altında performans
- Memory leak kontrolü

## 🛠️ Troubleshooting

### Port çakışması
```bash
# Kullanılan portları kontrol et
lsof -i :8080,8089,3000,9090,8001

# Processları sonlandır
kill -9 <PID>
```

### k3d cluster sorunları
```bash
# Cluster'ı yeniden başlat
make clean
make start
```

### Docker kaynak limitleri
Docker Desktop > Settings > Resources:
- Memory: En az 8GB
- CPU: En az 4 cores

## 📚 Detaylı Dokümantasyon

- [API Dokümantasyonu](http://localhost:8080/docs)
- [Kubernetes Manifestleri](./k8s/)
- [Load Test Senaryoları](./load-test/)

## 🤝 Katkıda Bulunma

1. Fork yapın
2. Feature branch oluşturun
3. Değişikliklerinizi commit edin
4. Pull request açın

## 📄 Lisans

MIT License