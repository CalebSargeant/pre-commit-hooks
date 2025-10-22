#!/usr/bin/env bash

# Master Pre-commit Hook - Complete Code Quality & Security Pipeline
# This is the "all" hook that provides comprehensive validation for any repository
# Usage: Referenced from any repo as github.com/calebsargeant/pre-commit-hooks hook "all"

set -Eeuo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Constants
STAGE_PRE_COMMIT="pre-commit"
STAGE_PRE_PUSH="pre-push"
STAGE_BOTH="both"

# Configuration
FAIL_ON_HIGH_SEVERITY=${FAIL_ON_HIGH_SEVERITY:-true}
FAIL_ON_MEDIUM_SEVERITY=${FAIL_ON_MEDIUM_SEVERITY:-false}
PRE_COMMIT_STAGE=${PRE_COMMIT_FROM_REF:+$STAGE_PRE_PUSH}
PRE_COMMIT_STAGE=${PRE_COMMIT_STAGE:-$STAGE_PRE_COMMIT}
HOOKS_VERBOSE=${HOOKS_VERBOSE:-0}            # 0=concise (default), 1=stream tool output
HOOKS_LOG_DIR=${HOOKS_LOG_DIR:-"$HOME/.pre-commit-hooks/logs"}
HOOKS_SUMMARY_LINES=${HOOKS_SUMMARY_LINES:-60}
HOOKS_DEBUG=${HOOKS_DEBUG:-0}
mkdir -p "$HOOKS_LOG_DIR"

# Default to enabling auto-fix in sub-hooks unless overridden
export HOOKS_AUTOFIX=${HOOKS_AUTOFIX:-1}

hr() { printf '%*s\n' "${1:-70}" '' | tr ' ' '─'; }

note() { printf "${DIM}%s${NC}\n" "$*"; }

header() {
  local title="$1"; shift || true
  printf "${BOLD}${BLUE}%s${NC}\n" "$title"
  hr 75
  [[ "$#" -gt 0 ]] && printf "%s\n" "$*"
}

# Extract actionable lines from a log
extract_issues() {
  local log="$1"; local n="${2:-$HOOKS_SUMMARY_LINES}"
  [[ -s "$log" ]] || { echo "(no output captured)"; return 0; }
  # Grep for common, actionable patterns across tools
  local pat
  pat='would reformat|^([^[:space:]]|\./|\.{2}/)[^:]+:[0-9]+(:[0-9]+)?:|\\berror\\b|\\bfatal\\b|\\bfail(ure|ed)?\\b|\\bviolation\\b|\\binvalid\\b|\\bnot found\\b|✖|❌|\\bwarning\\b|⚠|DL[0-9]{4}|SC[0-9]{4}|E[0-9]{3}|W[0-9]{3}|TS[0-9]{3,}|yamllint|checkov|tfsec|hadolint|trivy|terraform (validate|fmt)|eslint|prettier|flake8|mypy|black|isort'
  # -n to keep line numbers to aid navigation
  grep -InE "$pat" "$log" 2>/dev/null | awk '!seen[$0]++' | head -n "$n"
}

# Print quick fix hints per check/tool
print_fix_hints() {
  local script="$1"; local log="$2"
  case "$script" in
    python-quality.sh)
      grep -q "would reformat" "$log" 2>/dev/null && echo "Fix: black . && isort ."
      grep -qi "flake8" "$log" 2>/dev/null && echo "Fix: flake8 (then address listed errors)"
      ;;
    javascript-quality.sh)
      grep -qi "prettier" "$log" 2>/dev/null && echo "Fix: prettier --write <files>"
      grep -qi "eslint" "$log" 2>/dev/null && echo "Fix: eslint --fix <files>"
      grep -qi "TS[0-9]" "$log" 2>/dev/null && echo "Fix: tsc --noEmit"
      ;;
    terraform-quality.sh)
      grep -qi "terraform fmt" "$log" 2>/dev/null && echo "Fix: terraform fmt -recursive"
      grep -qi "validate" "$log" 2>/dev/null && echo "Fix: terraform init -backend=false && terraform validate"
      grep -qi "tflint" "$log" 2>/dev/null && echo "Fix: tflint --init && tflint"
      ;;
    docker-security.sh)
      grep -qi "hadolint" "$log" 2>/dev/null && echo "Fix: hadolint Dockerfile*"
      grep -qi "trivy" "$log" 2>/dev/null && echo "Fix: trivy config ."
      ;;
    file-quality.sh)
      grep -qi "trailing whitespace" "$log" 2>/dev/null && echo "Fix: remove trailing spaces (e.g., an editor save-on-format)"
      grep -qi "Invalid JSON" "$log" 2>/dev/null && echo "Fix: python3 -m json.tool <file>"
      grep -qi "CRLF" "$log" 2>/dev/null && echo "Fix: dos2unix <file>"
      ;;
  esac
}

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
FAILED_CHECKS=()
FAILED_LOGS=()

header "🚀 Complete Code Quality & Security Pipeline" "Stage: ${PRE_COMMIT_STAGE}"

# Detect file types in the current commit/repository context
STAGED_FILES=$(git diff --cached --name-only)
if [[ -n "$STAGED_FILES" ]]; then
  FILES="$STAGED_FILES"
  CONTEXT="staged files"
else
  FILES=$(git ls-files | head -100)  # Limit to avoid overwhelming output
  CONTEXT="repository files"
fi

echo -e "${CYAN}Context: Processing ${CONTEXT}${NC}\n"

