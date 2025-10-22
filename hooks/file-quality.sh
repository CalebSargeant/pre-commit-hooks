#!/usr/bin/env bash
# File Quality Validation
# General file formatting, syntax, and quality checks

set -Eeuo pipefail

# Colours
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Autofix behavior
HOOKS_AUTOFIX=${HOOKS_AUTOFIX:-1}   # 1=auto-fix trailing whitespace / YAML when possible

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

ISSUES_FOUND=0
FIXED_COUNT=0

echo -e "${BLUE}File Quality Validation${NC}"

# Get files to check
STAGED=$(git diff --cached --name-only)
if [[ -n "$STAGED" ]]; then
    FILES="$STAGED"
else
    FILES=$(git ls-files | head -50)
fi

# ----------------------------------------------------------------------
# ❌ Prevent committing directly to main or master
# ----------------------------------------------------------------------
CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
if [[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "master" ]]; then
    echo -e "${RED}❌ You are attempting to commit directly to '${CURRENT_BRANCH}' — this branch is protected.${NC}"
    echo -e "   Please create a feature branch instead."
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# Helpers
is_text_file() { grep -Iq . "$1" 2>/dev/null; }

# ----------------------------------------------------------------------
# ✂️ Check for trailing whitespace (and optionally auto-fix)
# ----------------------------------------------------------------------
TW_FILES=$(echo "$FILES" | xargs -n1 -I{} grep -l "[[:space:]]$" "{}" 2>/dev/null | head -50 || true)
if [[ -n "$TW_FILES" ]]; then
    echo -e "${YELLOW}⚠ Files with trailing whitespace found${NC}"
    echo "$TW_FILES"
    if [[ "$HOOKS_AUTOFIX" = "1" ]]; then
        TW_FIXED=0
        while IFS= read -r f; do
            [[ -f "$f" ]] || continue
            is_text_file "$f" || continue
            # Remove trailing spaces/tabs
            perl -0777 -pe 's/[ \t]+$//mg' -i -- "$f" 2>/dev/null || true
            git add -- "$f" 2>/dev/null || true
            TW_FIXED=$((TW_FIXED + 1))
        done <<<"$TW_FILES"
        if (( TW_FIXED > 0 )); then
            echo -e "${GREEN}✓ Auto-fixed trailing whitespace in ${TW_FIXED} file(s)${NC}"
            FIXED_COUNT=$((FIXED_COUNT + TW_FIXED))
            # Recompute to see if anything remains
            TW_FILES=$(echo "$FILES" | xargs -n1 -I{} grep -l "[[:space:]]$" "{}" 2>/dev/null | head -50 || true)
        fi
    fi
    [[ -n "$TW_FILES" ]] && ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# ----------------------------------------------------------------------
# 📦 Check for large files (>1MB)
# ----------------------------------------------------------------------
LARGE_FILES=$(echo "$FILES" | xargs ls -la 2>/dev/null | awk '$5 > 1048576 {print $9}' || true)
if [[ -n "$LARGE_FILES" ]]; then
    echo -e "${YELLOW}⚠ Large files detected (>1MB):${NC}"
    echo "$LARGE_FILES" | head -3
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# ----------------------------------------------------------------------
# 🧾 YAML validation (and optionally auto-format)
# ----------------------------------------------------------------------
YAML_FILES=$(echo "$FILES" | grep -E "\.(yaml|yml)$" | while read -r f; do [[ -f "$f" ]] && echo "$f"; done || true)
YAML_LINT_FAIL=0
if [[ -n "$YAML_FILES" ]] && command -v yamllint >/dev/null 2>&1; then
    if ! echo "$YAML_FILES" | xargs -n1 yamllint -d '{extends: relaxed, rules: {line-length: {max: 120}}}' >/dev/null 2>&1; then
        YAML_LINT_FAIL=1
        echo -e "${YELLOW}⚠ YAML formatting issues found${NC}"
        if [[ "$HOOKS_AUTOFIX" = "1" ]]; then
            # Prefer prettier if available
            if npx --no-install prettier --version >/dev/null 2>&1; then
                npx --no-install prettier --write "$YAML_FILES" >/dev/null 2>&1 || true
                git add -- "$YAML_FILES" 2>/dev/null || true
                echo -e "${GREEN}✓ Auto-formatted YAML with Prettier${NC}"
            elif command -v prettier >/dev/null 2>&1; then
                prettier --write "$YAML_FILES" >/dev/null 2>&1 || true
                git add -- "$YAML_FILES" 2>/dev/null || true
                echo -e "${GREEN}✓ Auto-formatted YAML with Prettier${NC}"
            fi
            # Re-run lint to confirm
            if echo "$YAML_FILES" | xargs -n1 yamllint -d '{extends: relaxed, rules: {line-length: {max: 120}}}' >/dev/null 2>&1; then
                YAML_LINT_FAIL=0
            fi
        fi
    fi
