#!/usr/bin/env bash

# Comprehensive security scan for the exploitum project
# Inspired by the sophisticated custom hooks from setup-hooks.sh

set -Eeuo pipefail

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Colour
BOLD='\033[1m'

# Configuration
FAIL_ON_HIGH_SEVERITY=${FAIL_ON_HIGH_SEVERITY:-true}
FAIL_ON_MEDIUM_SEVERITY=${FAIL_ON_MEDIUM_SEVERITY:-false}

# Find the repository root
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

echo -e "${BOLD}${BLUE}🛡️  Comprehensive Security Scan${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"

# Track findings
TOTAL_HIGH=0
TOTAL_MEDIUM=0
TOTAL_LOW=0
SECURITY_TOOLS_FOUND=false
SCAN_ERRORS=()

# Get staged files or all files if not in a git hook context
STAGED=$(git diff --cached --name-only)
if [[ -n "$STAGED" ]]; then
    FILES="$STAGED"
    CONTEXT="staged"
else
    FILES=$(find . -type f -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.tf" -o -name "*.hcl" -o -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o -name "*.sh" | grep -v ".git" | grep -v "node_modules" | grep -v ".terragrunt-cache" | head -100)
    CONTEXT="repository"
fi

echo -e "${BLUE}Context: Scanning ${CONTEXT} files${NC}"
echo ""

# Function to run security tool safely
run_security_tool() {
    local tool_name=$1
    local binary=$2
    local command=$3
    local description=$4
    
    if command -v "$binary" &> /dev/null; then
        SECURITY_TOOLS_FOUND=true
        echo -e "${BOLD}Running ${tool_name} - ${description}...${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        if eval "$command"; then
            echo -e "  ${GREEN}✓ ${tool_name} scan completed${NC}"
        else
            local exit_code=$?
            SCAN_ERRORS+=("${tool_name} failed with exit code ${exit_code}")
            echo -e "  ${YELLOW}⚠ ${tool_name} completed with warnings${NC}"
        fi
        echo ""
    else
        echo -e "${YELLOW}⚠️  ${tool_name} not found - skipping ${description}${NC}"
    fi
    return 0
}

# Python security scanning
PYTHON_FILES=$(echo "$FILES" | grep "\.py$" || true)
if [[ -n "$PYTHON_FILES" ]]; then
    echo -e "${BOLD}${MAGENTA}Python Security Scanning${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━"
    
# Bandit for Python security
    run_security_tool "Bandit" \
        "bandit" \
        "bandit -r . -x tests/ -f json -o /tmp/bandit-report.json || true" \
        "Python security linter"
    
    # Safety for dependency vulnerabilities
    run_security_tool "Safety" \
        "safety" \
        "safety check --json || true" \
        "Python dependency vulnerability checker"
    
    # Semgrep for advanced security patterns
    run_security_tool "Semgrep" \
        "semgrep" \
        "semgrep --config=auto --json --output=/tmp/semgrep-report.json . || true" \
        "Advanced security pattern detection"
fi

# JavaScript/TypeScript security scanning
JS_FILES=$(echo "$FILES" | grep -E "\.(js|ts|jsx|tsx)$" || true)
if [[ -n "$JS_FILES" ]]; then
    echo -e "${BOLD}${MAGENTA}JavaScript/TypeScript Security Scanning${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
# npm audit for Node.js dependencies
    if [[ -f "package.json" ]]; then
        run_security_tool "npm audit" \
            "npm" \
            "npm audit --audit-level=moderate || true" \
            "Node.js dependency vulnerability check"
    fi
    
    # ESLint with security plugin (only if config exists)
    if [[ -f ".eslintrc.security.js" ]]; then
        run_security_tool "ESLint Security" \
            "npx" \
            "npx --no-install eslint --ext .js,.ts,.jsx,.tsx . --config .eslintrc.security.js || true" \
            "JavaScript security linting"
    fi
fi

# Infrastructure as Code security
TERRAFORM_FILES=$(echo "$FILES" | grep -E "\.(tf|hcl)$" || true)
if [[ -n "$TERRAFORM_FILES" ]]; then
    echo -e "${BOLD}${MAGENTA}Infrastructure as Code Security Scanning${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Get unique directories containing terraform files
    TERRAFORM_DIRS=$(echo "$TERRAFORM_FILES" | xargs -n1 dirname | sort -u)
    
    for dir in $TERRAFORM_DIRS; do
        echo -e "${BLUE}Scanning $dir...${NC}"
        
        # TFSec
        run_security_tool "TFSec" \
            "tfsec \"$dir\" --minimum-severity MEDIUM --format lovely || true" \
            "Terraform security scanner"
        
        # Checkov
        run_security_tool "Checkov" \
            "checkov -d \"$dir\" --framework terraform --quiet || true" \
            "Policy-as-Code scanner"
        
        # Terrascan
        run_security_tool "Terrascan" \
            "terrascan scan -i terraform -d \"$dir\" || true" \
            "IaC security scanner"
    done
fi

# Container security scanning
DOCKER_FILES=$(echo "$FILES" | grep -E "(Dockerfile|docker-compose.*\.ya?ml)$" || true)
if [[ -n "$DOCKER_FILES" ]] || [[ -f "Dockerfile" ]] || [[ -f "docker-compose.yml" ]]; then
    echo -e "${BOLD}${MAGENTA}Container Security Scanning${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
# Trivy for comprehensive container scanning
    run_security_tool "Trivy" \
        "trivy" \
        "trivy config . --severity HIGH,CRITICAL --exit-code 0 || true" \
        "Comprehensive security scanner"
    
    # Hadolint for Dockerfile best practices
    run_security_tool "Hadolint" \
        "hadolint" \
        "find . -name 'Dockerfile*' -exec hadolint {} + || true" \
        "Dockerfile linter"
    
    # Docker Bench Security (if available)
    run_security_tool "Docker Bench" \
        "docker-bench-security" \
        "docker-bench-security || true" \
        "Docker security benchmarking"
fi

# Configuration file security
CONFIG_FILES=$(echo "$FILES" | grep -E "\.(yaml|yml|json|env|config)$" || true)
if [[ -n "$CONFIG_FILES" ]]; then
    echo -e "${BOLD}${MAGENTA}Configuration Security Scanning${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check for secrets in config files
    echo -e "${BLUE}Checking configuration files for secrets...${NC}"
for file in $CONFIG_FILES; do
        # Check for common secret patterns
        if [[ -f "$file" ]] && grep -E "(password|secret|key|token).*=.*[^#]" "$file" 2>/dev/null | grep -v "example\|placeholder\|xxx" | head -3; then
            echo -e "  ${RED}⚠ Potential secrets found in $file${NC}"
            TOTAL_HIGH=$((TOTAL_HIGH + 1))
        fi
    done
fi

# Git security checks
echo -e "${BOLD}${MAGENTA}Git Security Checks${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for large files that might contain secrets
echo -e "${BLUE}Checking for large files...${NC}"
LARGE_FILES=$(find . -type f -size +1M 2>/dev/null | grep -v ".git" | head -5)
if [[ -n "$LARGE_FILES" ]]; then
    echo -e "  ${YELLOW}⚠ Large files found (potential data leaks):${NC}"
    echo "$LARGE_FILES" | sed 's/^/    /'
    TOTAL_MEDIUM=$((TOTAL_MEDIUM + 1))
fi

# Check git history for potential secrets (light check)
echo -e "${BLUE}Quick git history check...${NC}"
if git log --oneline -10 | grep -iE "(password|secret|key|token|credential)" >/dev/null 2>&1; then
    echo -e "  ${YELLOW}⚠ Commit messages contain security-related terms${NC}"
    TOTAL_LOW=$((TOTAL_LOW + 1))
fi

# License and compliance checks
echo -e "${BOLD}${MAGENTA}License & Compliance Checks${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for license files
if [[ ! -f "LICENSE" ]] && [[ ! -f "LICENSE.txt" ]] && [[ ! -f "LICENSE.md" ]]; then
    echo -e "  ${YELLOW}⚠ No LICENSE file found${NC}"
    TOTAL_LOW=$((TOTAL_LOW + 1))
fi

# Check for security policy
if [[ ! -f "SECURITY.md" ]] && [[ ! -f ".github/SECURITY.md" ]]; then
    echo -e "  ${YELLOW}⚠ No SECURITY.md file found${NC}"
    TOTAL_LOW=$((TOTAL_LOW + 1))
fi

# Summary and recommendations
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BOLD}Security Scan Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$SECURITY_TOOLS_FOUND" = "false" ]]; then
    echo -e "${YELLOW}⚠️  Limited security scanning - install more tools for better coverage${NC}"
    echo ""
    echo "Recommended security tools:"
    echo "  • brew install tfsec checkov terrascan trivy hadolint"
    echo "  • pip install bandit safety semgrep"
    echo "  • npm install -g eslint eslint-plugin-security"
    echo ""
