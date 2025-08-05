"""
Load test configuration
"""

import os

# Target host configuration
TARGET_HOST = os.getenv("TARGET_HOST", "http://api-service")

# Test scenarios
SCENARIOS = {
    "normal": {
        "users": 50,
        "spawn_rate": 2,
        "duration": "5m"
    },
    "stress": {
        "users": 500,
        "spawn_rate": 10,
        "duration": "10m"
    },
    "spike": {
        "users": 1000,
        "spawn_rate": 100,
        "duration": "2m"
    },
    "endurance": {
        "users": 100,
        "spawn_rate": 5,
        "duration": "30m"
    }
}

# Performance thresholds
THRESHOLDS = {
    "response_time_95": 500,  # 95th percentile should be under 500ms
    "response_time_99": 1000,  # 99th percentile should be under 1s
    "failure_rate": 0.01,  # Less than 1% failure rate
    "rps": 100  # At least 100 requests per second
}

# Monitoring settings
STATS_INTERVAL = 5  # seconds
CSV_STATS = os.getenv("LOCUST_CSV", "locust_stats")
HTML_REPORT = os.getenv("LOCUST_HTML", "locust_report.html")

# Distributed mode settings
MASTER_HOST = os.getenv("LOCUST_MASTER_HOST", "locust-master")
MASTER_PORT = int(os.getenv("LOCUST_MASTER_PORT", "5557"))

# Custom headers
HEADERS = {
    "User-Agent": "Kubernetes-Test-Lab-Locust",
    "X-Test-Type": "Load-Test"
}