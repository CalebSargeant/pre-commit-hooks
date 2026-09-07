#!/usr/bin/env bash

# Terraform Comprehensive Validation Hook
# Complete Terraform pipeline: format, validate, docs, lint, security

set -Eeuo pipefail

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

# Autofix behavior
HOOKS_AUTOFIX=${HOOKS_AUTOFIX:-1}

echo -e "${BOLD}${BLUE}🏗️ Terraform Comprehensive Check${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"

# Find the repository root
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

ISSUES_FOUND=0
CHECKS_RUN=0

# Get Terraform files (excluding docker-bake.hcl and bake.hcl which are Docker Buildx files)
STAGED=$(git diff --cached --name-only)
if [[ -n "$STAGED" ]]; then
    TF_FILES=$(echo "$STAGED" | grep -E "\.(tf|hcl)$" | grep -vE "(\.terragrunt-cache|docker-bake\.hcl$|(^|/)bake\.hcl$)" || true)
    CONTEXT="staged"
else
    TF_FILES=$(find . -name "*.tf" -o -name "*.hcl" | grep -vE "(\.git|\.terragrunt-cache|docker-bake\.hcl$|(^|/)bake\.hcl$)" | head -50 || true)
    CONTEXT="repository"
fi

if [[ -z "$TF_FILES" ]]; then
    echo -e "${BLUE}No Terraform files found - skipping Terraform checks${NC}"
    exit 0
fi

echo -e "${BLUE}Context: Validating ${CONTEXT} Terraform files${NC}"
echo ""

# Get unique directories containing terraform files
TF_DIRS=$(echo "$TF_FILES" | xargs -n1 dirname | sort -u)

# Function to run terraform tool safely
run_tf_tool() {
    local tool_name=$1
    local binary=$2
    local command=$3
    local description=$4
    local directory=$5

    CHECKS_RUN=$((CHECKS_RUN + 1))

    if command -v "$binary" &> /dev/null; then
        echo -e "${BOLD}Running ${tool_name} in $directory - ${description}${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        cd "$REPO_ROOT/$directory"

        if eval "$command"; then
            echo -e "  ${GREEN}✓ ${tool_name} passed${NC}"
        else
            local exit_code=$?
            if [[ $exit_code -ne 0 ]]; then
                echo -e "  ${YELLOW}⚠ ${tool_name} found issues${NC}"
                ISSUES_FOUND=$((ISSUES_FOUND + 1))
            fi
        fi

        cd "$REPO_ROOT"
        echo ""
    else
        echo -e "${YELLOW}⚠️  ${tool_name} not available - install with: brew install ${binary}${NC}"
    fi
    return 0
}