run_validation() {
  local name="$1" stage="$2" script_name="$3" desc="$4"
  # Skip if not appropriate stage
  if [[ "$PRE_COMMIT_STAGE" != "$stage" && "$stage" != "$STAGE_BOTH" ]]; then return 0; fi

  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

  echo -e "${BOLD}${BLUE}${name}${NC} - ${desc}"
  hr 75

  if [[ ! -f "$HOOKS_DIR/$script_name" ]]; then
    echo -e "${CYAN}ℹ️  $name validation not available${NC}\n"
    return 0
  fi

  local base="${script_name%.sh}"
  local log="$HOOKS_LOG_DIR/${base}.log" start end dur
  : >"$log"  # truncate
  start=$(date +%s)

  if [[ "$HOOKS_VERBOSE" -eq 1 ]]; then
    if bash "$HOOKS_DIR/$script_name" 2>&1 | tee "$log"; then status=0; else status=$?; fi
  else
    if bash "$HOOKS_DIR/$script_name" >"$log" 2>&1; then status=0; else status=$?; fi
  fi

  end=$(date +%s); dur=$((end-start))

  if [[ $status -eq 0 ]]; then
    echo -e "${GREEN}✅ $name passed${NC} ${DIM}(${dur}s)${NC}\n"
  else
    echo -e "${RED}❌ $name failed${NC} ${DIM}(${dur}s)${NC}"
    echo -e "${YELLOW}Top findings:${NC}"
    extract_issues "$log" || true
    local hint
    hint=$(print_fix_hints "$script_name" "$log" | sed '/^$/d' | head -3 || true)
    if [[ -n "$hint" ]]; then
      echo -e "\n${CYAN}Hints:${NC}"
      echo "$hint" | sed 's/^/ - /'
    fi
    echo -e "\n${DIM}Full log: $log${NC}\n"

    TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
    FAILED_CHECKS+=("$name")
    FAILED_LOGS+=("$log")

    case "$script_name" in
      *security*|*syntax*) CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1));;
      *) : ;;
    esac
  fi
}

# File type detection
HAS_PYTHON=$(echo "$FILES" | grep -q "\.py$" && echo "true" || echo "false")
HAS_JAVASCRIPT=$(echo "$FILES" | grep -qE "\.(js|ts|jsx|tsx)$" && echo "true" || echo "false")
HAS_TERRAFORM=$(echo "$FILES" | grep -qE "\.(tf|hcl)$" && echo "true" || echo "false")
HAS_DOCKER=$(echo "$FILES" | grep -qE "(Dockerfile|docker-compose.*\.ya?ml)" && echo "true" || echo "false")
HAS_KUSTOMIZE=$(echo "$FILES" | grep -qE "^kubernetes/|kustomization\.ya?ml$" && echo "true" || echo "false")
HAS_DOCKER_BAKE=$(echo "$FILES" | grep -qE "(^|/)docker-bake\.hcl$|(^|/)bake\.hcl$" && echo "true" || echo "false")

# Always run security checks (critical)
run_validation "🛡️  Security Scan" "$STAGE_BOTH" "security-check.sh" "Comprehensive security scanning"

# Language-specific validations
[[ "$HAS_PYTHON" = "true" ]] && run_validation "🐍 Python Quality" "$STAGE_PRE_COMMIT" "python-quality.sh" "Python formatting, linting, and security"
[[ "$HAS_JAVASCRIPT" = "true" ]] && run_validation "📋 JavaScript Quality" "$STAGE_PRE_COMMIT" "javascript-quality.sh" "JavaScript/TypeScript formatting and linting"
[[ "$HAS_TERRAFORM" = "true" ]] && run_validation "🏗️  Infrastructure" "$STAGE_PRE_COMMIT" "terraform-quality.sh" "Terraform validation and security"
[[ "$HAS_DOCKER" = "true" ]] && run_validation "🐋 Container Security" "$STAGE_PRE_COMMIT" "docker-security.sh" "Docker and container validation"
[[ "$HAS_DOCKER_BAKE" = "true" ]] && run_validation "🧱 Docker Bake" "$STAGE_PRE_COMMIT" "docker-bake-validate.sh" "Validate docker-bake.hcl with buildx"
[[ "$HAS_KUSTOMIZE" = "true" ]] && run_validation "☸️  Kustomize" "$STAGE_PRE_COMMIT" "kustomize-validation.sh" "Validate kustomization builds"

# General file validations
run_validation "🔗 Actions SHA pinning" "$STAGE_PRE_COMMIT" "github-actions-pin-sha.sh" "Pin GitHub Actions to SHAs with semver comments"
run_validation "📁 File Quality" "$STAGE_PRE_COMMIT" "file-quality.sh" "General file validation and formatting"

# Pre-push only validations (comprehensive/expensive)
if [[ "$PRE_COMMIT_STAGE" = "$STAGE_PRE_PUSH" ]]; then
  run_validation "⚡ Performance Check" "$STAGE_PRE_PUSH" "performance-check.sh" "Performance regression testing"
  run_validation "⚖️  License Compliance" "$STAGE_PRE_PUSH" "license-check.sh" "Dependency license validation"
  run_validation "📊 Code Metrics" "$STAGE_PRE_PUSH" "code-metrics.sh" "Code quality metrics and analysis"
fi

# (summary removed per user preference)

echo ""
note "Tips:"
echo "  • Run individual checks: pre-commit run --hook-stage pre-commit"
echo "  • Stream full output: export HOOKS_VERBOSE=1"
echo "  • Update tools: pre-commit autoupdate"

# Exit with appropriate code
if (( CRITICAL_FAILURES > 0 )) && [[ "$FAIL_ON_HIGH_SEVERITY" = "true" ]]; then
  exit 1
elif (( TOTAL_ISSUES > 0 )); then
  # Fail the hook when any check fails (so developers fix before commit)
  exit 1
else
  exit 0
fi
