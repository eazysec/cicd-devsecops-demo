# ADR 0005: Rollback strategy

**Status**: Accepted (2026-09-22)

## Context

spec.md User Story 5 requires restoring production to a previous known-good artifact without a
rebuild. See [contracts/deploy-script.md](../../specs/001-cicd-devsecops-demo/contracts/deploy-script.md)
and [data-model.md#deploymentrecord](../../specs/001-cicd-devsecops-demo/data-model.md#deploymentrecord).

## Decision

- **Source of truth for "previous known-good"**: the GitHub Deployments API. Every deploy
  (`deploy.yml`) creates a Deployment + Deployment Status against the target environment,
  including the digest/version in its payload. No bespoke state file or database.
- **Resolution logic** (`scripts/resolve_previous_digest.py`) is a pure function — no network
  calls — that picks the most recent `status == "success"` record, excluding the current/failing
  one. It is unit-tested (`tests/unit/test_resolve_previous_digest.py`) without any live
  infrastructure.
- **Two entrypoints, one mechanism**:
  1. **Automatic**: `deploy.yml`'s production job calls `scripts/rollback.sh production
     <deployment_id>` when its own deploy or smoke-test step fails (Acceptance Scenario 1).
  2. **Manual**: `.github/workflows/rollback.yml` (`workflow_dispatch`) resolves a digest
     (auto or operator-supplied) and delegates to `deploy.yml`, so a manual rollback goes through
     the exact same AWS-auth/deployment-record/smoke-test path as every other deploy.
- Rollback never rebuilds; it is `deploy.sh` with an older digest, full stop.

## Known limitation

If GHCR ever garbage-collects an old, unreferenced image digest (not expected under normal
retention settings for a low-traffic public package, but not contractually guaranteed either),
that specific rollback target becomes unpullable. Mitigation: keep at least the last several
released versions' tags referenced (Release Please's GitHub Releases already do this
indefinitely), and treat "rollback target too old to exist" as a documented, surfaced failure
(`docker pull` fails loudly in the SSM command output) rather than a silent no-op.

## Consequences

- Rollback is fully testable without live AWS/GitHub infrastructure (the resolution logic), while
  the actual redeploy reuses `deploy.yml`'s already-verified path — no second, divergent
  "rollback deploy" implementation to keep in sync.
