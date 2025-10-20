#!/usr/bin/env bash

# Performance regression testing for the exploitum project
# Runs lightweight performance checks to catch regressions early

set -Eeuo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

# Configuration
PERFORMANCE_THRESHOLD=${PERFORMANCE_THRESHOLD:-5.0}  # seconds
MEMORY_THRESHOLD=${MEMORY_THRESHOLD:-100}            # MB

echo -e "${BOLD}${BLUE}⚡ Performance Regression Testing${NC}"
echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════${NC}"

# Find the repository root
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

ISSUES_FOUND=0
TESTS_RUN=0

# Function to run performance test
run_perf_test() {
    local test_name=$1
    local command=$2
    local threshold=$3
    
    echo -e "${BLUE}Running $test_name...${NC}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Measure execution time
    start_time=$(date +%s.%N)
    
    if eval "$command" >/dev/null 2>&1; then
        end_time=$(date +%s.%N)
        duration=$(echo "$end_time - $start_time" | bc -l)
        
        if (( $(echo "$duration > $threshold" | bc -l) )); then
            echo -e "  ${YELLOW}⚠ $test_name took ${duration}s (threshold: ${threshold}s)${NC}"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        else
            echo -e "  ${GREEN}✓ $test_name completed in ${duration}s${NC}"
        fi
    else
        echo -e "  ${RED}❌ $test_name failed to execute${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
}

# Python performance tests
if [[ -f "backend/lambda_handler.py" ]]; then
    echo -e "${BOLD}Python Performance Tests${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Import time test
    run_perf_test "Python import time" \
        "python3 -c 'import backend.lambda_handler'" \
        "2.0"
    
    # Basic function test
    if python3 -c "from backend.lambda_handler import lambda_handler" 2>/dev/null; then
        run_perf_test "Lambda handler initialization" \
            "python3 -c 'from backend.lambda_handler import lambda_handler; lambda_handler({\"test\": True}, {})'" \
            "3.0"
    fi
fi

# JavaScript/Node.js performance tests
if [[ -f "frontend/package.json" ]]; then
    echo -e "${BOLD}Frontend Performance Tests${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    cd frontend
    
    # Build time test
    if [[ -f "package.json" ]] && grep -q "build" package.json; then
        run_perf_test "Frontend build time" \
            "npm run build" \
            "30.0"
    fi
    
    # Bundle size check
    if [[ -d "dist" ]] || [[ -d "build" ]]; then
        BUILD_DIR="dist"
        [[ -d "build" ]] && BUILD_DIR="build"
        
        BUNDLE_SIZE=$(du -sm $BUILD_DIR 2>/dev/null | cut -f1 || echo "0")
        if [[ "$BUNDLE_SIZE" -gt 10 ]]; then
            echo -e "  ${YELLOW}⚠ Bundle size is ${BUNDLE_SIZE}MB (consider optimization)${NC}"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        else
            echo -e "  ${GREEN}✓ Bundle size is ${BUNDLE_SIZE}MB${NC}"
        fi
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
    
    cd ..
fi

# Docker build performance
if [[ -f "Dockerfile" ]]; then
    echo -e "${BOLD}Container Performance Tests${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Docker build time (using cache)
    run_perf_test "Docker build time" \
        "docker build -t exploitum-test ." \
        "60.0"
    
    # Check image size
    if docker images exploitum-test --format "table {{.Size}}" | tail -n1 >/dev/null 2>&1; then
        IMAGE_SIZE=$(docker images exploitum-test --format "table {{.Size}}" | tail -n1 | sed 's/MB//')
        if [[ "${IMAGE_SIZE%.*}" -gt 500 ]] 2>/dev/null; then
            echo -e "  ${YELLOW}⚠ Docker image is ${IMAGE_SIZE} (consider multi-stage build)${NC}"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        else
            echo -e "  ${GREEN}✓ Docker image size is ${IMAGE_SIZE}${NC}"
        fi
        TESTS_RUN=$((TESTS_RUN + 1))
        
        # Clean up test image
        docker rmi exploitum-test >/dev/null 2>&1 || true
    fi
fi

# Database/Infrastructure performance
if [[ -d "terraform" ]]; then
    echo -e "${BOLD}Infrastructure Performance Tests${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    cd terraform
    
    # Terraform plan time
    if [[ -f "main.tf" ]]; then
        run_perf_test "Terraform plan time" \
            "terraform plan -out=tfplan" \
            "15.0"
        
        # Clean up plan file
        rm -f tfplan
    fi
    
    cd ..
fi

# API performance tests (if backend is running)
if [[ -f "backend/lambda_handler.py" ]]; then
    echo -e "${BOLD}API Performance Tests${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check if we can run a simple API test
    if python3 -c "import requests" 2>/dev/null; then
        # This would need to be adapted based on your actual API
        echo -e "  ${BLUE}API performance tests require running service${NC}"
    else
        echo -e "  ${YELLOW}⚠ requests module not found - skipping API tests${NC}"
    fi
fi

# Memory usage check for current processes
echo -e "${BOLD}System Resource Check${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━"

# Check available memory
if command -v free >/dev/null 2>&1; then
    AVAILABLE_MEM=$(free -m | awk 'NR==2{printf "%d", $7}')
    if [[ "$AVAILABLE_MEM" -lt 500 ]]; then
        echo -e "  ${YELLOW}⚠ Low available memory: ${AVAILABLE_MEM}MB${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    else
        echo -e "  ${GREEN}✓ Available memory: ${AVAILABLE_MEM}MB${NC}"
    fi
elif command -v vm_stat >/dev/null 2>&1; then
    # macOS memory check
    FREE_PAGES=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
    FREE_MB=$((FREE_PAGES * 4096 / 1024 / 1024))
    if [[ "$FREE_MB" -lt 500 ]]; then
        echo -e "  ${YELLOW}⚠ Low available memory: ${FREE_MB}MB${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    else
        echo -e "  ${GREEN}✓ Available memory: ${FREE_MB}MB${NC}"
    fi
fi

TESTS_RUN=$((TESTS_RUN + 1))

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BOLD}Performance Test Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $ISSUES_FOUND -eq 0 ]]; then
    echo -e "${GREEN}✅ All $TESTS_RUN performance tests passed!${NC}"
    echo -e "${GREEN}   No performance regressions detected.${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  Found $ISSUES_FOUND performance issue(s) out of $TESTS_RUN tests${NC}"
    echo ""
    echo -e "${BLUE}💡 Performance Tips:${NC}"
    echo "  • Profile your code to find bottlenecks"
    echo "  • Use caching where appropriate"
    echo "  • Optimize database queries"
    echo "  • Consider lazy loading"
    echo "  • Monitor resource usage in production"
    echo ""
    echo -e "${YELLOW}Note: Performance tests are advisory - commit will proceed${NC}"
    exit 0
fi