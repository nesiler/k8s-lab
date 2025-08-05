from locust import HttpUser, task, between, events
import random
import json
from datetime import datetime
import logging

# Logging setup
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class KubernetesTestUser(HttpUser):
    """Load test user for Kubernetes Test Lab API"""
    
    # Wait time between requests (1-3 seconds)
    wait_time = between(1, 3)
    
    def on_start(self):
        """Called when a user starts"""
        logger.info(f"User started at {datetime.now()}")
        self.task_ids = []
    
    @task(5)
    def health_check(self):
        """Health check endpoint - yüksek frekans"""
        with self.client.get("/health", catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Health check failed: {response.status_code}")
    
    @task(10)
    def create_task(self):
        """Create a new task"""
        task_data = {
            "title": f"Task {random.randint(1000, 9999)}",
            "description": f"Load test task created at {datetime.now()}",
            "priority": random.randint(1, 5),
            "completed": False
        }
        
        with self.client.post("/tasks", json=task_data, catch_response=True) as response:
            if response.status_code == 200:
                response.success()
                try:
                    task_id = response.json()["id"]
                    self.task_ids.append(task_id)
                    # Keep only last 100 task IDs
                    if len(self.task_ids) > 100:
                        self.task_ids = self.task_ids[-100:]
                except:
                    pass
            else:
                response.failure(f"Create task failed: {response.status_code}")
    
    @task(15)
    def list_tasks(self):
        """List tasks with random filters"""
        params = {
            "skip": random.randint(0, 10),
            "limit": random.randint(10, 50)
        }
        
        # Randomly add completed filter
        if random.random() > 0.5:
            params["completed"] = random.choice([True, False])
        
        self.client.get("/tasks", params=params, name="/tasks?[filtered]")
    
    @task(8)
    def get_task(self):
        """Get a specific task"""
        if self.task_ids:
            task_id = random.choice(self.task_ids)
            self.client.get(f"/tasks/{task_id}", name="/tasks/[id]")
        else:
            # If no tasks created yet, create one
            self.create_task()
    
    @task(5)
    def update_task(self):
        """Update a task"""
        if self.task_ids:
            task_id = random.choice(self.task_ids)
            update_data = {
                "completed": random.choice([True, False]),
                "priority": random.randint(1, 5)
            }
            self.client.put(f"/tasks/{task_id}", json=update_data, name="/tasks/[id]")
    
    @task(2)
    def delete_task(self):
        """Delete a task"""
        if self.task_ids:
            task_id = random.choice(self.task_ids)
            with self.client.delete(f"/tasks/{task_id}", name="/tasks/[id]", catch_response=True) as response:
                if response.status_code in [200, 204]:
                    response.success()
                    self.task_ids.remove(task_id)
                else:
                    response.failure(f"Delete failed: {response.status_code}")
    
    @task(3)
    def get_stats(self):
        """Get statistics"""
        self.client.get("/stats")
    
    @task(2)
    def cpu_intensive(self):
        """CPU intensive task for scaling test"""
        iterations = random.randint(500000, 2000000)
        with self.client.post(
            "/cpu-intensive",
            json={"iterations": iterations},
            catch_response=True,
            timeout=30
        ) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"CPU intensive task failed: {response.status_code}")
    
    @task(1)
    def memory_intensive(self):
        """Memory intensive task"""
        size_mb = random.randint(5, 20)
        self.client.post("/memory-intensive", json={"size_mb": size_mb}, timeout=10)
    
    @task(3)
    def simulate_delay(self):
        """Simulate variable delays"""
        delay = random.uniform(0.5, 2.0)
        self.client.post("/simulate-delay", json={"delay_seconds": delay}, timeout=10)
    
    @task(1)
    def random_error(self):
        """Test error handling"""
        error_rate = random.uniform(0.1, 0.3)
        with self.client.post(
            "/random-error",
            json={"error_rate": error_rate},
            catch_response=True
        ) as response:
            if response.status_code < 400:
                response.success()
            else:
                # Expected errors, mark as success for load testing
                response.success()

class StressTestUser(HttpUser):
    """Aggressive user for stress testing"""
    
    wait_time = between(0.1, 0.5)  # Very short wait times
    
    @task
    def hammer_api(self):
        """Continuously hit the API"""
        endpoints = ["/health", "/tasks", "/stats", "/"]
        endpoint = random.choice(endpoints)
        self.client.get(endpoint)

class SpikeTestUser(HttpUser):
    """User for spike testing"""
    
    wait_time = between(0.5, 1)
    
    def on_start(self):
        """Burst of activity on start"""
        for _ in range(10):
            self.client.get("/health")
            self.client.get("/tasks")
    
    @task
    def normal_activity(self):
        """Normal activity after spike"""
        self.client.get("/tasks")

# Event handlers for monitoring
@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    logger.info("Load test started!")

@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    logger.info("Load test finished!")
    logger.info(f"Requests: {environment.stats.total.num_requests}")
    logger.info(f"Failures: {environment.stats.total.num_failures}")
    logger.info(f"Avg response time: {environment.stats.total.avg_response_time}ms")

# Custom scenarios
class ScenarioUser(HttpUser):
    """User with realistic usage scenarios"""
    
    wait_time = between(2, 5)
    
    def on_start(self):
        self.created_tasks = []
    
    @task(20)
    def browse_tasks(self):
        """Browse and read tasks"""
        # List tasks
        self.client.get("/tasks?limit=20")
        
        # View some details
        if self.created_tasks:
            for _ in range(random.randint(1, 3)):
                task_id = random.choice(self.created_tasks)
                self.client.get(f"/tasks/{task_id}", name="/tasks/[id]")
    
    @task(10)
    def create_and_manage_task(self):
        """Create and manage a task"""
        # Create
        task_data = {
            "title": f"User task {random.randint(1, 999)}",
            "description": "A task that needs to be done",
            "priority": random.randint(1, 3)
        }
        
        with self.client.post("/tasks", json=task_data, catch_response=True) as response:
            if response.status_code == 200:
                task_id = response.json()["id"]
                self.created_tasks.append(task_id)
                
                # Update it after a while
                self.client.put(
                    f"/tasks/{task_id}",
                    json={"completed": True},
                    name="/tasks/[id]"
                )
    
    @task(5)
    def check_stats(self):
        """Check statistics occasionally"""
        self.client.get("/stats")
        self.client.get("/health")