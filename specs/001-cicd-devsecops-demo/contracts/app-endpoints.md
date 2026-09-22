# Contract: Application HTTP Endpoints

## `GET /`

**Purpose**: Human-readable status page for the projector (FR-001, FR-004).

**Response**: `200 text/html`, always — this endpoint never reflects the app's own health as an
HTTP status (a broken status page would be a worse demo failure than a page that honestly shows
`status: unhealthy`); health is communicated *within* the page and via `/health`.

**Must display**: title (`🚀 DevOps / DevSecOps Live Demo`), project name
(`cicd-devsecops-demo`), `APP_VERSION`, `ENVIRONMENT`, health status, `GIT_SHA`, `BUILD_TIME`,
`ARTIFACT_DIGEST` (omitted/marked "n/a" when not set, e.g. local dev).

## `GET /health`

**Purpose**: Machine-readable health for CI health checks, smoke tests, and Docker `HEALTHCHECK`
(FR-002).

**Response**: `200 application/json` when healthy. There is no dependency that can make this
service "unhealthy" at the application layer (no DB, no external call) — the endpoint always
returns `status: "healthy"` once the process is up; a `503` is only ever produced by the process
not running at all (connection refused), which is exactly what the deploy health check needs to
distinguish "old container still up" from "new container serving."

```json
{
  "status": "healthy",
  "application": "cicd-devsecops-demo",
  "version": "1.0.1",
  "environment": "production",
  "commit": "a1b2c3d"
}
```

**Schema** (all fields required, all strings):

| Field | Constraint |
|---|---|
| `status` | literal `"healthy"` |
| `application` | literal `"cicd-devsecops-demo"` |
| `version` | matches `^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$` — full SemVer 2.0.0 core with optional pre-release/build metadata (release versions are always bare `X.Y.Z`; local/dev defaults use a `-dev`/`-local` pre-release suffix, which must validate too — see [data-model.md](../data-model.md#versionmetadata)) |
| `environment` | one of `staging`, `production`, `local` |
| `commit` | non-empty short SHA (or `"unknown"` in a from-source dev run with no Git metadata injected) |

**Consumers**: `scripts/healthcheck.sh` (CI + local), `scripts/smoke-test.sh`, Docker
`HEALTHCHECK`, the status page's own client-side "healthy" badge (fetches this endpoint).

## Backward compatibility

Both endpoints are additive-only for the lifetime of this demo (no versioning scheme needed — a
single, intentionally small service). A breaking change to the `/health` JSON shape would be a
Conventional Commit `BREAKING CHANGE`, per FR-024.
