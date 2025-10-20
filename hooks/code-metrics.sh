#!/usr/bin/env bash

# Code Metrics and Analysis
# Collects code quality metrics and trends

set -Eeuo pipefail

# Colours
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

echo -e "${BLUE}Code Metrics and Analysis${NC}"

# Basic repository metrics
echo -e "${BLUE}Repository Overview:${NC}"
echo "  Lines of code: $(git ls-files | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}' || echo 'N/A')"
echo "  Files tracked: $(git ls-files | wc -l)"
echo "  Contributors: $(git shortlog -sn | wc -l)"
echo "  Commits: $(git rev-list --count HEAD 2>/dev/null || echo 'N/A')"

# Language breakdown
echo ""
echo -e "${BLUE}Language Breakdown:${NC}"
if command -v cloc >/dev/null 2>&1; then
    cloc --quiet . 2>/dev/null | tail -10 || echo "  cloc not available"
else
    echo "  Python: $(find . -name '*.py' | wc -l) files"
    echo "  JavaScript/TypeScript: $(find . -name '*.js' -o -name '*.ts' | wc -l) files"
    echo "  Terraform: $(find . -name '*.tf' | wc -l) files"
    echo "  YAML: $(find . -name '*.yml' -o -name '*.yaml' | wc -l) files"
fi

# Code complexity (if available)
if command -v radon >/dev/null 2>&1; then
    echo ""
    echo -e "${BLUE}Python Complexity:${NC}"
    radon cc . -s 2>/dev/null | head -5 || echo "  No Python files or radon unavailable"
fi

security_summary() {
    echo ""
    echo -e "${BLUE}Security Summary:${NC}"
    echo "  Secrets baseline: $([[ -f '.secrets.baseline' ]] && echo 'Present' || echo 'Missing')"
    echo "  Gitignore: $([[ -f '.gitignore' ]] && echo 'Present' || echo 'Missing')"
    echo "  License file: $([[ -f 'LICENSE' ]] && echo 'Present' || echo 'Missing')"
    return 0
}

security_summary

echo -e "${GREEN}✅ Code metrics collection completed${NC}"
exit 0