fi
if (( YAML_LINT_FAIL )); then
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# ----------------------------------------------------------------------
# 🧩 JSON validation
# ----------------------------------------------------------------------
JSON_FILES=$(echo "$FILES" | grep "\.json$" || true)
if [[ -n "$JSON_FILES" ]]; then
    for json_file in $JSON_FILES; do
        if [[ -f "$json_file" ]] && ! python3 -m json.tool "$json_file" >/dev/null 2>&1; then
            echo -e "${RED}❌ Invalid JSON: $json_file${NC}"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
    done
fi

# ----------------------------------------------------------------------
# 🐚 Shell script formatting (shfmt)
# ----------------------------------------------------------------------
if command -v shfmt >/dev/null 2>&1; then
    SHFMT_OUT=$(shfmt -d hooks 2>&1 || true)
    if [[ -n "$SHFMT_OUT" ]]; then
        echo -e "${YELLOW}⚠ Shell formatting issues detected by shfmt:${NC}"
        echo "$SHFMT_OUT" | head -50
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
fi

# ----------------------------------------------------------------------
# 🧪 GitHub Actions workflow lint (actionlint)
# ----------------------------------------------------------------------
WF_FILES=$(echo "$FILES" | grep -E '^\.github/workflows/.*\.ya?ml$' || true)
if [[ -n "$WF_FILES" || -d ".github/workflows" ]] && command -v actionlint >/dev/null 2>&1 && \
   ! actionlint -color -shellcheck= >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ actionlint found issues in workflow files${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# ----------------------------------------------------------------------
# 🔄 Mixed line ending check (CRLF)
# ----------------------------------------------------------------------
MIXED_ENDINGS=$(echo "$FILES" | xargs grep -IlU $'\r' 2>/dev/null || true)
for f in $FILES; do
    if [[ -f "$f" ]] && grep -q $'\r' "$f" 2>/dev/null; then
        MIXED_ENDINGS="$MIXED_ENDINGS\n$f"
    fi
done
MIXED_ENDINGS=$(echo -e "$MIXED_ENDINGS" | sed '/^$/d' | head -3)
if [[ -n "$MIXED_ENDINGS" ]]; then
    echo -e "${YELLOW}⚠ Files with Windows (CRLF) line endings detected:${NC}"
    echo "$MIXED_ENDINGS"
    echo -e "   Consider converting with 'dos2unix <file>'."
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# ----------------------------------------------------------------------
# 🧾 Byte Order Mark (BOM) / UTF-8 enforcement
# ----------------------------------------------------------------------
BOM_FILES=""
for f in $FILES; do
    if [[ -f "$f" ]] && head -c 3 "$f" | grep -q $'\xEF\xBB\xBF'; then
        BOM_FILES="$BOM_FILES\n$f"
    fi
done
BOM_FILES=$(echo -e "$BOM_FILES" | sed '/^$/d' | head -3)
if [[ -n "$BOM_FILES" ]]; then
    echo -e "${YELLOW}⚠ Files containing UTF-8 Byte Order Marks (BOM):${NC}"
    echo "$BOM_FILES"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# ----------------------------------------------------------------------
# ⚙️ Shebang validation for executable scripts
# ----------------------------------------------------------------------
EXEC_FILES=$(echo "$FILES" | xargs file 2>/dev/null | grep "executable" | cut -d: -f1 || true)
if [[ -n "$EXEC_FILES" ]]; then
    for f in $EXEC_FILES; do
        if ! head -n1 "$f" | grep -Eq '^#!'; then
            echo -e "${YELLOW}⚠ Executable missing shebang: $f${NC}"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
    done
fi

# ----------------------------------------------------------------------
# ✅ Summary
# ----------------------------------------------------------------------
if [[ $ISSUES_FOUND -eq 0 ]]; then
    if (( FIXED_COUNT > 0 )); then
        echo -e "${GREEN}✅ File quality issues auto-fixed (${FIXED_COUNT} change(s))${NC}"
    else
        echo -e "${GREEN}✅ File quality checks passed${NC}"
    fi
    exit 0
else
    echo -e "${YELLOW}Found $ISSUES_FOUND file quality issue(s)${NC}"
    exit 1
fi
