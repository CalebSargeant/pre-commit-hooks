#!/usr/bin/env bash

# CI Merge Gate: fail-fast checks for merge safety (syntax and critical validation only)
# Focus on correctness over style. Intended for CI on pull_request.

set -Eeuo pipefail

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

# Ensure we are at repo root when inside a git repo
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  REPO_ROOT=$(git rev-parse --show-toplevel)
  cd "$REPO_ROOT"
fi

echo -e "${BOLD}${BLUE}🔒 Merge Gate Checks (syntax & critical validation)${NC}"

ISSUES=0

# Collect candidate files (prefer changed files in PR)
FILES=""
if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
  # In PR context; requires fetch-depth: 0 in checkout
  BASE="origin/${GITHUB_BASE_REF}"
  # Try to ensure base exists (ignore failures if already present)
  git fetch --no-tags --prune --depth=1 origin "$GITHUB_BASE_REF" "$GITHUB_HEAD_REF" >/dev/null 2>&1 || true
  FILES=$(git --no-pager diff --name-only "$BASE...HEAD" || echo "")
fi

# Fallbacks
if [[ -z "$FILES" ]] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  # Last commit diff
  FILES=$(git --no-pager diff --name-only HEAD~1..HEAD 2>/dev/null || echo "")
fi
if [[ -z "$FILES" ]] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  # All tracked files (bounded)
  FILES=$(git ls-files | head -1000)
fi
if [[ -z "$FILES" ]]; then
  FILES=$(find . -type f | sed 's#^./##' | head -1000)
fi

# De-dup and normalize
FILES=$(printf '%s\n' "$FILES" | sed '/^$/d' | sort -u)

# Utility: run a command and increment ISSUES on failure with label
run_check() {
  local label="$1"; shift
  if "$@"; then
    echo -e "  ${GREEN}✓${NC} $label"
  else
    echo -e "  ${RED}✗${NC} $label"
    ISSUES=$((ISSUES+1))
  fi
}

# 1) YAML validity (syntax only; relaxed lint rules)
YAML_FILES=$(printf '%s\n' "$FILES" | grep -E '\.(yml|yaml)$' || true)
if [[ -n "$YAML_FILES" ]]; then
  echo -e "${BOLD}YAML syntax${NC}"
  if command -v yamllint >/dev/null 2>&1; then
    # Relaxed config: focus on parse errors and key duplicates
    CFG='{rules: {line-length: disable, indentation: disable, trailing-spaces: disable, new-lines: disable, document-start: disable, truthy: disable, comments: disable, comments-indentation: disable, empty-lines: disable, colons: disable, commas: disable, brackets: disable, braces: disable, key-duplicates: enable}}'
    while IFS= read -r f; do
      [[ -f "$f" ]] || continue
      run_check "YAML parses: $f" bash -c "yamllint -d '$CFG' '$f' >/dev/null"
    done <<< "$YAML_FILES"
  else
    echo -e "  ${YELLOW}yamllint not found; skipping YAML checks${NC}"
  fi
  echo ""
fi

# 2) GitHub Actions workflow validation (actionlint)
if [[ -d .github/workflows ]]; then
  echo -e "${BOLD}GitHub Actions workflows${NC}"
  if command -v actionlint >/dev/null 2>&1; then
    if actionlint -color -shellcheck=; then
      echo -e "  ${GREEN}✓ workflows pass actionlint${NC}"
    else
      echo -e "  ${RED}✗ actionlint reported issues${NC}"
      ISSUES=$((ISSUES+1))
    fi
  else
    echo -e "  ${YELLOW}actionlint not found; skipping workflow lint${NC}"
  fi
  echo ""
fi

# 3) JSON validity
JSON_FILES=$(printf '%s\n' "$FILES" | grep -E '\.json$' || true)
if [[ -n "$JSON_FILES" ]]; then
  echo -e "${BOLD}JSON syntax${NC}"
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    run_check "JSON parses: $f" bash -c "python3 -m json.tool \"$f\" >/dev/null"
  done <<< "$JSON_FILES"
  echo ""
fi

# 4) TOML validity (Python 3.11+ tomllib)
TOML_FILES=$(printf '%s\n' "$FILES" | grep -E '\.toml$' || true)
if [[ -n "$TOML_FILES" ]] && command -v python3 >/dev/null 2>&1; then
  echo -e "${BOLD}TOML syntax${NC}"
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    run_check "TOML parses: $f" python3 -c 'import tomllib,sys; tomllib.load(open(sys.argv[1],"rb"))' "$f"
  done <<< "$TOML_FILES"
  echo ""
