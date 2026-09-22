# Contract: GitHub Events → Workflows

| Event | Workflow | Runs (policy-gated) | Never runs |
|---|---|---|---|
| `push` to a non-`main` branch | `pr-validation.yml` | Secret scan; lint; unit tests + coverage if `application`/`pipeline_infra` change | Docker build/scan/deploy (PR pipeline never deploys) |
| `pull_request` → `main` | `pr-validation.yml` | Same as above, as required status checks gating merge | Release, build-for-registry, deploy |
| `push` to `main` (post-merge) | `release.yml` | Release Please step (opens/updates release PR, or — on merging the release PR — tags + GitHub Release); on an actual release: build once, push to GHCR, Trivy scan | A second build anywhere downstream |
| `release.yml` successful build+scan | `deploy.yml` (called, not a separate trigger) | Deploy digest to `staging` → health check → smoke test → (manual approval) → promote same digest to `production` → health check → smoke test | Rebuilding the image |
| `workflow_dispatch` on `rollback.yml` | `rollback.yml` | Resolve previous known-good digest for the chosen environment (or use a supplied digest input) → `deploy.sh` | Any build step |
| `workflow_dispatch` on `deploy.yml` (manual promote) | `deploy.yml` | Same as the automatic path, for re-running a promotion without a new commit | Any build step |

**Composite/reusable design** (Principle VII / brief §31): `deploy.yml` is a reusable workflow
called both from `release.yml` and directly via `workflow_dispatch`, so the promote logic exists
once. `pr-validation.yml` and `release.yml` both start with the same `classify-change` composite
action (wrapping `scripts/classify_change.py`) so the policy logic exists once and is unit-tested
independently of any workflow YAML.

**Required status checks on the `main` branch ruleset**: secret scan (always), lint (always),
unit tests (when classification ≠ `docs_only`). Documentation-only PRs therefore still have a
small, fixed set of required checks — never zero — consistent with FR-016 (mandatory gates are
never removed by policy).
