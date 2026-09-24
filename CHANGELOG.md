# Changelog

## [1.4.2](https://github.com/eazysec/cicd-devsecops-demo/compare/cicd-devsecops-demo-v1.4.1...cicd-devsecops-demo-v1.4.2) (2026-09-24)


### Bug Fixes

* validate digest format in deploy.sh before remote execution ([88b7330](https://github.com/eazysec/cicd-devsecops-demo/commit/88b7330e5df09b0728f17f5daa544763509f82bf))
* validate digest format in deploy.sh before remote execution ([0567ef8](https://github.com/eazysec/cicd-devsecops-demo/commit/0567ef8ab354c5fb4e5d9828ea165deb150d1d0d))

## [1.4.1](https://github.com/eazysec/cicd-devsecops-demo/compare/cicd-devsecops-demo-v1.4.0...cicd-devsecops-demo-v1.4.1) (2026-09-24)


### Bug Fixes

* declare GITHUB_TOKEN permissions explicitly on every job ([0a83572](https://github.com/eazysec/cicd-devsecops-demo/commit/0a83572b957e7e64784ad46bdca422d4376c4138))
* declare GITHUB_TOKEN permissions explicitly on every job ([a6281e9](https://github.com/eazysec/cicd-devsecops-demo/commit/a6281e924f9f8ec86b582ff386bd6de0025c5bfd))

## [1.4.0](https://github.com/eazysec/cicd-devsecops-demo/compare/cicd-devsecops-demo-v1.3.0...cicd-devsecops-demo-v1.4.0) (2026-09-23)


### Features

* add CodeQL as a decoupled, non-blocking SAST pass ([e939a47](https://github.com/eazysec/cicd-devsecops-demo/commit/e939a47364a922c7e047b8faf0d54b70647d24d2))
* add CodeQL as a decoupled, non-blocking SAST pass ([af0a78b](https://github.com/eazysec/cicd-devsecops-demo/commit/af0a78bf69bc3b52cbdfb98f0261191d2adeafce))

## [1.3.0](https://github.com/eazysec/cicd-devsecops-demo/compare/cicd-devsecops-demo-v1.2.0...cicd-devsecops-demo-v1.3.0) (2026-09-23)


### Features

* upload Trivy SARIF to GitHub Code Scanning, summarize ZAP findi… ([ee2bdc0](https://github.com/eazysec/cicd-devsecops-demo/commit/ee2bdc03d8530e5078f20c0808689ad33df05ee2))
* upload Trivy SARIF to GitHub Code Scanning, summarize ZAP findings in-run ([9540e6c](https://github.com/eazysec/cicd-devsecops-demo/commit/9540e6ccf5df05898591f2f7b4bbe02bdc2e4757))

## [1.2.0](https://github.com/eazysec/cicd-devsecops-demo/compare/cicd-devsecops-demo-v1.1.2...cicd-devsecops-demo-v1.2.0) (2026-09-22)


### Features

* add SAST (Bandit), dependency scanning (pip-audit), and DAST (Z… ([db47c8f](https://github.com/eazysec/cicd-devsecops-demo/commit/db47c8f5a9799c5eb4ad6ba85c07c74096465acb))
* add SAST (Bandit), dependency scanning (pip-audit), and DAST (ZAP) gates ([7d16f2f](https://github.com/eazysec/cicd-devsecops-demo/commit/7d16f2f079f5bef6c9041bec56ac924c4470f8c1))

## [1.1.2](https://github.com/eazysec/cicd-devsecops-demo/compare/cicd-devsecops-demo-v1.1.1...cicd-devsecops-demo-v1.1.2) (2026-09-22)


### Bug Fixes

* dedupe push vs pull_request runs on the same branch in pr-validation ([fb13236](https://github.com/eazysec/cicd-devsecops-demo/commit/fb132363a0aacbaa3f36042c02afc6c6a1362322))

## [1.1.1](https://github.com/eazysec/cicd-devsecops-demo/compare/cicd-devsecops-demo-v1.1.0...cicd-devsecops-demo-v1.1.1) (2026-09-22)


### Bug Fixes

* add reviewed Trivy exception for base-image build tooling CVEs ([6696fba](https://github.com/eazysec/cicd-devsecops-demo/commit/6696fba5905ad5a6a4bca4c0af498f2c3d8b9b1f))
* add reviewed Trivy exception for base-image build tooling CVEs ([4d81bb4](https://github.com/eazysec/cicd-devsecops-demo/commit/4d81bb4eda919901cba7d091c4f4bba3e32e76fb))

## [1.1.0](https://github.com/eazysec/cicd-devsecops-demo/compare/cicd-devsecops-demo-v1.0.0...cicd-devsecops-demo-v1.1.0) (2026-09-22)


### Features

* initial CI/CD DevSecOps demo implementation ([df46b05](https://github.com/eazysec/cicd-devsecops-demo/commit/df46b052f57aa1ca2f4f00324118aa6557d32d9b))


### Bug Fixes

* grant reusable deploy.yml job permissions at the calling job level ([b8e97e2](https://github.com/eazysec/cicd-devsecops-demo/commit/b8e97e22df06e8d61b6e4705946476b8400f54da))
* grant reusable deploy.yml job permissions at the calling job level ([3f791ef](https://github.com/eazysec/cicd-devsecops-demo/commit/3f791ef689e79b5fad01e31a1c497f92c041dc7a))
