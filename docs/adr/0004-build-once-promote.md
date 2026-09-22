# ADR 0004: Build-once, promote-the-same-artifact enforcement

**Status**: Accepted (2026-09-22)

## Context

Constitution Principle I ("Build Once, Promote the Same Artifact") is the project's core
architectural invariant (brief §11). This ADR records exactly how the implementation enforces it,
so the guarantee can be verified rather than taken on faith.

## Decision

- `.github/workflows/release.yml`'s `build-scan-publish` job is the **only** job in the entire
  repository that runs `docker/build-push-action` with `push: true`. No other workflow file
  builds or pushes an image.
- That job's `steps.build.outputs.digest` (the pushed image's content digest) is passed, byte-for-
  byte, as the `digest` input to `deploy-staging` and then `deploy-production` — both are calls
  to the same reusable `deploy.yml`, and neither has a build step of its own.
- `deploy.yml`'s `deploy` job runs `scripts/deploy.sh <environment> <digest>`, which resolves the
  image strictly as `ghcr.io/<repo>@<digest>` (a digest reference, never `:latest` or any other
  mutable tag) and hands that exact reference to `docker pull` / `docker run` on the target EC2
  host.
- `scripts/rollback.sh` / `scripts/resolve_deployment_digest.sh` only ever select a digest from
  **past** successful GitHub Deployment records — never trigger a build.

## Verification

Given any release, compare the `payload.digest` field of that release's `staging` and
`production` GitHub Deployment records (Repo → Environments, or via the Deployments API) — they
must be byte-identical. This is Success Criterion SC-005 and is demonstrated live in the
Conference Runbook.

## Consequences

- A failed staging health check blocks `deploy-production` (job dependency:
  `needs: [..., deploy-staging]`) — production can never receive a digest that never passed
  staging.
- If a rebuild is ever genuinely needed (e.g. a security patch), it MUST go through a new
  Conventional Commit and a new Release Please release, producing a new version and a new digest
  — there is deliberately no "patch this image in place" path.
