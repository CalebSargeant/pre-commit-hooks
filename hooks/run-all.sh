#!/usr/bin/env bash

# Master Pre-commit Hook - Complete Code Quality & Security Pipeline
# This is the "all" hook that provides comprehensive validation for any repository
# Usage: Referenced from any repo as github.com/calebsargeant/infra hook "all"

set -Eeuo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Configuration
FAIL_ON_HIGH_SEVERITY=${FAIL_ON_HIGH_SEVERITY:-true}
FAIL_ON_MEDIUM_SEVERITY=${FAIL_ON_MEDIUM_SEVERITY:-false}
PRE_COMMIT_STAGE=${PRE_COMMIT_FROM_REF:+pre-push}
PRE_COMMIT_STAGE=${PRE_COMMIT_STAGE:-pre-commit}

echo -e "${BOLD}${BLUE}🚀 Complete Code Quality & Security Pipeline${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Stage: ${PRE_COMMIT_STAGE}${NC}"
echo ""

# Find the repository root
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

# Get the directory where this script is located (in the cached pre-commit repo)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR"

# Track overall results
TOTAL_ISSUES=0
TOTAL_CHECKS=0
CRITICAL_FAILURES=0

# Function to run a validation with error handling
run_validation() {
    local name=$1
    local stage=$2
    local script_name=$3
    local description=$4
    
    # Skip if not appropriate stage
    if [[ "$PRE_COMMIT_STAGE" != "$stage" && "$stage" != "both" ]]; then
        return 0
    fi
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    echo -e "${BOLD}${BLUE}${name}${NC} - ${description}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [[ -f "$HOOKS_DIR/$script_name" ]]; then
        if bash "$HOOKS_DIR/$script_name"; then
            echo -e "${GREEN}✅ $name passed${NC}"
        else
            local exit_code=$?
            echo -e "${YELLOW}⚠️  $name found issues (exit code: $exit_code)${NC}"
            TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
            
            # Mark critical failures for security and syntax issues
            if [[ "$script_name" == *"security"* || "$script_name" == *"syntax"* ]]; then
                CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1))
            fi
        fi
    else
        echo -e "${CYAN}ℹ️  $name validation not available${NC}"
    fi
    
    echo ""
}

# Detect file types in the current commit/repository context
STAGED_FILES=$(git diff --cached --name-only)
if [[ -n "$STAGED_FILES" ]]; then
    FILES="$STAGED_FILES"
    CONTEXT="staged files"
else
    FILES=$(git ls-files | head -100)  # Limit to avoid overwhelming output
    CONTEXT="repository files"
fi

echo -e "${CYAN}Context: Processing ${CONTEXT}${NC}"
echo ""

# File type detection
HAS_PYTHON=$(echo "$FILES" | grep -q "\.py$" && echo "true" || echo "false")
HAS_JAVASCRIPT=$(echo "$FILES" | grep -qE "\.(js|ts|jsx|tsx)$" && echo "true" || echo "false")
HAS_TERRAFORM=$(echo "$FILES" | grep -qE "\.(tf|hcl)$" && echo "true" || echo "false")
HAS_DOCKER=$(echo "$FILES" | grep -qE "(Dockerfile|docker-compose.*\.ya?ml)" && echo "true" || echo "false")

# Always run security checks (critical)
run_validation "🛡️  Security Scan" "both" "security-check.sh" "Comprehensive security scanning"

# Language-specific validations
if [[ "$HAS_PYTHON" = "true" ]]; then
    run_validation "🐍 Python Quality" "pre-commit" "python-quality.sh" "Python formatting, linting, and security"
fi

if [[ "$HAS_JAVASCRIPT" = "true" ]]; then
    run_validation "📋 JavaScript Quality" "pre-commit" "javascript-quality.sh" "JavaScript/TypeScript formatting and linting"
fi

if [[ "$HAS_TERRAFORM" = "true" ]]; then
    run_validation "🏗️  Infrastructure" "pre-commit" "terraform-quality.sh" "Terraform validation and security"
fi

if [[ "$HAS_DOCKER" = "true" ]]; then
    run_validation "🐋 Container Security" "pre-commit" "docker-security.sh" "Docker and container validation"
fi

# General file validations
run_validation "📁 File Quality" "pre-commit" "file-quality.sh" "General file validation and formatting"

# Pre-push only validations (comprehensive/expensive)
if [[ "$PRE_COMMIT_STAGE" = "pre-push" ]]; then
    run_validation "⚡ Performance Check" "pre-push" "performance-check.sh" "Performance regression testing"
    run_validation "⚖️  License Compliance" "pre-push" "license-check.sh" "Dependency license validation"
    run_validation "📊 Code Metrics" "pre-push" "code-metrics.sh" "Code quality metrics and analysis"
fi

# Summary and final decision
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BOLD}Validation Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $TOTAL_ISSUES -eq 0 ]]; then
    echo -e "${GREEN}🎉 All $TOTAL_CHECKS validations passed!${NC}"
    echo -e "${GREEN}   Your code meets all quality and security standards.${NC}"
elif [[ $CRITICAL_FAILURES -gt 0 ]]; then
    echo -e "${RED}❌ Found $CRITICAL_FAILURES critical issue(s) out of $TOTAL_CHECKS checks${NC}"
    echo -e "${RED}   Critical security or syntax issues must be resolved.${NC}"
    
    if [[ "$FAIL_ON_HIGH_SEVERITY" = "true" ]]; then
        echo ""
        echo -e "${RED}Commit blocked due to critical issues.${NC}"
        echo -e "${YELLOW}To bypass: FAIL_ON_HIGH_SEVERITY=false git commit${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  Found $TOTAL_ISSUES non-critical issue(s) out of $TOTAL_CHECKS checks${NC}"
    echo -e "${BLUE}   Review the issues above and fix when convenient.${NC}"
fi

echo ""
echo -e "${BLUE}💡 Tips:${NC}"
echo "  • Run individual checks: pre-commit run --hook-stage pre-commit"
echo "  • Skip temporary: SKIP=all git commit -m 'WIP: debugging'"
echo "  • Update tools: pre-commit autoupdate"
echo "  • Full docs: https://github.com/calebsargeant/infra/tree/main/hooks"

# Exit with appropriate code
if [[ $CRITICAL_FAILURES -gt 0 ]] && [[ "$FAIL_ON_HIGH_SEVERITY" = "true" ]]; then
    exit 1
else
    exit 0
fi