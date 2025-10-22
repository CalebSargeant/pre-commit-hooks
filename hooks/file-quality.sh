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
# 🧾 YAML validation (syntax + optional formatting)
# ----------------------------------------------------------------------
YAML_FILES=$(echo "$FILES" | grep -E "\.(yaml|yml)$" | while read -r f; do [[ -f "$f" ]] && echo "$f"; done || true)
# Syntax check via Python yaml if available
if [[ -n "$YAML_FILES" ]] && command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' 2>/dev/null; then
    for yf in $YAML_FILES; do
        if ! python3 - <<PY 2>/dev/null
import sys, yaml
yaml.safe_load(open(sys.argv[1]))
PY
"$yf"; then
            echo -e "${RED}❌ Invalid YAML: $yf${NC}"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
    done
fi
YAML_LINT_FAIL=0
if [[ -n "$YAML_FILES" ]] && command -v yamllint >/dev/null 2>&1; then
    if ! echo "$YAML_FILES" | xargs -n1 yamllint -d '{extends: relaxed, rules: {line-length: {max: 120}}}' >/dev/null 2>&1; then
        YAML_LINT_FAIL=1
        echo -e "${YELLOW}⚠ YAML formatting issues found${NC}"
        if [[ "$HOOKS_AUTOFIX" = "1" ]]; then
            # Prefer prettier if available
            if npx --no-install prettier --version >/dev/null 2>&1; then
                npx --no-install prettier --write "$YAML_FILES" >/dev/null 2>&1 || true
                git add -- $YAML_FILES 2>/dev/null || true
                echo -e "${GREEN}✓ Auto-formatted YAML with Prettier${NC}"
            elif command -v prettier >/dev/null 2>&1; then
                prettier --write $YAML_FILES >/dev/null 2>&1 || true
                git add -- $YAML_FILES 2>/dev/null || true
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
# 🧩 JSON validation and optional auto-format
# ----------------------------------------------------------------------
JSON_FILES=$(echo "$FILES" | grep "\.json$" || true)
if [[ -n "$JSON_FILES" ]]; then
    for json_file in $JSON_FILES; do
        [[ -f "$json_file" ]] || continue
        if ! python3 -m json.tool "$json_file" >/dev/null 2>&1; then
            echo -e "${RED}❌ Invalid JSON: $json_file${NC}"
            if [[ "$HOOKS_AUTOFIX" = "1" ]]; then
                # Try to pretty-print if parser is available and input is actually valid for that parser
                if command -v jq >/dev/null 2>&1 && jq -M . "$json_file" >/dev/null 2>&1; then
                    tmp=$(mktemp) && jq -M . "$json_file" > "$tmp" && mv "$tmp" "$json_file"
                    git add -- "$json_file" 2>/dev/null || true
                    echo -e "  ${GREEN}✓ Auto-formatted JSON: $json_file${NC}"
                    continue
                elif python3 -m json.tool "$json_file" >/dev/null 2>&1; then
                    tmp=$(mktemp) && python3 -m json.tool "$json_file" > "$tmp" 2>/dev/null && mv "$tmp" "$json_file"
                    git add -- "$json_file" 2>/dev/null || true
                    echo -e "  ${GREEN}✓ Auto-formatted JSON: $json_file${NC}"
                    continue
                fi
            fi
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        else
            if [[ "$HOOKS_AUTOFIX" = "1" ]]; then
                if command -v jq >/dev/null 2>&1; then
                    tmp=$(mktemp) && jq -M . "$json_file" > "$tmp" && mv "$tmp" "$json_file"
                else
                    tmp=$(mktemp) && python3 -m json.tool "$json_file" > "$tmp" 2>/dev/null && mv "$tmp" "$json_file"
                fi
                git add -- "$json_file" 2>/dev/null || true
                echo -e "  ${GREEN}✓ Normalized JSON formatting: $json_file${NC}"
            fi
        fi
    done