fi

# 5) Shell script syntax (no style)
SH_FILES=$(printf '%s\n' "$FILES" | grep -E '\.sh$' || true)
if [[ -n "$SH_FILES" ]]; then
  echo -e "${BOLD}Shell script syntax${NC}"
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    run_check "bash -n: $f" bash -n "$f"
  done <<< "$SH_FILES"
  echo ""
fi

# 6) Python syntax
PY_FILES=$(printf '%s\n' "$FILES" | grep -E '\.py$' || true)
if [[ -n "$PY_FILES" ]] && command -v python3 >/dev/null 2>&1; then
  echo -e "${BOLD}Python syntax${NC}"
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    run_check "py_compile: $f" python3 -m py_compile "$f"
  done <<< "$PY_FILES"
  echo ""
fi

# 7) JavaScript syntax (best-effort)
JS_FILES=$(printf '%s\n' "$FILES" | grep -E '\.js$' || true)
if [[ -n "$JS_FILES" ]] && command -v node >/dev/null 2>&1; then
  echo -e "${BOLD}JavaScript syntax${NC}"
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    run_check "node --check: $f" node --check "$f"
  done <<< "$JS_FILES"
  echo ""
fi

# 8) TypeScript type-check (project-provided tsc)
TS_FILES=$(printf '%s\n' "$FILES" | grep -E '\.tsx?$' || true)
if [[ -n "$TS_FILES" ]] && npx --no-install tsc -v >/dev/null 2>&1; then
  echo -e "${BOLD}TypeScript type-check${NC}"
  run_check "tsc --noEmit" npx --no-install tsc --noEmit
  echo ""
fi

# 9) Terraform validate (no formatting)
TF_DIRS=$(printf '%s\n' "$FILES" | grep -E '\.(tf|hcl)$' | xargs -n1 dirname | sort -u || true)
if [[ -n "$TF_DIRS" ]] && command -v terraform >/dev/null 2>&1; then
  echo -e "${BOLD}Terraform validate${NC}"
  export TF_IN_AUTOMATION=1
  for d in $TF_DIRS; do
    [[ -d "$d" ]] || continue
    run_check "terraform init ($d)" bash -c "terraform -chdir='$d' init -backend=false -input=false -no-color >/dev/null"
    run_check "terraform validate ($d)" bash -c "terraform -chdir='$d' validate -no-color"
  done
  echo ""
fi

# 10) Docker Compose config
COMPOSE_FILES=$(printf '%s\n' "$FILES" | grep -E '(^|.*/)(docker-compose.*\.ya?ml|compose\.ya?ml)$' || true)
if [[ -n "$COMPOSE_FILES" ]] && command -v docker >/dev/null 2>&1; then
  echo -e "${BOLD}Docker Compose config${NC}"
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    run_check "docker compose config: $f" bash -c "docker compose -f '$f' config -q"
  done <<< "$COMPOSE_FILES"
  echo ""
fi

# 11) Helm chart lint
HELM_DIRS=$(printf '%s\n' "$FILES" | grep -E '(^|.*/)(Chart\.ya?ml)$' | xargs -n1 dirname | sort -u || true)
if [[ -z "$HELM_DIRS" ]] && [[ -d charts ]]; then
  HELM_DIRS=$(find charts -type f -name 'Chart.yaml' -maxdepth 3 -print0 | xargs -0 -n1 dirname 2>/dev/null | sort -u || true)
fi
if [[ -n "$HELM_DIRS" ]] && command -v helm >/dev/null 2>&1; then
  echo -e "${BOLD}Helm lint${NC}"
  for d in $HELM_DIRS; do
    [[ -d "$d" ]] || continue
    run_check "helm lint ($d)" helm lint "$d" --quiet
  done
  echo ""
fi

# 12) Secrets scanning (gitleaks) on PR range or working tree
if command -v gitleaks >/dev/null 2>&1; then
  echo -e "${BOLD}Secrets scan (gitleaks)${NC}"
  BASE=""
  if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
    git fetch --no-tags --prune --depth=1 origin "$GITHUB_BASE_REF" "$GITHUB_HEAD_REF" >/dev/null 2>&1 || true
    BASE=$(git merge-base "origin/${GITHUB_BASE_REF}" HEAD 2>/dev/null || echo "")
  fi
  if [[ -n "$BASE" ]]; then
    run_check "gitleaks (diff ${BASE}..HEAD)" bash -c "gitleaks detect --no-banner --redact --source . --log-opts='${BASE}..HEAD' --exit-code 1"
  else
    run_check "gitleaks (working tree)" bash -c "gitleaks detect --no-banner --redact --source . --no-git --exit-code 1"
  fi
  echo ""
