#!/usr/bin/env bash

# JavaScript Quality Gate Hook
# Comprehensive JavaScript/TypeScript code quality validation

set -Eeuo pipefail

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BOLD}${BLUE}📋 JavaScript Quality Gate${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

ISSUES_FOUND=0

# Get JS/TS files
STAGED=$(git diff --cached --name-only)
if [[ -n "$STAGED" ]]; then
    JS_FILES=$(echo "$STAGED" | grep -E "\.(js|ts|jsx|tsx)$" || true)
    CONTEXT="staged"
else
    JS_FILES=$(find . -type f \( -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" \) | grep -v "node_modules" | grep -v ".git" | head -20)
    CONTEXT="repository"
fi

if [[ -z "$JS_FILES" ]]; then
    echo -e "${BLUE}No JavaScript/TypeScript files found - skipping JS quality checks${NC}"
    exit 0
fi

echo -e "${BLUE}Context: Validating ${CONTEXT} JavaScript/TypeScript files${NC}"
echo ""

# Check if we're in a Node.js project
if [[ -f "package.json" ]] || [[ -f "frontend/package.json" ]]; then
    FRONTEND=0
    if [[ -f "frontend/package.json" ]]; then
        FRONTEND=1
    fi

    # Prepare file list relative to working dir when running inside frontend
    JS_FILES_LOCAL="$JS_FILES"
    if [[ "$FRONTEND" -eq 1 ]]; then
        JS_FILES_LOCAL=$(echo "$JS_FILES" | sed 's#^frontend/##')
    fi

    # 1. Prettier formatting
    PRETTIER_CMD=""
    if npx --no-install prettier --version >/dev/null 2>&1; then
        PRETTIER_CMD="npx --no-install prettier"
    elif command -v prettier >/dev/null 2>&1; then
        PRETTIER_CMD="prettier"
    fi
    if [[ -n "$PRETTIER_CMD" ]]; then
        echo -e "${BOLD}Running Prettier (formatter)...${NC}"
        if [[ "$FRONTEND" -eq 1 ]]; then
            (cd frontend && $PRETTIER_CMD --check $JS_FILES_LOCAL 2>/dev/null)
        else
            $PRETTIER_CMD --check $JS_FILES_LOCAL 2>/dev/null
        fi
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✓ Prettier formatting passed${NC}"
        else
            echo -e "${YELLOW}⚠ Prettier found formatting issues (auto-fixable)${NC}"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
        echo ""
    fi

    # 2. ESLint linting
    ESLINT_CMD=""
    if npx --no-install eslint -v >/dev/null 2>&1; then
        ESLINT_CMD="npx --no-install eslint"
    elif command -v eslint >/dev/null 2>&1; then
        ESLINT_CMD="eslint"
    fi
    if [[ -n "$ESLINT_CMD" ]]; then
        echo -e "${BOLD}Running ESLint (linter)...${NC}"
        if [[ "$FRONTEND" -eq 1 ]]; then
            (cd frontend && $ESLINT_CMD $JS_FILES_LOCAL 2>/dev/null)
        else
            $ESLINT_CMD $JS_FILES_LOCAL 2>/dev/null
        fi
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✓ ESLint linting passed${NC}"
        else
            echo -e "${RED}❌ ESLint found linting issues${NC}"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
        echo ""
    fi

    # 3. TypeScript checking (if TS files present)
    if echo "$JS_FILES" | grep -q "\.tsx\?$"; then
        TSC_CMD=""
        if npx --no-install tsc -v >/dev/null 2>&1; then
            TSC_CMD="npx --no-install tsc"
        elif command -v tsc >/dev/null 2>&1; then
            TSC_CMD="tsc"
        fi
        if [[ -n "$TSC_CMD" ]]; then
            echo -e "${BOLD}Running TypeScript compiler...${NC}"
            if [[ "$FRONTEND" -eq 1 ]]; then
                (cd frontend && $TSC_CMD --noEmit 2>/dev/null)
            else
                $TSC_CMD --noEmit 2>/dev/null
            fi
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}✓ TypeScript compilation passed${NC}"
            else
                echo -e "${YELLOW}⚠ TypeScript found type issues${NC}"
                ISSUES_FOUND=$((ISSUES_FOUND + 1))
            fi
            echo ""
        fi
    fi
else
    echo -e "${YELLOW}⚠️  No package.json found - limited JavaScript validation available${NC}"
    echo ""
fi

# Basic syntax checks for any JS files
echo -e "${BOLD}Running basic syntax checks...${NC}"
SYNTAX_ISSUES=0

for js_file in $JS_FILES; do
    # Combine file existence and Node availability checks
    if [[ -f "$js_file" ]] && command -v node >/dev/null 2>&1; then
        if node --check "$js_file" 2>/dev/null; then
            echo -e "  ${GREEN}✓ $js_file syntax OK${NC}"
        else
            echo -e "  ${RED}❌ $js_file has syntax errors${NC}"
            SYNTAX_ISSUES=$((SYNTAX_ISSUES + 1))
        fi
    fi
done

if [[ $SYNTAX_ISSUES -gt 0 ]]; then
    ISSUES_FOUND=$((ISSUES_FOUND + SYNTAX_ISSUES))
fi

echo ""

# Summary
if [[ $ISSUES_FOUND -eq 0 ]]; then
    echo -e "${GREEN}✅ JavaScript quality gate passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  Found $ISSUES_FOUND JavaScript quality issue(s)${NC}"
    echo -e "${BLUE}Consider running 'npm run format' or 'prettier --write .' to auto-fix${NC}"
    exit 1
fi