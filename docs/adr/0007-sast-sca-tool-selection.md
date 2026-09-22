# ADR 0007: SAST/SCA tool selection — Bandit + pip-audit

**Status**: Accepted (2026-09-23)

## Context

Closing the "quels outils pour quels besoins" gap identified when assessing this project against
the "DevSecOps moderne" webinar theme required adding a SAST tool and a manifest-level dependency
(SCA) tool, alongside the existing Gitleaks (secrets) and Trivy (image vulnerabilities). See
[research.md D10](../../specs/001-cicd-devsecops-demo/research.md#d10-sastsca-tool-selection-bandit--pip-audit).

## Decision

**Bandit** for SAST, **pip-audit** for dependency/SCA scanning at the manifest level, both added
as steps in `pr-validation.yml`'s existing conditional test job (see [ADR
0006](./0006-security-tool-placement.md)).

## Rationale

- `pip-audit` is official PyPA tooling: free, no account or API key, queries the open OSV/PyPI
  Advisory Database — consistent with this project's standing "zero unnecessary credential"
  policy (OIDC over static AWS keys, public GHCR over a private registry).
- Bandit is the standard Python SAST linter, zero-config for a codebase this size, fast enough
  for the PR pipeline's time budget (FR-008).

## Rejected alternatives

- **Safety** — the historical default for Python dependency scanning, but its free tier's
  vulnerability database access has been restricted since its 2022-2023 shift to a commercial
  model. Rejected to keep the demo runnable by anyone who clones the repo, no signup required.
- **Snyk** — requires an account/API token; rejected for the same reason, and it would introduce
  a third-party SaaS dependency this project has deliberately avoided everywhere else.

## Consequences

- `pip-audit` and Trivy have complementary, not overlapping, blind spots: `pip-audit` inspects
  *declared* dependencies before any build happens (catches a vulnerable `flask`/`gunicorn` pin
  earlier than Trivy ever could), but — like `pip show` — cannot see code `pip` vendors
  internally under `pip/_vendor/`, which is exactly what the first real Trivy scan caught
  (`msgpack`, `pkg_resources` — see [docs/retex-webinar.md §1.3](../retex-webinar.md#13-une-vraie-vulnérabilité-trivy--investiguée-avant-dêtre-excusée)).
  Running both is deliberate, not redundant.
- New dev dependencies (`bandit`, `pip-audit`) added to `pyproject.toml`; no new runtime
  dependencies, no change to the shipped container image.
