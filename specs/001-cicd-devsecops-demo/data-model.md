# Phase 1 Data Model: CI/CD DevSecOps Live Conference Demo

This project has no database. "Data model" here means the shapes of the metadata that flow
through the pipeline and the app — what each entity from [spec.md](./spec.md#key-entities)
concretely looks like and where it lives.

## VersionMetadata

Injected into the Docker image at build time (build args → environment variables), read by the
app at startup. Never mutated at runtime.

| Field | Type | Source | Example |
|---|---|---|---|
| `APP_VERSION` | string (SemVer) | Release Please manifest / Git tag | `1.0.1` |
| `GIT_SHA` | string (40-hex, short form displayed) | `github.sha` at build time | `a1b2c3d` |
| `BUILD_TIME` | string (ISO-8601 UTC) | workflow step (`date -u +%Y-%m-%dT%H:%M:%SZ`) | `2026-09-22T14:03:11Z` |
| `ENVIRONMENT` | enum: `staging`, `production`, `local` | deploy-time env var (not build-time — same image, different env var per environment; see note) | `production` |
| `ARTIFACT_DIGEST` | string (`sha256:...`) | resolved after push, passed to deploy step; exposed to the app as an env var at container run time | `sha256:9f86d0...` |

**Note on build-once vs. `ENVIRONMENT`**: `ENVIRONMENT` is the one field that is *not* baked in at
build time — baking it in would force a rebuild per environment, violating Principle I. It is
passed as a plain container run-time environment variable (`-e ENVIRONMENT=production`) by the
deploy script, identical image either way. `APP_VERSION`, `GIT_SHA`, `BUILD_TIME` are baked in via
Docker build args because they are properties of the artifact itself, not of where it runs.
`ARTIFACT_DIGEST` is technically only known *after* the image is pushed (a digest is a hash of the
pushed manifest), so it cannot be baked into the image that produced it — it is supplied the same
way as `ENVIRONMENT`, at container run time, and is optional in the UI ("if available" per
FR-001).

**Validation rules**: `APP_VERSION` MUST match full SemVer 2.0.0 — core `\d+\.\d+\.\d+` plus
optional pre-release/build metadata (`0.0.0-dev`, `0.0.0-local`, `1.0.0-rc.1` are all valid) —
**not** just a bare `X.Y.Z`, since the local/dev defaults deliberately carry a pre-release suffix
and must validate too (a too-strict `^\d+\.\d+\.\d+$` regex was shipped initially and crashed
every local/dev container at gunicorn worker boot; fixed and covered by
`tests/unit/test_version.py::test_valid_semver_with_prerelease_and_build_metadata_accepted`).
`ENVIRONMENT` MUST be one of the enum values (the app defaults to `local` if unset, so `flask run`
on a laptop never crashes for a missing var); `/health` MUST always be able to render even if
`ARTIFACT_DIGEST` is absent (local dev has none).

## ChangeClassification

Computed once per pipeline run by `scripts/classify_change.py` from the list of changed file
paths (`git diff --name-only`).

| Field | Type | Description |
|---|---|---|
| `change_type` | enum: `docs_only`, `application`, `pipeline_infra` | Coarse classification driving `if:` conditions in workflows |
| `reasons` | list[string] | Human-readable justification per skipped/run gate, surfaced in the job summary |

**Rules** (see also FR-015/FR-016):
- Any changed path outside an allow-list of doc-like paths (`**/*.md`, `docs/**`) ⇒
  `application` (never downgraded by a mix of doc + code changes).
- Any changed path under `.github/workflows/`, `Dockerfile`, `scripts/` ⇒ `pipeline_infra`
  (treated with at least the same rigor as `application`).
- Mandatory gates (secret scan) do not consult `ChangeClassification` at all — they are wired
  unconditionally, so a bug in the classifier can never silently disable them (Principle II).

## GateResult

Not a stored entity — it is simply the natural status of a GitHub Actions job/step
(`success`/`failure`/`skipped`), read from the Checks API by branch protection. Documented here
only to fix vocabulary: a **Gate** (spec Key Entity) is mandatory, conditional, or
optional/informational; its **GateResult** for a given PipelineRun is one of those three statuses,
never silently absent from the run's UI.

## DeploymentRecord

Source of truth: the **GitHub Deployments API** (native GitHub Environments feature), not a
custom file or database. Each deploy step creates a GitHub Deployment against the `staging` or
`production` environment; each health-check outcome reports a Deployment Status
(`in_progress` → `success`/`failure`). This is what "previous known-good artifact" resolves
against for rollback: the most recent Deployment to that environment with status `success`.

| Field | Type | Source |
|---|---|---|
| `environment` | `staging` \| `production` | GitHub Environment name |
| `ref` | Git SHA | `github.sha` of the triggering run |
| `payload.digest` | `sha256:...` | custom deployment payload set by the workflow |
| `payload.version` | SemVer string | custom deployment payload |
| `status` | `in_progress`\|`success`\|`failure`\|`inactive` | set by the deploy/verify job |

**Rationale for reusing the GitHub Deployments API instead of a bespoke state file**: it is
already visible in the repository's "Environments" UI (a good on-stage visual), requires no extra
storage/locking, and is exactly what it is designed for — avoiding a bespoke mechanism honors
Principle VII.

## Environment (config, not data)

Two GitHub Environments, `staging` and `production`, each holding:

| Item | Kind | Example |
|---|---|---|
| `AWS_ROLE_ARN` | Environment secret (or repo-level variable if identical) | role assumed via OIDC, scoped to that environment's EC2 instance only |
| `EC2_INSTANCE_ID` | Environment variable | `i-0123456789abcdef0` |
| `APP_URL` | Environment variable | `https://staging.demo.example` / `https://prod.demo.example` |
| Required reviewers | Environment protection rule | production only (see plan/Assumptions) |

No secret is duplicated between environments with the same value; each environment's AWS role is
scoped to its own instance only (least privilege / blast-radius separation, FR-040).
