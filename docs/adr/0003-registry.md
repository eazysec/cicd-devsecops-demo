# ADR 0003: Container registry — public GHCR

**Status**: Accepted (2026-09-22)

## Context

See [research.md D3](../../specs/001-cicd-devsecops-demo/research.md#d3-container-registry).

## Decision

GitHub Container Registry (`ghcr.io/eazysec/cicd-devsecops-demo`), package visibility set to
**public** after the first push (a one-time manual step — GHCR always creates new packages as
private and there is no API/workflow-time flag to publish as public on first push).

## Rationale

- Free for public repositories; authenticates in-workflow with the ambient `GITHUB_TOKEN` — no
  extra PAT/secret.
- Public visibility means the EC2 hosts (ADR 0001) need **zero** registry credentials to `docker
  pull` — the smallest possible secret surface for the deploy path.

## Rejected alternatives

- **Docker Hub**: extra account/secret to manage, anonymous pull rate limits.
- **Amazon ECR**: would have been required by Lambda (rejected in ADR 0001); not otherwise
  justified — it would remove the "zero registry credential on the box" property for no benefit.

## Consequences

- `docs/github-environments-setup.md` includes the one manual step (Package settings → Change
  visibility → Public) required after the first `release.yml` run creates the package.
