# CHANGELOG

<!-- version list -->

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
