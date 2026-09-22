# Implementation Plan: CI/CD DevSecOps Live Conference Demo

**Branch**: `001-cicd-devsecops-demo` | **Date**: 2026-09-22 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-cicd-devsecops-demo/spec.md`

## Summary

Build a small Flask status app and a GitHub Actions pipeline that together demonstrate the full
commit-to-production lifecycle for a live conference talk: policy-based dynamic gate execution,
non-bypassable secret scanning, Conventional-Commits-driven SemVer releases (Release Please),
build-once/promote-the-same-digest to AWS EC2 staging and production via SSM Run Command (no SSH,
OIDC-based least-privilege AWS auth), Trivy image scanning with a determinism-safe severity
policy, health-checked/smoke-tested deployments, and a documented rollback path — plus a fully
local, network-independent Emergency Demo Plan. See [research.md](./research.md) for the six
architecture decisions (D1–D7) and their rationale.

## Technical Context

**Language/Version**: Python 3.13

**Primary Dependencies**: Flask (app), Gunicorn (production WSGI server in the container), pytest
+ pytest-cov (tests/coverage), Ruff (lint), Gitleaks (secret scanning, via
`gitleaks-action`), Trivy (`aquasecurity/trivy-action`, image scanning)

**Storage**: N/A — the app is stateless; version/commit/build metadata is injected at build time
via environment variables / build args, not persisted

**Testing**: pytest (unit + Flask test client endpoint tests), pytest-cov (coverage), Ruff
(lint/format check) — all run locally and in CI with the same commands

**Target Platform**: Linux containers (`linux/amd64`), deployed to two AWS EC2 `t3.micro`
instances (staging, production) running Docker Engine, reached via AWS SSM Run Command; CI runs on
GitHub-hosted Ubuntu runners

**Project Type**: Single small web service + its CI/CD pipeline (not a multi-package/monorepo)

**Performance Goals**: Not performance-sensitive; a few requests/second is more than sufficient
for a conference audience hitting the status page. The one real "performance" constraint is
*pipeline* speed (see Constraints).

**Constraints**: PR pipeline (secret scan + lint + tests + coverage, application-change path)
should complete in well under 3 minutes (FR-008/SC-007); staging/production health-check-after-
deploy must use bounded retries/timeout, never hang (FR-039, Edge Cases); no step may depend on a
service that can silently go stale between rehearsal and the live talk without a documented
mitigation (Principle V).

**Scale/Scope**: One Flask service, two endpoints (`GET /`, `GET /health`), two deployment
environments, one GitHub repository, a handful of GitHub Actions workflows/composite actions, and
a `scripts/` directory of small POSIX-sh/Python scripts shared between CI and the local Emergency
Demo Plan.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Status |
|---|---|---|
| I. Build Once, Promote the Same Artifact | Single `docker/build-push-action` build step in the release workflow produces one digest; staging and production deploy jobs both consume that same digest as a workflow output/artifact — no second build job exists anywhere in the design. | PASS |
| II. Security Gates Mandatory, Author Cannot Bypass | Gitleaks runs unconditionally in the reusable PR-validation workflow, is a required status check on the `main` branch ruleset, and no workflow input/label controlled by a PR author skips it (only path-based policy adds *more* jobs, never removes this one). | PASS |
| III. Policy-Based Dynamic Execution | A single "classify change" job (script in `scripts/classify_change.py`, unit-tested) outputs a change-type used by downstream `if:` conditions; every skipped job still appears in the run (as a skipped, not absent, job) with a reason in its name/summary. | PASS |
| IV. Trunk-Based, Short-Lived Branches | Design assumes a `main` branch ruleset (required checks, no direct pushes) and short-lived feature/fix branches; no `develop`/`release` branches introduced. | PASS |
| V. Deterministic, Reproducible Demo | All GitHub Actions pinned by SHA (D4); Trivy policy designed so an unfixable/new CVE cannot flip a previously-green pipeline red (D5); EC2 always-on hosts avoid free-tier sleep (D1); `scripts/demo-local.sh` reruns the pre-deploy chain with zero network dependency on GitHub/registry/AWS. | PASS |
| VI. Traceable Versioning | Release Please derives version from Conventional Commits (D2); image tags include SemVer + Git SHA; `/health` echoes `version` + `commit`; README documents the Commit→Release→Version→Image→Environment chain. | PASS |
| VII. Minimum Viable Sophistication | No Kubernetes/Helm/Argo CD/Terraform/service mesh anywhere in the design; infra is two EC2 instances configured once (documented as manual steps + a small provisioning script), not an IaC framework, matching the constitution's explicit "no infra-complexity-for-its-own-sake" stance. | PASS |

No violations requiring Complexity Tracking entries.

## Project Structure

### Documentation (this feature)

```text
specs/001-cicd-devsecops-demo/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   ├── app-endpoints.md
│   ├── deploy-script.md
│   └── pipeline-events.md
└── tasks.md              # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
cicd-devsecops-demo/
├── app/
│   ├── __init__.py          # Flask app factory
│   ├── main.py               # entrypoint (create_app + routes wiring)
│   ├── routes.py             # GET / and GET /health handlers
│   ├── version.py            # reads build-time metadata (version, commit, build time, digest)
│   └── templates/
│       └── index.html        # status page template
│
├── tests/
│   ├── unit/
│   │   ├── test_version.py
│   │   └── test_classify_change.py
│   └── integration/
│       └── test_endpoints.py  # Flask test client: GET /, GET /health contract
│
├── scripts/
│   ├── classify_change.py     # policy engine: change-type from changed file paths
│   ├── demo-local.sh          # Emergency Demo Plan: lint→test→secretscan→build→run→verify
│   ├── healthcheck.sh          # bounded-retry health check, used by CI and locally
│   ├── smoke-test.sh           # black-box smoke tests against a running instance
│   ├── deploy.sh                # SSM Run Command wrapper: deploy <env> <digest>
│   └── rollback.sh              # thin wrapper over deploy.sh for the "previous digest" case
│
├── .github/
│   ├── workflows/
│   │   ├── pr-validation.yml    # push (branch) + pull_request → main
│   │   ├── release.yml           # push/merge → main (Release Please + build/scan/publish)
│   │   ├── deploy.yml            # reusable: staging + production deploy, called by release.yml
│   │   │                          # and by workflow_dispatch for manual promote/rollback
│   │   └── rollback.yml          # workflow_dispatch: manual rollback to a named digest
│   ├── actions/
│   │   └── classify-change/       # composite action wrapping scripts/classify_change.py
│   ├── dependabot.yml
│   └── release-please-config.json / .release-please-manifest.json
│
├── Dockerfile
├── .dockerignore
├── .gitignore
├── .trivyignore
├── pyproject.toml            # deps, pytest, ruff, coverage config
├── requirements.txt / requirements-dev.txt (or uv/pip-tools lock, per implementation)
│
├── README.md
├── SECURITY.md
└── docs/
    ├── adr/                   # short ADRs (0001-deployment-platform.md, ...)
    └── diagrams/               # Mermaid sources if not inlined in README
```

**Structure Decision**: Single-project layout (no frontend/backend split, no monorepo). `app/`
holds the Flask service, `tests/` mirrors it, `scripts/` holds every piece of logic that must be
runnable identically from CI *and* from a laptop with no network (Emergency Demo Plan), and
`.github/workflows/` stays thin — orchestration and `if:` policy only, delegating real logic to
`scripts/` and one composite action, per Principle VII and the brief's explicit "YAML must not
contain all the logic" instruction.

## Complexity Tracking

*No constitution violations — table intentionally empty.*
