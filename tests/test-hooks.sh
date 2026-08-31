#!/usr/bin/env bash
#
# Regression tests for the hooks in this repo.
#
# Run:  tests/test-hooks.sh
#
# Each test builds a throwaway git repo, stages files into it, runs one hook
# from that directory and asserts on the exit code and output. Nothing here
# needs tfsec/checkov/terrascan/tflint to be installed; the hooks are supposed
# to skip cleanly when a scanner is missing, and several of these tests exist
# precisely to prove that they do.

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS="$REPO_ROOT/hooks"

PASS=0
FAIL=0

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

pass() { PASS=$((PASS + 1)); echo -e "  ${GREEN}PASS${NC} $1"; }
fail() {
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC} $1"
    if [[ -n "${2:-}" ]]; then
        echo "       $2"
    fi
}

# Build an empty git repo in a temp dir and echo its path.
new_repo() {
    local dir
    dir="$(mktemp -d)"
    git -C "$dir" init -q
    git -C "$dir" config user.email test@example.com
    git -C "$dir" config user.name "test"
    git -C "$dir" config commit.gpgsign false
    echo "$dir"
}

# run_hook <repo-dir> <hook-script> -> sets RC and OUT
run_hook() {
    local dir=$1 hook=$2
    set +e
    OUT="$(cd "$dir" && HOOKS_AUTOFIX=0 "$hook" 2>&1)"
    RC=$?
    set -e
}

echo -e "${BOLD}Hook regression tests${NC}"
echo

# ---------------------------------------------------------------------------
# security-check.sh
# ---------------------------------------------------------------------------
echo -e "${BOLD}security-check.sh${NC}"

# Regression: the three Infrastructure-as-Code call sites used to pass 3 of the
# 4 arguments run_security_tool declares. The script runs under `set -u`, so
# `local description=$4` aborted with "$4: unbound variable" on ANY commit that
# staged a .tf or .hcl file. It did not reproduce with an empty staging area,
# because the script then falls back to a `find | head -100` listing that
# happened to contain no terraform files, so the IaC block never ran.
# Fixed in v1.4.4 (3109465).
for ext in tf hcl; do
    dir="$(new_repo)"
    cat > "$dir/main.$ext" <<'TF'
resource "null_resource" "example" {
  triggers = {
    name = local.name
  }
}
TF
    git -C "$dir" add "main.$ext"
    run_hook "$dir" "$HOOKS/security-check.sh"
    if grep -q "unbound variable" <<< "$OUT"; then
        fail "staged .$ext does not crash on an unbound variable" \
             "$(grep -m1 'unbound variable' <<< "$OUT")"
    elif [[ $RC -ne 0 ]]; then
        fail "staged .$ext exits 0 with no scanners installed" "exit $RC"
    else
        pass "staged .$ext exits 0 with no scanners installed"
    fi
    rm -rf "$dir"
done

# Every run_security_tool call must pass all four arguments the function
# declares. Guards the whole class of bug rather than the three known sites.
#
# Counting quote characters is not good enough here: the `command` argument
# embeds escaped quotes (tfsec \"$dir\" ...). shlex applies real shell word
# splitting, so it counts arguments rather than quote marks.
if command -v python3 &> /dev/null; then
    missing_args="$(python3 - "$HOOKS/security-check.sh" <<'PY'
import re, shlex, sys

BS = chr(92)
lines = open(sys.argv[1], encoding="utf-8").read().split("\n")
bad, i = [], 0
while i < len(lines):
    if re.match(r"\s*run_security_tool\s", lines[i]):
        start, buf = i, []
        while True:
            buf.append(lines[i].rstrip().rstrip(BS).rstrip())
            if not lines[i].rstrip().endswith(BS):
                break
            i += 1
        try:
            argc = len(shlex.split(" ".join(buf).strip())) - 1
        except ValueError as exc:
            bad.append(f"line {start + 1}: unparseable ({exc})")
            argc = None
        if argc is not None and argc != 4:
            bad.append(f"line {start + 1}: {argc} args, expected 4")
    i += 1
print("\n".join(bad))
PY
)"
    if [[ -n "$missing_args" ]]; then
        fail "every run_security_tool call passes 4 arguments" "$missing_args"
    else
        pass "every run_security_tool call passes 4 arguments"
    fi
else
    echo -e "  ${YELLOW}SKIP${NC} run_security_tool arity check (python3 not found)"
fi

echo

# ---------------------------------------------------------------------------
# terraform-quality.sh
# ---------------------------------------------------------------------------
echo -e "${BOLD}terraform-quality.sh${NC}"

# Regression: the deprecated-syntax check was `grep -q "\${.*}"`, which matches
# any interpolation anywhere. Interpolation is not deprecated and cannot be
# avoided, so that flagged roughly half of every real Terraform repo and failed
# the hook on any commit staging a .tf or .hcl file. Only a string whose ENTIRE
# value is one interpolation is redundant.
dir="$(new_repo)"
cat > "$dir/legit.tf" <<'TF'
locals {
  from_root  = "${path.module}/templates/user-data.sh"
  prefixed   = "prefix-${var.environment}"
  arithmetic = "FAULT-DOMAIN-${var.fault_domain + 1}"
  two_parts  = "${var.a}${var.b}"
  bare       = var.enabled
}
TF
git -C "$dir" add legit.tf
run_hook "$dir" "$HOOKS/terraform-quality.sh"
if grep -qi "interpolation" <<< "$OUT"; then
    fail "legitimate interpolation is not flagged" \
         "$(grep -i -m1 'interpolation' <<< "$OUT")"
else
    pass "legitimate interpolation is not flagged"
fi
rm -rf "$dir"

# The genuine anti-pattern must still be caught.
dir="$(new_repo)"
cat > "$dir/redundant.tf" <<'TF'
locals {
  region = "${var.region}"
}
TF
git -C "$dir" add redundant.tf
run_hook "$dir" "$HOOKS/terraform-quality.sh"
if grep -qi "interpolation" <<< "$OUT"; then
    pass "redundant interpolation-only string is flagged"
else
    fail "redundant interpolation-only string is flagged" "no warning emitted"
fi
rm -rf "$dir"

echo
echo "───────────────────────────────────"
echo -e "${BOLD}$PASS passed, $FAIL failed${NC}"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
exit 0
