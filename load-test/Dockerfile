FROM python:3.11-slim

# Çalışma dizini
WORKDIR /app

# Python bağımlılıkları
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Uygulama kodları
COPY . .

# Locust web UI portu
EXPOSE 8089

# Locust worker portu (distributed mode için)
EXPOSE 5557

# Kullanıcı oluştur
RUN useradd -m -u 1000 locust && chown -R locust:locust /app
USER locust

# Başlatma komutu
CMD ["locust", "--host", "http://api-service"]