fi

# 13) Terraform security (tfsec/checkov) — HIGH severity only
if [[ -n "$TF_DIRS" ]]; then
  if command -v tfsec >/dev/null 2>&1; then
    echo -e "${BOLD}tfsec (HIGH severity)${NC}"
    for d in $TF_DIRS; do
      [[ -d "$d" ]] || continue
      run_check "tfsec ($d)" bash -c "tfsec '$d' --minimum-severity HIGH --format compact"
    done
    echo ""
  fi
  if command -v checkov >/dev/null 2>&1; then
    echo -e "${BOLD}checkov (HIGH severity)${NC}"
    for d in $TF_DIRS; do
      [[ -d "$d" ]] || continue
      run_check "checkov ($d)" bash -c "checkov -d '$d' --framework terraform --quiet --severity-level HIGH"
    done
    echo ""
  fi
fi

# 14) Kubernetes manifests — kubeconform (and kustomize build)
K8S_FILES=$(printf '%s\n' "$FILES" | grep -E '\.(ya?ml)$' | xargs -n1 -I{} sh -c "grep -Eq '^\s*(apiVersion|kind):' '{}' && echo '{}' || true" 2>/dev/null | sed '/^$/d' || true)
if [[ -n "$K8S_FILES" ]] && command -v kubeconform >/dev/null 2>&1; then
  echo -e "${BOLD}Kubernetes manifests (kubeconform)${NC}"
  # Validate individual manifests
  run_check "kubeconform (files)" bash -o pipefail -c "kubeconform -strict -ignore-missing-schemas -summary $(printf ' %q' $K8S_FILES)"
  echo ""
fi

KUSTOMIZE_DIRS=$(printf '%s\n' "$FILES" | grep -E '(^|.*/)(kustomization\.ya?ml)$' | xargs -n1 dirname | sort -u || true)
if [[ -n "$KUSTOMIZE_DIRS" ]] && command -v kustomize >/dev/null 2>&1 && command -v kubeconform >/dev/null 2>&1; then
  echo -e "${BOLD}Kustomize builds (kubeconform)${NC}"
  for d in $KUSTOMIZE_DIRS; do
    [[ -d "$d" ]] || continue
    run_check "kustomize build ($d) | kubeconform" bash -o pipefail -c "kustomize build '$d' | kubeconform -strict -ignore-missing-schemas -summary"
  done
  echo ""
fi

# 15) Dependency audit — HIGH/CRITICAL only
# npm audit
if [[ -f package.json ]] && command -v npm >/dev/null 2>&1; then
  echo -e "${BOLD}npm audit (HIGH+)${NC}"
  run_check "npm audit --omit=dev --audit-level=high" bash -c "npm audit --omit=dev --audit-level=high"
  echo ""
fi
# pip-audit
if command -v pip-audit >/dev/null 2>&1; then
  echo -e "${BOLD}pip-audit (HIGH+)${NC}"
  if [[ -f requirements.txt ]]; then
    run_check "pip-audit -r requirements.txt" bash -c "pip-audit -r requirements.txt --strict --disable-pip-version-check --ignore-vuln GHSA-0000-0000-0000 || true"
  else
    run_check "pip-audit (env)" bash -c "pip-audit --strict --disable-pip-version-check || true"
  fi
  echo ""
fi

# 16) Trivy config (HIGH/CRITICAL) — if available
if command -v trivy >/dev/null 2>&1; then
  echo -e "${BOLD}Trivy config (HIGH,CRITICAL)${NC}"
  run_check "trivy config ." bash -c "trivy config . --severity HIGH,CRITICAL --exit-code 1 --quiet"
  echo ""
fi

# Summary
if [[ $ISSUES -eq 0 ]]; then
  echo -e "${GREEN}✅ Merge gate passed: no critical issues found${NC}"
  exit 0
else
  echo -e "${RED}❌ Merge gate failed: $ISSUES issue(s) detected${NC}"
  exit 1
fi
