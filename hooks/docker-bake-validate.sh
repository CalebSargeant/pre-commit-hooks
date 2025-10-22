#!/usr/bin/env bash

# Docker Bake (buildx) HCL validation
# Validates docker-bake.hcl/bake.hcl files using `docker buildx bake --print`

set -Eeuo pipefail

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

# Gather candidate files (prefer staged)
STAGED=$(git diff --cached --name-only || true)
if [[ -n "$STAGED" ]]; then
  BAKE_FILES=$(echo "$STAGED" | grep -E "(^|/)docker-bake\.hcl$|(^|/)bake\.hcl$" || true)
  CONTEXT="staged"
else
  BAKE_FILES=$(git ls-files | grep -E "(^|/)docker-bake\.hcl$|(^|/)bake\.hcl$" || true)
  CONTEXT="repository"
fi

if [[ -z "$BAKE_FILES" ]]; then
  exit 0
fi

echo -e "${BOLD}${BLUE}🧱 Docker Bake validation (${CONTEXT})${NC}"

# Tool availability
if ! command -v docker >/dev/null 2>&1; then
  echo -e "${YELLOW}⚠ docker not installed, skipping bake validation${NC}"
  exit 0
fi
if ! docker buildx version >/dev/null 2>&1; then
  echo -e "${YELLOW}⚠ docker buildx not available, skipping bake validation${NC}"
  exit 0
fi

ISSUES=0
WARNINGS=0

while IFS= read -r file; do
  [[ -f "$file" ]] || continue
  printf "  %s... " "$file"
  dir=$(dirname "$file")
  base=$(basename "$file")

  # Validate syntax via --print default (or plain --print which prints all)
  if OUTPUT=$( (cd "$dir" && docker buildx bake -f "$base" --print default) 2>&1 ); then
    status=valid
  else
    status=invalid
  fi

  # If valid and jq present, try printing individual groups/targets
  if [[ "$status" = valid ]] && command -v jq >/dev/null 2>&1; then
    groups=$(echo "$OUTPUT" | jq -r '.group | keys[]' 2>/dev/null || true)
    targets=$(echo "$OUTPUT" | jq -r '.target | keys[]' 2>/dev/null || true)
    for t in $groups $targets; do
      [[ -n "$t" && "$t" != null ]] || continue
      if ! (cd "$dir" && docker buildx bake -f "$base" --print "$t" >/dev/null 2>&1); then
        status=invalid
        break
      fi
    done
  fi

  if [[ "$status" = valid ]]; then
    echo -e "${GREEN}✓ valid${NC}"
    # Style nits
    if grep -q $'\t' "$file"; then
      echo -e "    ${YELLOW}⚠ contains tabs (prefer spaces)${NC}"
      WARNINGS=$((WARNINGS+1))
    fi
    if grep -q "platforms\s*=" "$file" && grep -B5 "platforms\s*=" "$file" | grep -q 'target\s*"_common"'; then
      echo -e "    ${YELLOW}⚠ 'platforms' in _common target (use 'platform' instead)${NC}"
      WARNINGS=$((WARNINGS+1))
    fi
  else
    echo -e "${RED}✗ invalid${NC}"
    echo -e "${RED}    Error details:${NC}"
    echo "$OUTPUT" | grep -E "ERROR:|error:|failed" | head -5 | sed 's/^/      /'
    ISSUES=$((ISSUES+1))
  fi

done <<<"$BAKE_FILES"

echo ""
if (( ISSUES > 0 )); then
  echo -e "${RED}❌ Docker Bake validation failed (${ISSUES} file(s))${NC}"
  exit 1
else
  if (( WARNINGS > 0 )); then
    echo -e "${GREEN}✅ Bake files valid${NC} ${YELLOW}(with ${WARNINGS} warning(s))${NC}"
  else
    echo -e "${GREEN}✅ Bake files valid${NC}"
  fi
fi

exit 0
