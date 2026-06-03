# pre-commit-hooks

> **Security scanning and dependency auditing have moved to [Cinnabar](https://github.com/CalebSargeant/cinnabar) (private repository).**
> Use cinnabar for Trivy, TruffleHog, Semgrep, Checkov and
> dependency audits — in CI **and** as pre-commit hooks. This repo now focuses on
> what cinnabar deliberately doesn't do: **code formatting, file hygiene, and
> GitHub Actions SHA-pinning**. The `security-scan`, `docker-security`, `terraform-quality`, and `file-quality` hooks below overlap with Cinnabar and will be removed in a future release.

Shared Bash-based pre-commit/pre-push hooks for **formatting, file hygiene, and GitHub Actions SHA-pinning**. Tools are auto-detected and skipped if not installed. Hooks scope to staged files when available; otherwise they fall back to a repository-limited sample to keep runs fast.

## Quick start

1. Install pre-commit:
   - Homebrew: `brew install pre-commit`
   - Pip: `pipx install pre-commit` or `pip install pre-commit`
2. Add to your repo's `.pre-commit-config.yaml`.

Option A: Single orchestrator (recommended)
```yaml path=null start=null
repos:
  - repo: https://github.com/calebsargeant/pre-commit-hooks
    rev: main  # pin to a tag/sha in real projects
    hooks:
      - id: all
```

Option B: Pick individual hooks
```yaml path=null start=null
repos:
  - repo: https://github.com/calebsargeant/pre-commit-hooks
    rev: main
    hooks:
      - id: file-quality           # fast hygiene (whitespace, CRLF/BOM, YAML/JSON)
      - id: actions-pin-sha        # pin Actions to SHAs with full semver comments
      - id: python-quality         # black/isort/flake8/mypy (if installed)
      - id: javascript-quality     # prettier/eslint/tsc (if installed)
      - id: terraform-quality      # fmt/validate/tflint/tfsec/checkov/terraform-docs
      - id: docker-security        # hadolint + trivy config/image
      - id: security-scan          # semgrep/bandit/safety/tfsec/checkov/trivy (pre-push)
      - id: performance-check      # advisory, does not fail by default (pre-push)
      - id: license-compliance     # dependency licenses (pre-push)
```

Then run:
```sh path=null start=null
pre-commit install
pre-commit run -a
```

## Available hooks
- all: Orchestrates everything. Stage-aware. Runs security, language checks, Docker/IaC, and (on pre-push) metrics, performance, licenses.
- file-quality: Branch protection (no commits to main/master), trailing whitespace, large files, CRLF/BOM, YAML/JSON validity, shebangs for executables.
- actions-pin-sha: Pin GitHub Actions `uses:` to full SHAs and annotate with full semver (e.g., `# v5.0.0`); if ref cannot be resolved (e.g., `v4`), falls back to latest `v4.x.y` or latest release.
- python-quality: black, isort, flake8, optional mypy.
- javascript-quality: prettier, eslint, optional tsc; supports monorepo `frontend/`.
- terraform-quality: fmt, validate, tflint, tfsec, checkov, terraform-docs (per-directory).
- docker-security: hadolint, trivy config/image, basic docker-compose hardening heuristics.
- security-scan (pre-push): bandit, safety, semgrep, tfsec, checkov, terrascan, trivy, hadolint, basic secret heuristics.
- performance-check (pre-push): lightweight build/runtime checks (advisory).
- license-compliance (pre-push): basic OSS license due diligence for Python/Node/Docker base images.

## Configuration and env vars
- FAIL_ON_HIGH_SEVERITY=true|false (default true): security-scan/run-all will fail on high issues.
- FAIL_ON_MEDIUM_SEVERITY=true|false (default false): optionally fail on medium issues.
- PRE_COMMIT_STAGE is auto-detected by run-all (pre-commit vs pre-push).
- Actions pinning:
  - PIN_SHA_VERBOSE=0|1|2 (default 1)
  - PIN_SHA_DRY_RUN=0|1 (default 0)

## Tooling auto-detection
Hooks only run tools that are already available in your environment. Recommended installs:
- General: shellcheck, shfmt, yamllint
- Python: black, isort, flake8, mypy, bandit, safety
- JS/TS: prettier, eslint, typescript (tsc)
- Terraform: terraform, tflint, tfsec, checkov, terraform-docs, terrascan
- Containers: hadolint, trivy
- Licenses: pip-licenses, license-checker

## Development
- Lint scripts: `shellcheck hooks/*.sh`
- Format scripts: `shfmt -d hooks` (show diff) or `shfmt -w hooks` (write)
- Run the orchestrator locally:
```sh path=null start=null
# Pre-commit stage
PRE_COMMIT_STAGE=pre-commit bash hooks/run-all.sh
# Pre-push stage
PRE_COMMIT_STAGE=pre-push bash hooks/run-all.sh
```

## CI scanning

For these checks in CI, use **[Cinnabar](https://github.com/CalebSargeant/cinnabar) (private repository)** — it packages the security + lint scanners as a composite GitHub Action and a reusable workflow, sharing the same logic as its pre-commit hooks:

```yaml
- uses: CalebSargeant/cinnabar@v1
```

_(Earlier versions of this README described a composite action and a `hooks-ci.yml` reusable workflow in this repo; those never shipped. Cinnabar is the supported CI path.)_