fi

# ----------------------------------------------------------------------
# 🐚 Shell script formatting (shfmt)
# ----------------------------------------------------------------------
if command -v shfmt >/dev/null 2>&1; then
    if [[ "$HOOKS_AUTOFIX" = "1" ]]; then
        shfmt -w hooks >/dev/null 2>&1 || true
        git add -- hooks/*.sh 2>/dev/null || true
        echo -e "${GREEN}✓ Auto-formatted shell scripts in hooks/${NC}"
    else
        SHFMT_OUT=$(shfmt -d hooks 2>&1 || true)
        if [[ -n "$SHFMT_OUT" ]]; then
            echo -e "${YELLOW}⚠ Shell formatting issues detected by shfmt:${NC}"
            echo "$SHFMT_OUT" | head -50
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
    fi
fi

# ----------------------------------------------------------------------
# 🧪 GitHub Actions workflow lint (actionlint) + extra checks
# ----------------------------------------------------------------------
WORKFLOW_FILES=$(echo "$FILES" | grep -E '^\.github/workflows/.*\.ya?ml$' || true)
ACTION_FILES=$(echo "$FILES" | grep -E '^\.github/actions/.*\.ya?ml$' || true)
if [[ -n "$WORKFLOW_FILES" || -d ".github/workflows" ]] && command -v actionlint >/dev/null 2>&1; then
    if ! actionlint -color -shellcheck= >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠ actionlint found issues in workflow files${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
    # Deprecated actions hints and basic secrets heuristics
    if [[ -n "$WORKFLOW_FILES" ]]; then
        while IFS= read -r wf; do
            [[ -f "$wf" ]] || continue
            if grep -qE 'uses:\s*actions/checkout@v[12]' "$wf" 2>/dev/null; then
                echo -e "  ${YELLOW}⚠ $wf uses actions/checkout@v1/v2 (consider v4)${NC}"
            fi
            if grep -qE 'uses:\s*actions/setup-node@v[12]' "$wf" 2>/dev/null; then
                echo -e "  ${YELLOW}⚠ $wf uses actions/setup-node@v1/v2 (consider v4)${NC}"
            fi
            if grep -E "(password|token|key|secret)\s*:\s*['\"][^'\"]+['\"]" "$wf" 2>/dev/null | grep -vqE 'secrets\.|\$\{\{'; then
                echo -e "  ${RED}❌ $wf may contain hardcoded secrets${NC}"
                ISSUES_FOUND=$((ISSUES_FOUND + 1))
            fi
        done <<<"$WORKFLOW_FILES"
    fi
fi
# Basic YAML validity for .github/actions/*.yml
if [[ -n "$ACTION_FILES" ]] && command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' 2>/dev/null; then
    while IFS= read -r af; do
        [[ -f "$af" ]] || continue
        if ! python3 - <<PY 2>/dev/null
import sys, yaml
yaml.safe_load(open(sys.argv[1]))
PY
"$af"; then
            echo -e "${RED}❌ Invalid YAML: $af${NC}"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
    done <<<"$ACTION_FILES"
fi

# ----------------------------------------------------------------------
# 🔄 Mixed line ending check (CRLF) with optional auto-convert
# ----------------------------------------------------------------------
MIXED_ENDINGS_LIST=""
for f in $FILES; do
    [[ -f "$f" ]] || continue
    is_text_file "$f" || continue
    if grep -q $'\r' "$f" 2>/dev/null; then
        MIXED_ENDINGS_LIST="$MIXED_ENDINGS_LIST\n$f"
        if [[ "$HOOKS_AUTOFIX" = "1" ]]; then
            if command -v dos2unix >/dev/null 2>&1; then
                dos2unix "$f" >/dev/null 2>&1 || true
            else
                perl -pi -e 's/\r\n?/\n/g' -- "$f" 2>/dev/null || true
            fi
            git add -- "$f" 2>/dev/null || true
        fi
    fi
done
MIXED_ENDINGS=$(echo -e "$MIXED_ENDINGS_LIST" | sed '/^$/d' | head -3)
if [[ -n "$MIXED_ENDINGS_LIST" ]]; then
    if [[ "$HOOKS_AUTOFIX" = "1" ]]; then
        echo -e "${GREEN}✓ Converted CRLF to LF in affected files${NC}"
        REMAIN=0
        for f in $FILES; do
            [[ -f "$f" ]] || continue
            is_text_file "$f" || continue
            if grep -q $'\r' "$f" 2>/dev/null; then REMAIN=1; break; fi
        done
        if [[ $REMAIN -ne 0 ]]; then
            echo -e "${YELLOW}⚠ Files with Windows (CRLF) line endings remain:${NC}"
            echo "$MIXED_ENDINGS"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
    else
        echo -e "${YELLOW}⚠ Files with Windows (CRLF) line endings detected:${NC}"
        echo "$MIXED_ENDINGS"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
fi

# ----------------------------------------------------------------------
# 🧾 Byte Order Mark (BOM) / UTF-8 enforcement (auto-remove when enabled)
# ----------------------------------------------------------------------
BOM_LIST=""
for f in $FILES; do
    [[ -f "$f" ]] || continue
    is_text_file "$f" || continue
    if head -c 3 "$f" | grep -q $'\xEF\xBB\xBF'; then
        BOM_LIST="$BOM_LIST\n$f"
        if [[ "$HOOKS_AUTOFIX" = "1" ]]; then
            perl -0777 -pe 's/^\xEF\xBB\xBF//' -i -- "$f" 2>/dev/null || true
            git add -- "$f" 2>/dev/null || true
        fi
    fi
done
BOM_FILES=$(echo -e "$BOM_LIST" | sed '/^$/d' | head -3)
if [[ -n "$BOM_LIST" ]]; then
    if [[ "$HOOKS_AUTOFIX" = "1" ]]; then
        echo -e "${GREEN}✓ Removed UTF-8 BOM from affected files${NC}"
    else
        echo -e "${YELLOW}⚠ Files containing UTF-8 Byte Order Marks (BOM):${NC}"
        echo "$BOM_FILES"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
fi

# ----------------------------------------------------------------------
# ⚙️ Shebang validation for executable scripts
# ----------------------------------------------------------------------
EXEC_FILES=""
for f in $FILES; do
    [[ -f "$f" ]] || continue
    # Check if file has executable bit set in git
    mode=$(git ls-files -s -- "$f" | awk '{print $1}')
    # Check for 100755 (executable)
    if [[ "$mode" == "100755" ]]; then
        EXEC_FILES="$EXEC_FILES $f"
    fi
done
if [[ -n "$EXEC_FILES" ]]; then
    for f in $EXEC_FILES; do
        if ! head -n1 "$f" | grep -Eq '^#!'; then
            echo -e "${YELLOW}⚠ Executable missing shebang: $f${NC}"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
    done
fi

# ----------------------------------------------------------------------
# Ensure newline at EOF for text files
if [[ "$HOOKS_AUTOFIX" = "1" ]]; then
    EOF_FIXED=0
    for f in $FILES; do
        [[ -f "$f" ]] || continue
        is_text_file "$f" || continue
        if [[ -s "$f" ]] && [[ $(tail -c1 "$f" | wc -l | tr -d ' ') -eq 0 ]]; then
            printf "\n" >> "$f" 2>/dev/null || true
            git add -- "$f" 2>/dev/null || true
            EOF_FIXED=$((EOF_FIXED + 1))
        fi
    done
    if (( EOF_FIXED > 0 )); then
        echo -e "${GREEN}✓ Added missing newline at EOF to ${EOF_FIXED} file(s)${NC}"
        FIXED_COUNT=$((FIXED_COUNT + EOF_FIXED))
    fi
fi

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
