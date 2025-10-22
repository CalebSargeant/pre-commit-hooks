#!/usr/bin/env bash

# Python Quality Gate Hook
# Comprehensive Python code quality validation

set -Eeuo pipefail

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

# Autofix behavior
HOOKS_AUTOFIX=${HOOKS_AUTOFIX:-1}

echo -e "${BOLD}${BLUE}🐍 Python Quality Gate${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

ISSUES_FOUND=0

# Get Python files
STAGED=$(git diff --cached --name-only)
if [[ -n "$STAGED" ]]; then
    PY_FILES=$(echo "$STAGED" | grep "\.py$" || true)
    CONTEXT="staged"
else
    PY_FILES=$(find . -name "*.py" | grep -v ".git" | head -20)
    CONTEXT="repository"
fi

if [[ -z "$PY_FILES" ]]; then
    echo -e "${BLUE}No Python files found - skipping Python quality checks${NC}"
    exit 0
fi

echo -e "${BLUE}Context: Validating ${CONTEXT} Python files${NC}"
echo ""

# 1. Black formatting (auto-fix when enabled)
if command -v black &> /dev/null; then
    echo -e "${BOLD}Running Black (formatter)...${NC}"
    if [[ "${HOOKS_AUTOFIX}" = "1" ]]; then
        black -q $PY_FILES || true
        git add -- $PY_FILES 2>/dev/null || true
        echo -e "  ${GREEN}✓ Auto-formatted with Black${NC}"
    else
        if black --check --diff $PY_FILES; then
            echo -e "${GREEN}✓ Black formatting passed${NC}"
        else
            echo -e "${YELLOW}⚠ Black found formatting issues (auto-fixable)${NC}"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
    fi
    echo ""
fi

# 2. isort import sorting (auto-fix when enabled)
if command -v isort &> /dev/null; then
    echo -e "${BOLD}Running isort (import sorting)...${NC}"
    if [[ "${HOOKS_AUTOFIX}" = "1" ]]; then
        isort -q $PY_FILES || true
        git add -- $PY_FILES 2>/dev/null || true
        echo -e "  ${GREEN}✓ Auto-sorted imports with isort${NC}"
    else
        if isort --check-only --diff $PY_FILES; then
            echo -e "${GREEN}✓ Import sorting passed${NC}"
        else
            echo -e "${YELLOW}⚠ isort found import issues (auto-fixable)${NC}"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
    fi
    echo ""
fi

# 3. flake8 linting
if command -v flake8 &> /dev/null; then
    echo -e "${BOLD}Running flake8 (linter)...${NC}"
    if flake8 $PY_FILES; then
        echo -e "${GREEN}✓ flake8 linting passed${NC}"
    else
        echo -e "${RED}❌ flake8 found linting issues${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
    echo ""
fi

# 4. mypy type checking (optional, may not pass initially)
if command -v mypy &> /dev/null; then
    echo -e "${BOLD}Running mypy (type checker)...${NC}"
    if mypy --ignore-missing-imports $PY_FILES 2>/dev/null; then
        echo -e "${GREEN}✓ mypy type checking passed${NC}"
    else
        echo -e "${YELLOW}⚠ mypy found type issues (review recommended)${NC}"
        # Don't fail on mypy issues as they're often gradual
    fi
    echo ""
fi

# Summary
if [[ $ISSUES_FOUND -eq 0 ]]; then
    echo -e "${GREEN}✅ Python quality gate passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  Found $ISSUES_FOUND Python quality issue(s)${NC}"
    exit 1
fi
