# ADR 0006: Security tool placement — co-located by pipeline stage

**Status**: Accepted (2026-09-23)

## Context

While planning the DAST (ZAP) and SAST/SCA (Bandit, pip-audit) additions, two alternative
groupings were considered: a dedicated `security.yml` workflow file, and a `security`/`quality`
job split inside `pr-validation.yml`. See
[research.md D9](../../specs/001-cicd-devsecops-demo/research.md#d9-security-tool-placement-co-located-by-pipeline-stage-not-grouped-by-category).

## Decision

Every security tool lives in the workflow file that already owns the pipeline stage producing
its input artifact: Gitleaks/Bandit/pip-audit in `pr-validation.yml` (source code, every push/PR),
Trivy in `release.yml` (built image, post-build), ZAP in `deploy.yml` (running instance,
post-staging-deploy). No `security.yml`. No `security`/`quality` job split.

## Rationale

- Each tool's natural trigger is a different artifact type (source / image / running instance) —
  forcing them into one file means one workflow reacting to three unrelated event types, or a
  reusable-workflow indirection that adds a layer without removing complexity.
- A `security`/`quality` job split would blur a more important distinction: mandatory (Gitleaks,
  never skippable, constitution Principle II) vs. conditional (Bandit/pip-audit/tests, skipped
  with a stated reason for docs-only changes). Grouping by category risks silently weakening the
  mandatory guarantee or running conditional tools needlessly.
- Co-located tools reuse the same `actions/checkout`/`actions/setup-python` a job already pays
  for, avoiding duplicate setup cost that a category-based file/job split would reintroduce.

## Consequences

- Job/workflow names carry both signals: security tools are named to say so explicitly (e.g.
  "Quality & Security Gate: Tests, SAST, Dependency Scan"), even though they're not physically
  grouped in their own file or job.
- Anyone auditing "what security controls exist" must read three workflow files instead of one —
  accepted trade-off; `SECURITY.md` and this ADR exist precisely to give that reader a single
  place to start instead.