fi

# Display scan errors
if [[ ${#SCAN_ERRORS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Scan Warnings:${NC}"
    for error in "${SCAN_ERRORS[@]}"; do
        echo -e "  ${YELLOW}⚠ $error${NC}"
    done
    echo ""
fi

# Final verdict
EXIT_CODE=0

if [[ $TOTAL_HIGH -gt 0 ]]; then
    echo -e "${RED}❌ Found $TOTAL_HIGH high severity issue(s)${NC}"
    
    if [[ "$FAIL_ON_HIGH_SEVERITY" = "true" ]]; then
        EXIT_CODE=1
    fi
fi

if [[ $TOTAL_MEDIUM -gt 0 ]]; then
    echo -e "${YELLOW}⚠️  Found $TOTAL_MEDIUM medium severity issue(s)${NC}"
    
    if [[ "$FAIL_ON_MEDIUM_SEVERITY" = "true" ]]; then
        EXIT_CODE=1
    fi
fi

if [[ $TOTAL_LOW -gt 0 ]]; then
    echo -e "${CYAN}ℹ️  Found $TOTAL_LOW low severity issue(s)${NC}"
fi

if [[ $TOTAL_HIGH -eq 0 ]] && [[ $TOTAL_MEDIUM -eq 0 ]] && [[ $TOTAL_LOW -eq 0 ]]; then
    echo -e "${GREEN}✅ No significant security issues found!${NC}"
    echo -e "${GREEN}   Your code passed security scanning.${NC}"
fi

echo ""
echo -e "${BLUE}💡 Security Tips:${NC}"
echo "  • Use .gitignore for sensitive files"
echo "  • Enable branch protection rules"
echo "  • Review dependencies regularly"
echo "  • Use secrets management tools"
echo "  • Keep security tools updated"

if [[ $EXIT_CODE -ne 0 ]]; then
    echo "" >&2
    echo -e "${RED}Security scan failed - address issues before proceeding${NC}" >&2
    echo -e "${YELLOW}To bypass: FAIL_ON_HIGH_SEVERITY=false git commit --no-verify${NC}" >&2
fi

exit $EXIT_CODE