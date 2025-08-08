from locust import HttpUser, task, between, events
import random
from datetime import datetime
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class MinimalApiUser(HttpUser):
    """User hitting minimal Go API endpoints"""
    wait_time = between(0.5, 2)

    @task(5)
    def health(self):
        with self.client.get("/health", catch_response=True) as r:
            if r.status_code == 200:
                r.success()
            else:
                r.failure(f"health {r.status_code}")

    @task(5)
    def stats(self):
        self.client.get("/stats")

    @task(8)
    def cpu(self):
        iterations = random.randint(500000, 1500000)
        with self.client.post(f"/cpu-intensive?iterations={iterations}", name="/cpu-intensive", catch_response=True, timeout=30) as r:
            if r.status_code == 200:
                r.success()
            else:
                r.failure(f"cpu {r.status_code}")

    @task(3)
    def mem(self):
        size_mb = random.randint(5, 20)
        self.client.post(f"/memory-intensive?size_mb={size_mb}", name="/memory-intensive", timeout=15)

    @task(4)
    def delay(self):
        delay = random.uniform(0.2, 1.5)
        self.client.post(f"/simulate-delay?delay_seconds={delay}", name="/simulate-delay", timeout=10)

@events.test_start.add_listener
def on_start(environment, **kwargs):
    logger.info(f"Load test started at {datetime.now()}")

@events.test_stop.add_listener
def on_stop(environment, **kwargs):
    logger.info("Load test finished!")
    logger.info(f"Requests: {environment.stats.total.num_requests}")
    logger.info(f"Failures: {environment.stats.total.num_failures}")
    logger.info(f"Avg response time: {environment.stats.total.avg_response_time}ms")