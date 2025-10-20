#!/usr/bin/env bash

# Docker Security Scan Hook
# Focused container security validation

set -Eeuo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BOLD}${BLUE}🐋 Docker Security Scan${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"

# Find the repository root
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

ISSUES_FOUND=0
SCANS_RUN=0

# Get relevant files
STAGED=$(git diff --cached --name-only)
if [[ -n "$STAGED" ]]; then
    DOCKER_FILES=$(echo "$STAGED" | grep -E "(Dockerfile.*|docker-compose.*\.ya?ml|\.dockerignore)" || true)
    CONTEXT="staged"
else
    DOCKER_FILES=$(find . -name "Dockerfile*" -o -name "docker-compose*.yml" -o -name "docker-compose*.yaml" -o -name ".dockerignore" | grep -v ".git" || true)
    CONTEXT="repository"
fi

if [[ -z "$DOCKER_FILES" ]]; then
    echo -e "${BLUE}No Docker files found - skipping container security scan${NC}"
    exit 0
fi

echo -e "${BLUE}Context: Scanning ${CONTEXT} Docker files${NC}"
echo ""

# Function to run security tool safely
run_security_tool() {
    local tool_name=$1
    local binary=$2
    local command=$3
    local description=$4
    
    SCANS_RUN=$((SCANS_RUN + 1))
    
    if command -v "$binary" &> /dev/null; then
        echo -e "${BOLD}Running ${tool_name} - ${description}...${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        if eval "$command"; then
            echo -e "  ${GREEN}✓ ${tool_name} scan completed${NC}"
        else
            local exit_code=$?
            if [[ $exit_code -ne 0 ]]; then
                echo -e "  ${YELLOW}⚠ ${tool_name} found issues${NC}"
                ISSUES_FOUND=$((ISSUES_FOUND + 1))
            fi
        fi
        echo ""
    else
        echo -e "${YELLOW}⚠️  ${tool_name} not available - install with: brew install ${binary}${NC}"
    fi
}

# Hadolint for Dockerfile best practices
if echo "$DOCKER_FILES" | grep -q "Dockerfile"; then
    run_security_tool "Hadolint" \
        "hadolint" \
        "find . -name 'Dockerfile*' -exec hadolint --ignore DL3008 --ignore DL3009 --ignore DL3015 --ignore DL4006 {} +" \
        "Dockerfile linter and security checker"
fi

# Trivy for comprehensive security scanning
if echo "$DOCKER_FILES" | grep -qE "(Dockerfile|docker-compose)"; then
    run_security_tool "Trivy Config" \
        "trivy" \
        "trivy config . --severity HIGH,CRITICAL --exit-code 1" \
        "Container configuration security scanner"
    
    # If we have built images, scan them too
    if command -v docker &> /dev/null && docker images --format "table {{.Repository}}" | grep -v REPOSITORY | head -1 >/dev/null 2>&1; then
        RECENT_IMAGE=$(docker images --format "table {{.Repository}}:{{.Tag}}" | grep -v REPOSITORY | head -1)
        if [[ -n "$RECENT_IMAGE" ]]; then
            run_security_tool "Trivy Image" \
                "trivy" \
                "trivy image --severity HIGH,CRITICAL --exit-code 0 $RECENT_IMAGE" \
                "Container image vulnerability scanner"
        fi
    fi
fi

# Docker Compose security checks
if echo "$DOCKER_FILES" | grep -q "docker-compose"; then
    echo -e "${BOLD}Docker Compose Security Checks${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    for compose_file in $(echo "$DOCKER_FILES" | grep docker-compose); do
        if [[ -f "$compose_file" ]]; then
            echo -e "${BLUE}Checking $compose_file...${NC}"
            
            # Check for privileged containers
            if grep -q "privileged.*true" "$compose_file"; then
                echo -e "  ${RED}⚠ Privileged containers detected${NC}"
                ISSUES_FOUND=$((ISSUES_FOUND + 1))
            fi
            
            # Check for host network mode
            if grep -q "network_mode.*host" "$compose_file"; then
                echo -e "  ${YELLOW}⚠ Host network mode detected${NC}"
                ISSUES_FOUND=$((ISSUES_FOUND + 1))
            fi
            
            # Check for exposed sensitive ports
            if grep -qE "^\s*-\s*\"(22|3389|5432|3306|6379|27017):" "$compose_file"; then
                echo -e "  ${YELLOW}⚠ Sensitive ports exposed${NC}"
                ISSUES_FOUND=$((ISSUES_FOUND + 1))
            fi
            
            # Check for secrets in environment
            if grep -qE "(PASSWORD|SECRET|KEY|TOKEN).*=" "$compose_file"; then
                echo -e "  ${RED}⚠ Potential secrets in environment variables${NC}"
                ISSUES_FOUND=$((ISSUES_FOUND + 1))
            fi
            
            if [[ $ISSUES_FOUND -eq 0 ]]; then
                echo -e "  ${GREEN}✓ No security issues found in $compose_file${NC}"
            fi
        fi
    done
    echo ""
fi

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BOLD}Docker Security Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $ISSUES_FOUND -eq 0 ]] && [[ $SCANS_RUN -gt 0 ]]; then
    echo -e "${GREEN}✅ All Docker security checks passed!${NC}"
    echo -e "${GREEN}   No container security issues detected.${NC}"
elif [[ $SCANS_RUN -eq 0 ]]; then
    echo -e "${YELLOW}⚠️  No security tools available for scanning${NC}"
    echo ""
    echo "Install recommended tools:"
    echo "  • brew install hadolint"
    echo "  • brew install trivy"
else
    echo -e "${YELLOW}⚠️  Found $ISSUES_FOUND potential security issue(s)${NC}"
    echo ""
    echo -e "${BLUE}💡 Container Security Tips:${NC}"
    echo "  • Use non-root users in containers"
    echo "  • Scan images regularly with trivy"
    echo "  • Keep base images updated"
    echo "  • Use multi-stage builds to reduce attack surface"
    echo "  • Never store secrets in images or compose files"
fi

# Exit with appropriate code
if [[ $ISSUES_FOUND -gt 0 ]]; then
    exit 1
fi

exit 0