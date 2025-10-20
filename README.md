# pre-commit-hooks

Shared Bash-based pre-commit/pre-push hooks for consistent quality, security, and hygiene across projects. Tools are auto-detected and skipped if not installed. Hooks scope to staged files when available; otherwise they fall back to a repository-limited sample to keep runs fast.

## Quick start

1. Install pre-commit:
   - Homebrew: `brew install pre-commit`
   - Pip: `pipx install pre-commit` or `pip install pre-commit`
2. Add to your repo’s `.pre-commit-config.yaml`.

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

## GitHub Action (Marketplace)
Use this repo as a composite action that runs each hook as its own step with per-check toggles.

Minimal example (only file-quality and python):
```yaml path=null start=null
name: CI
on: [push, pull_request]
jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.x' }
      - name: Install optional tools
        run: |
          python -m pip install --upgrade pip || true
          pip install black isort flake8 mypy || true
          curl -sSL https://github.com/rhysd/actionlint/releases/latest/download/actionlint_Linux_x86_64.tar.gz | sudo tar -xz -C /usr/local/bin actionlint || true
          SHFMT_VERSION=3.8.0
          curl -sSL -o /tmp/shfmt "https://github.com/mvdan/sh/releases/download/v${SHFMT_VERSION}/shfmt_v${SHFMT_VERSION}_linux_amd64" && sudo install -m 0755 /tmp/shfmt /usr/local/bin/shfmt || true
      - uses: calebsargeant/pre-commit-hooks@v1
        with:
          stage: pre-commit
          run_file_quality: 'true'
          run_python: 'true'
          run_security: 'false'
          run_javascript: 'false'
          run_terraform: 'false'
          run_docker: 'false'
          run_license: 'false'
          run_code_metrics: 'false'
          run_performance: 'false'
          run_precommit_basic: 'false'
```

Optional reusable workflow with job-per-check granularity:
```yaml path=null start=null
name: Hooks CI
on: [push, pull_request]
jobs:
  hooks:
    uses: calebsargeant/pre-commit-hooks/.github/workflows/hooks-ci.yml@v1
    with:
      stage: pre-commit
      run_file_quality: true
      run_python: true
      run_javascript: false
      run_terraform: false
      run_docker: false
      run_security: true
      run_license: false
      run_code_metrics: false
      run_performance: false
      run_precommit_basic: true
```

Inputs (composite action):
- stage: pre-commit | pre-push (default: pre-commit)
- fail_on_high_severity: 'true' | 'false' (default: 'true')
- fail_on_medium_severity: 'true' | 'false' (default: 'false')
- run_file_quality, run_security, run_python, run_javascript, run_terraform, run_docker, run_license, run_code_metrics, run_performance, run_precommit_basic: 'true' | 'false'

Performance notes:
- Hooks prefer staged files; repo-wide fallbacks are bounded (head -N) to keep runs fast.
- Security scan and Terraform checks can be heavy; they are staged-gated and/or pre-push by default.
