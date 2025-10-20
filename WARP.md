# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

Project overview
- This repo is a collection of Bash-based quality and security hooks intended to be invoked directly or via pre-commit/pre-push. Tools are auto-detected and skipped if not installed. Most scripts scope checks to staged files when available, otherwise fall back to repository files.

Common commands
- Run the full pipeline (pre-commit stage):

```sh path=null start=null
PRE_COMMIT_STAGE=pre-commit bash hooks/run-all.sh
```

- Run the full pipeline (pre-push stage):

```sh path=null start=null
PRE_COMMIT_STAGE=pre-push bash hooks/run-all.sh
```

- Limit checks to specific files by staging only those files first:

```sh path=null start=null
git add path/to/file1 path/to/file2
PRE_COMMIT_STAGE=pre-commit bash hooks/run-all.sh
# (optionally) unstage afterwards
git restore --staged path/to/file1 path/to/file2
```

- Run a single check script:

```sh path=null start=null
bash hooks/python-quality.sh
bash hooks/javascript-quality.sh
bash hooks/terraform-quality.sh
bash hooks/docker-security.sh
bash hooks/file-quality.sh
bash hooks/security-check.sh
```

- Lint and format the hook scripts themselves:

```sh path=null start=null
# Lint
shellcheck hooks/*.sh
# Format (show diff or write in-place)
shfmt -d hooks
shfmt -w hooks
```

- Relax or harden failure behavior for security scans:

```sh path=null start=null
FAIL_ON_HIGH_SEVERITY=false FAIL_ON_MEDIUM_SEVERITY=false bash hooks/run-all.sh
```

Key architecture and flow
- Orchestrator: hooks/run-all.sh
  - Detects stage (pre-commit vs pre-push) via PRE_COMMIT_STAGE or PRE_COMMIT_FROM_REF.
  - Detects file types present in the current context and selectively invokes language/tooling scripts via run_validation().
  - Summarizes results and enforces failure on critical categories when configured.

- Quality/security modules (invoked by the orchestrator or directly):
  - hooks/security-check.sh: Cross-cutting security scan. Python (bandit, safety, semgrep), JS/TS (npm audit, ESLint security), IaC (tfsec, checkov, terrascan), containers (trivy, hadolint), basic secret heuristics in config files, and repo hygiene (LICENSE/SECURITY.md presence). Respects FAIL_ON_HIGH_SEVERITY/FAIL_ON_MEDIUM_SEVERITY.
  - hooks/python-quality.sh: Formatting (black), import sorting (isort), lint (flake8), optional types (mypy). Scopes to staged .py when present.
  - hooks/javascript-quality.sh: Formatting (prettier), lint (eslint), optional TS type check (tsc). Supports monorepo pattern by entering frontend/ when present.
  - hooks/terraform-quality.sh: Per-directory pipeline: terraform fmt, validate (initializes when needed), tflint, tfsec, checkov, terraform-docs; plus anti-pattern heuristics and Terragrunt formatting when .hcl files exist.
  - hooks/docker-security.sh: Dockerfile and compose checks via hadolint, trivy config, simple compose hardening heuristics; optional image scan when recent images exist.
  - hooks/file-quality.sh: Generic hygiene (block commits directly to main/master, trailing whitespace, large files, YAML lint via yamllint, JSON validity, CRLF detection, UTF-8 BOM, shebang presence for executables).
  - hooks/pre-commit-basic.sh: Runs a set of pre-commit built-in hygiene hooks (end-of-file, trailing whitespace, mixed line endings, etc.).
  - hooks/license-check.sh: Basic license due diligence for Python (pip-licenses) and Node (license-checker) with conservative allow/flag lists; also inspects Docker base image licenses.
  - hooks/code-metrics.sh: Repository metrics (cloc/radon if present) and simple security document presence checks.
  - hooks/performance-check.sh: Advisory performance smoke tests (build times, bundle/image size, terraform plan time, system memory), does not fail the commit by default.

Development notes for Warp
- All scripts cd to the repo root via git rev-parse and are safe to run from any subdirectory.
- Tools are optional; scripts print installation hints when a tool is missing and continue where reasonable.
- To exercise “staged file” code paths during development, stage a small set of files before running scripts; to exercise repository-wide paths, ensure nothing is staged.
- The orchestrator always runs security and general file checks; language- and IaC-specific checks are conditional on detected file types.
