# CHANGELOG

<!-- version list -->

## v1.5.1 (2026-09-07)

### Bug Fixes

- **terraform-quality**: Only flag interpolation-only strings as deprecated
  ([`27a46f4`](https://github.com/CalebSargeant/pre-commit-hooks/commit/27a46f4d91280336a6f37b71387ce0b13ac0fed6))

- **terraform-quality**: Use the terragrunt v1 CLI for HCL formatting
  ([`bd45706`](https://github.com/CalebSargeant/pre-commit-hooks/commit/bd4570689d238747493373d9bdf71b8e94943a5e))

- **tests**: Mark test-hooks.sh executable
  ([`340c835`](https://github.com/CalebSargeant/pre-commit-hooks/commit/340c835d0103e0c8f8adacd77bb4bbd4bc49b84f))


## v1.5.0 (2026-08-23)

### Features

- **hooks**: Strip AI co-author trailers at commit-msg
  ([`1a2edda`](https://github.com/CalebSargeant/pre-commit-hooks/commit/1a2eddadaa5f36b227ea70cebf107d57cf62f77c))


## v1.4.4 (2026-08-03)

### Bug Fixes

- **file-quality**: Validate multi-document YAML with safe_load_all
  ([`493639e`](https://github.com/CalebSargeant/pre-commit-hooks/commit/493639e025f6af33b7b0c49591066f4101cee662))

- **hooks**: Stop SIGPIPE from aborting hooks under pipefail
  ([`e68d2f0`](https://github.com/CalebSargeant/pre-commit-hooks/commit/e68d2f0930c949877c4b88afc6b8ce4b28bd984e))

- **security-check**: Pass the binary argument to IaC tool invocations
  ([`3109465`](https://github.com/CalebSargeant/pre-commit-hooks/commit/3109465d50363d0a243b4f3dab3f8feaec5619a3))


## v1.4.3 (2026-06-03)

### Bug Fixes

- **readme**: Align Cinnabar CI description with intro
  ([`b1cba5c`](https://github.com/CalebSargeant/pre-commit-hooks/commit/b1cba5c252b18f1bfe95a79d0bc115ca43188acd))

- **README**: Clarify that only security scanning moved to Cinnabar, not linting hooks
  ([`ecf8833`](https://github.com/CalebSargeant/pre-commit-hooks/commit/ecf883386d1c650eb933be8a3a90d7cd7c220940))

- **readme**: Update Cinnabar link to note private repo
  ([`5167230`](https://github.com/CalebSargeant/pre-commit-hooks/commit/5167230ddbd5c29ea4e236ce97f215cedf8a8c23))

- **README**: Update Cinnabar repo owner from MagmaMoose to CalebSargeant
  ([`aeae633`](https://github.com/CalebSargeant/pre-commit-hooks/commit/aeae6333435c627ae50683be9b3f684f1d8a04bb))

### Documentation

- Align repo summary with stated focus list
  ([`e6700f4`](https://github.com/CalebSargeant/pre-commit-hooks/commit/e6700f4ee83a382ce2683d407495da136034e406))

- Refocus on formatting/hygiene; point security+lint to Cinnabar
  ([`259e7c8`](https://github.com/CalebSargeant/pre-commit-hooks/commit/259e7c8eac4a1d3bad679a10d7500647f4881fe0))

- Tighten Cinnabar scope description in README
  ([`5d63b11`](https://github.com/CalebSargeant/pre-commit-hooks/commit/5d63b112de889d15020d87662bb36f05cbac4e9d))

- **readme**: Add GitHub Actions SHA-pinning to repo description
  ([`82039b5`](https://github.com/CalebSargeant/pre-commit-hooks/commit/82039b5379e52ef90fbb96f00131f257b0133df9))

- **readme**: List all hooks overlapping with Cinnabar
  ([`d90f696`](https://github.com/CalebSargeant/pre-commit-hooks/commit/d90f6965a0629da2449b8556a0b5cef05b5ddbba))

- **README**: Pin Cinnabar example to commit SHA with semver comment
  ([`bf5c0fb`](https://github.com/CalebSargeant/pre-commit-hooks/commit/bf5c0fbb63f1374a446e93122b32f20187b0d3e2))


## v1.4.2 (2025-10-25)

### Chores

- **deps**: Bump CalebSargeant/reusable-workflows from 1.0.1 to 1.0.3
  ([`af3ff20`](https://github.com/CalebSargeant/pre-commit-hooks/commit/af3ff20490f840e8e6343e4c4b3d2c5b18232222))


## v1.4.1 (2025-10-22)

### Bug Fixes

- Correct YAML validation script to properly pass file arguments to Python
  ([`f1297d9`](https://github.com/CalebSargeant/pre-commit-hooks/commit/f1297d918e1187b66587079ca3336528617be8b9))


## v1.4.0 (2025-10-22)

### Bug Fixes

- Change shebang in ci-merge-gate.sh to use /bin/sh for better compatibility
  ([`8803f83`](https://github.com/CalebSargeant/pre-commit-hooks/commit/8803f8317aacf53658ad2b5afcd12c87395deaf5))

- Enhance GitHub Actions CI by adding download messages for tools
  ([`2e5862f`](https://github.com/CalebSargeant/pre-commit-hooks/commit/2e5862f3557c6f73560b2e75d2a776370cbc3b11))

- Export BIN variable for tool installation in GitHub Actions CI
  ([`7ba413c`](https://github.com/CalebSargeant/pre-commit-hooks/commit/7ba413c99e04ef69b47e9d2e3a669757b80fb359))

- Improve merge gate checks and enhance validation for various file types
  ([`2936b6f`](https://github.com/CalebSargeant/pre-commit-hooks/commit/2936b6f2dcb1e7a1d52c393469a2927e3fc963dc))

- Improve YAML file validation in file-quality.sh to ensure only existing files are processed
  ([`9fcbeff`](https://github.com/CalebSargeant/pre-commit-hooks/commit/9fcbeffb965ecf0881458669c1e396f31fcd530d))

- Make ci-merge-gate.sh executable before running in GitHub Actions CI
  ([`09243bb`](https://github.com/CalebSargeant/pre-commit-hooks/commit/09243bb4f7f66d7ccccd158e901e54e51ffe4fde))

- Optimize GitHub Actions CI by adding caching for tools and Python dependencies
  ([`57b38dd`](https://github.com/CalebSargeant/pre-commit-hooks/commit/57b38dd41259c8d9d7f1e7bc0abdda24fa1184d9))

- Refactor GitHub Actions CI to consolidate setup steps and improve merge gate checks
  ([`a6c6a58`](https://github.com/CalebSargeant/pre-commit-hooks/commit/a6c6a58c5e15ca947bf596dc4854b8a8c66f3b29))

- Refactor GitHub Actions CI to consolidate setup steps and improve merge gate checks
  ([`70a0c7e`](https://github.com/CalebSargeant/pre-commit-hooks/commit/70a0c7e5e22a95f5cba71b8cbb225c3cac88af19))

- Update GitHub Actions CI to dynamically fetch latest tool versions
  ([`089e6fb`](https://github.com/CalebSargeant/pre-commit-hooks/commit/089e6fb6938d497230c1fc069315bb0b35750b03))

- Update GitHub Actions CI to use versioned actions and streamline tool setup
  ([`1f843a3`](https://github.com/CalebSargeant/pre-commit-hooks/commit/1f843a38f6054715201aab78eae02575f43d6d98))

- Update GitHub Actions CI to use versioned actions for actionlint and tfsec
  ([`20bf429`](https://github.com/CalebSargeant/pre-commit-hooks/commit/20bf429de5f8c95717df168f78ddb023536031c2))

- Update Trivy download command to support new naming convention and architecture
  ([`4f20a52`](https://github.com/CalebSargeant/pre-commit-hooks/commit/4f20a52944b48673716d24a4baaa6aa44760a3eb))

- Update Trivy download URL to support multiple architectures
  ([`d25e611`](https://github.com/CalebSargeant/pre-commit-hooks/commit/d25e61190ca6a1c770811ad41e06c945783bce7a))

### Features

- Enhance GitHub Actions CI with setup jobs for actionlint, gitleaks, kubeconform, tfsec, trivy, and
  Python tools
  ([`0f94f02`](https://github.com/CalebSargeant/pre-commit-hooks/commit/0f94f02a3947ef64978638456e35a45b95532bdc))

- Implement merge gate CI with comprehensive checks and auto-fix capabilities
  ([`778453c`](https://github.com/CalebSargeant/pre-commit-hooks/commit/778453c3766423ba7da31053bf72fc72878aa88a))


## v1.3.0 (2025-10-22)


## v1.2.0 (2025-10-22)


## v1.1.0 (2025-10-20)


## v1.0.1 (2025-10-20)

### Bug Fixes

- Update reusable workflow reference in CI configuration
  ([`c2dd8b9`](https://github.com/CalebSargeant/pre-commit-hooks/commit/c2dd8b9a45e64d2e97edc8370cafb25a64ee3e21))


## v1.0.0 (2025-10-20)

- Initial Release