# Run checks for each directory
for dir in $TF_DIRS; do
    echo -e "${BOLD}${BLUE}Processing directory: $dir${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Terraform Format (auto-fix when enabled)
    if [[ "${HOOKS_AUTOFIX}" = "1" ]]; then
        run_tf_tool "terraform fmt" \
            "terraform" \
            "terraform fmt -recursive" \
            "Code formatting" \
            "$dir"
    else
        run_tf_tool "terraform fmt" \
            "terraform" \
            "terraform fmt -check -recursive -diff" \
            "Code formatting" \
            "$dir"
    fi

    # 2. Terraform Validate (only if .terraform exists or we can init)
    if [[ -d "$dir/.terraform" ]] || terraform -chdir="$dir" init -backend=false >/dev/null 2>&1; then
        run_tf_tool "terraform validate" \
            "terraform" \
            "terraform validate" \
            "Configuration validation" \
            "$dir"
    else
        echo -e "${YELLOW}⚠️  Terraform not initialized in $dir - skipping validation${NC}"
    fi

    # 3. TFLint
    run_tf_tool "tflint" \
        "tflint" \
        "tflint --init && tflint" \
        "Terraform linting" \
        "$dir"

    # 4. TFSec
    run_tf_tool "tfsec" \
        "tfsec" \
        "tfsec . --minimum-severity MEDIUM --format lovely" \
        "Security scanning" \
        "$dir"

    # 5. Checkov
    run_tf_tool "checkov" \
        "checkov" \
        "checkov -d . --framework terraform --quiet" \
        "Policy compliance checking" \
        "$dir"

    # 6. Terrascan (IaC security)
    run_tf_tool "terrascan" \
        "terrascan" \
        "terrascan scan -i terraform -d ." \
        "IaC security scanner" \
        "$dir"

    # 6. Terraform Docs (if README exists or we should create docs)
    if [[ -f "$dir/README.md" ]] || ls "$dir"/*.tf >/dev/null 2>&1; then
        run_tf_tool "terraform-docs" \
            "terraform-docs" \
            "terraform-docs markdown table --output-file README.md ." \
            "Documentation generation" \
            "$dir"
    fi

    echo ""
done

# Additional checks
echo -e "${BOLD}Additional Terraform Checks${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Format a terragrunt directory, across both CLI generations.
#
#   tg_hclfmt <dir>            rewrite files in place
#   tg_hclfmt <dir> --check    report only, non-zero if reformatting is needed
#
# terragrunt v1 renamed `hclfmt` to `hcl fmt` and dropped the `--terragrunt-`
# flag prefix. Both pre-v1 invocations are hard errors on v1 ("flag provided but
# not defined"), exiting 1, which made this whole section useless on any modern
# terragrunt: the check branch reported formatting issues for every file
# regardless of formatting, and the autofix branch (`|| true`) silently
# reformatted nothing while still printing "Auto-formatted HCL".
#
# Probed rather than version-parsed, so this keeps working across whatever the
# next rename is.
tg_hclfmt() {
    local dir=$1 mode=${2:-}

    if terragrunt hcl fmt --help &> /dev/null; then
        if [[ "$mode" = "--check" ]]; then
            terragrunt hcl fmt --check --working-dir "$dir"
        else
            terragrunt hcl fmt --working-dir "$dir"
        fi
    else
        if [[ "$mode" = "--check" ]]; then
            terragrunt hclfmt --terragrunt-check --terragrunt-working-dir "$dir"
        else
            terragrunt hclfmt --terragrunt-working-dir "$dir"
        fi
    fi
}

# Check for common anti-patterns
echo -e "${BLUE}Checking for Terraform anti-patterns...${NC}"
CHECKS_RUN=$((CHECKS_RUN + 1))

ANTIPATTERN_ISSUES=0

for tf_file in $TF_FILES; do
    if [[ -f "$tf_file" ]]; then
        # Check for hardcoded values
        if grep -qE "(password|secret|key)\s*=\s*\"[^$]" "$tf_file" 2>/dev/null; then
            echo -e "  ${RED}⚠ Potential hardcoded secrets in $tf_file${NC}"
            ANTIPATTERN_ISSUES=$((ANTIPATTERN_ISSUES + 1))
        fi

        # Check for missing tags
        if grep -q "resource.*aws_" "$tf_file" && ! grep -q "tags\s*=" "$tf_file" 2>/dev/null; then
            echo -e "  ${YELLOW}⚠ AWS resources without tags in $tf_file${NC}"
            ANTIPATTERN_ISSUES=$((ANTIPATTERN_ISSUES + 1))
        fi

        # Check for deprecated syntax.
        #
        # What is actually deprecated (Terraform 0.12+) is a string whose ENTIRE
        # value is one interpolation: `count = "${var.enabled}"`, which should be
        # written `count = var.enabled`. Interpolation itself is not deprecated
        # and cannot be avoided: `"${path.module}/x"`, `"prefix-${var.env}"` and
        # every terragrunt `source = "${get_repo_root()}/..."` are all correct.
        #
        # This used to be `grep -q "\${.*}"`, which matched any interpolation
        # anywhere and so flagged over half of every real Terraform repo,
        # failing the hook on any commit that staged a .tf or .hcl file.
        #
        # The pattern below anchors on `= "${...}"` as the whole right-hand
        # side, and excludes `{`, `}` and `"` inside the interpolation so that
        # concatenations ("${a}${b}") and nested-quote calls are not matched.
        # It prefers false negatives over false positives.
        if grep -qE '=[[:space:]]*"\$\{[^{}"]*\}"[[:space:]]*(#.*)?$' "$tf_file" 2>/dev/null; then
            echo -e "  ${YELLOW}⚠ Redundant interpolation-only string in $tf_file (\"\${x}\" can be written x)${NC}"
            ANTIPATTERN_ISSUES=$((ANTIPATTERN_ISSUES + 1))
        fi
    fi
done

if [[ $ANTIPATTERN_ISSUES -eq 0 ]]; then
    echo -e "  ${GREEN}✓ No anti-patterns detected${NC}"
else
    ISSUES_FOUND=$((ISSUES_FOUND + ANTIPATTERN_ISSUES))
fi

echo ""

# Check for Terragrunt files
HCL_FILES=$(echo "$TF_FILES" | grep "\.hcl$" || true)
if [[ -n "$HCL_FILES" ]]; then
    echo -e "${BOLD}Terragrunt Checks${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━"

    for hcl_file in $HCL_FILES; do
        if [[ -f "$hcl_file" ]]; then
            echo -e "${BLUE}Checking $hcl_file...${NC}"

            # Basic HCL syntax check
            if command -v terragrunt &> /dev/null; then
                if [[ "${HOOKS_AUTOFIX}" = "1" ]]; then
                    tg_hclfmt "$(dirname "$hcl_file")" >/dev/null 2>&1 || true
                    git add -- "$hcl_file" 2>/dev/null || true
                    echo -e "  ${GREEN}✓ Auto-formatted HCL${NC}"
                else
                    if tg_hclfmt "$(dirname "$hcl_file")" --check >/dev/null 2>&1; then
                        echo -e "  ${GREEN}✓ HCL formatting OK${NC}"
                    else
                        echo -e "  ${YELLOW}⚠ HCL formatting issues${NC}"
                        ISSUES_FOUND=$((ISSUES_FOUND + 1))
                    fi
                fi
            fi
        fi
    done

    CHECKS_RUN=$((CHECKS_RUN + 1))
    echo ""
fi

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BOLD}Terraform Validation Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $ISSUES_FOUND -eq 0 ]] && [[ $CHECKS_RUN -gt 0 ]]; then
    echo -e "${GREEN}✅ All Terraform checks passed!${NC}"
    echo -e "${GREEN}   Infrastructure code is validated and secure.${NC}"
elif [[ $CHECKS_RUN -eq 0 ]]; then
    echo -e "${YELLOW}⚠️  No Terraform tools available for validation${NC}"
    echo ""
    echo "Install recommended tools:"
    echo "  • brew install terraform"
    echo "  • brew install tflint"
    echo "  • brew install tfsec"
    echo "  • brew install terraform-docs"
    echo "  • pip install checkov"
else
    echo -e "${YELLOW}⚠️  Found $ISSUES_FOUND issue(s) across $CHECKS_RUN validation checks${NC}"
    echo ""
    echo -e "${BLUE}💡 Terraform Best Practices:${NC}"
    echo "  • Use consistent formatting with 'terraform fmt'"
    echo "  • Validate configurations with 'terraform validate'"
    echo "  • Use variables instead of hardcoded values"
    echo "  • Tag all cloud resources consistently"
    echo "  • Keep modules small and focused"
    echo "  • Use semantic versioning for module sources"
fi

# Exit with appropriate code
if [[ $ISSUES_FOUND -gt 0 ]]; then
    exit 1
fi

exit 0
