#!/bin/bash

# Metrics test script for Kubernetes Test Lab

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Testing Metrics Endpoints...${NC}"

# Test API health
echo -e "${YELLOW}Testing API health...${NC}"
if curl -s http://localhost:8080/health > /dev/null; then
    echo -e "${GREEN}✅ API health check passed${NC}"
else
    echo -e "${RED}❌ API health check failed${NC}"
    exit 1
fi

# Test API metrics
echo -e "${YELLOW}Testing API metrics endpoint...${NC}"
if curl -s http://localhost:8080/metrics > /dev/null; then
    echo -e "${GREEN}✅ API metrics endpoint accessible${NC}"
    # Show some metrics
    echo -e "${BLUE}Sample metrics:${NC}"
    curl -s http://localhost:8080/metrics | grep -E "(api_requests_total|api_request_duration_seconds)" | head -5
else
    echo -e "${RED}❌ API metrics endpoint failed${NC}"
fi

# Test Prometheus
echo -e "${YELLOW}Testing Prometheus...${NC}"
if curl -s http://localhost:9090/api/v1/status/targets > /dev/null; then
    echo -e "${GREEN}✅ Prometheus is accessible${NC}"
    # Show targets
    echo -e "${BLUE}Prometheus targets:${NC}"
    curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health}' 2>/dev/null || echo "No targets found or jq not available"
else
    echo -e "${RED}❌ Prometheus is not accessible${NC}"
fi

# Test Grafana
echo -e "${YELLOW}Testing Grafana...${NC}"
if curl -s http://localhost:3000/api/health > /dev/null; then
    echo -e "${GREEN}✅ Grafana is accessible${NC}"
else
    echo -e "${RED}❌ Grafana is not accessible${NC}"
fi

# Check pods
echo -e "${YELLOW}Checking pod status...${NC}"
kubectl get pods -n test-lab

# Check services
echo -e "${YELLOW}Checking services...${NC}"
kubectl get svc -n test-lab

echo -e "${GREEN}✅ Metrics test completed!${NC}" 