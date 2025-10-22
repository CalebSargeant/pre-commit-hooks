#!/usr/bin/env bash

# Kustomize validation for kubernetes manifests
# Validates kustomization directories using kubectl kustomize

set -Eeuo pipefail

# Config
MAX_PARALLEL_JOBS=${MAX_PARALLEL_JOBS:-8}
VALIDATE_ALL=${VALIDATE_ALL:-false}

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

STAGED=$(git diff --cached --name-only || true)
K8S_CHANGED=$(echo "$STAGED" | grep '^kubernetes/' || true)

if [[ -z "$K8S_CHANGED" && "$VALIDATE_ALL" != "true" ]]; then
  exit 0
fi

echo -e "${BOLD}${BLUE}☸️  Kustomize validation${NC}"

# Tool availability
if ! command -v kubectl >/dev/null 2>&1; then
  echo -e "${YELLOW}⚠ kubectl not installed, skipping kustomize validation${NC}"
  exit 0
fi

# Collect kustomization files
if [[ "$VALIDATE_ALL" = "true" || -z "$K8S_CHANGED" ]]; then
  mapfile -t KUSTOM_FILES < <(find ./kubernetes -type f \( -name 'kustomization.yaml' -o -name 'kustomization.yml' \) | grep -v \/\.disabled\/ | sort)
else
  KUSTOM_FILES=()
  while IFS= read -r d; do
    cur="$d"
    while [[ "$cur" != "." && -n "$cur" ]]; do
      if [[ -f "$cur/kustomization.yaml" || -f "$cur/kustomization.yml" ]]; then
        # de-dupe
        if ! printf '%s\n' "${KUSTOM_FILES[@]}" | grep -qx "$cur/kustomization.yaml\|$cur/kustomization.yml"; then
          if [[ -f "$cur/kustomization.yaml" ]]; then KUSTOM_FILES+=("$cur/kustomization.yaml"); else KUSTOM_FILES+=("$cur/kustomization.yml"); fi
        fi
        break
      fi
      cur=$(dirname "$cur")
    done
  done < <(echo "$K8S_CHANGED" | xargs -n1 dirname | sort -u)
fi

if [[ ${#KUSTOM_FILES[@]} -eq 0 ]]; then
  echo -e "${YELLOW}⚠ No kustomization files to validate${NC}"
  exit 0
fi

echo -e "${BLUE}Found ${#KUSTOM_FILES[@]} kustomization(s); using ${MAX_PARALLEL_JOBS} parallel jobs${NC}"

validate_one() {
  local kf="$1"
  local dir
  dir=$(dirname "$kf")
  if kubectl kustomize "$dir" --enable-helm >/dev/null 2>&1 || kubectl kustomize "$dir" >/dev/null 2>&1; then
    echo "OK:${dir#./}"
  else
    echo "FAILED:${dir#./}" && kubectl kustomize "$dir" 2>&1 | head -20
  fi
}
export -f validate_one

# Parallel execution
TMPDIR_RUN=$(mktemp -d)
trap "rm -rf '$TMPDIR_RUN'" EXIT

if command -v parallel >/dev/null 2>&1; then
  mapfile -t RESULTS < <(printf '%s\n' "${KUSTOM_FILES[@]}" | parallel -j "$MAX_PARALLEL_JOBS" --will-cite validate_one {})
else
  mapfile -t RESULTS < <(printf '%s\n' "${KUSTOM_FILES[@]}" | xargs -P "$MAX_PARALLEL_JOBS" -I {} bash -c 'validate_one "$@"' _ {})
fi

FAIL=0; PASS=0
for r in "${RESULTS[@]}"; do
  if [[ "$r" == OK:* ]]; then
    echo -e "${GREEN}✓${NC} ${r#OK:}"
    PASS=$((PASS+1))
  elif [[ "$r" == FAILED:* ]]; then
    echo -e "${RED}✗${NC} ${r#FAILED:}"; FAIL=$((FAIL+1))
  fi
done

echo ""
if (( FAIL > 0 )); then
  echo -e "${RED}❌ Kustomize validation failed (${FAIL} failed, ${PASS} passed)${NC}"
  exit 1
else
  echo -e "${GREEN}✅ All ${PASS} kustomizations are valid${NC}"
fi

exit 0
