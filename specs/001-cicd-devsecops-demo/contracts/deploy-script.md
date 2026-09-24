# Contract: `scripts/deploy.sh` / `scripts/rollback.sh`

These scripts are the single implementation of "promote an artifact to an environment," called
identically by `deploy.yml` (release flow), `rollback.yml` (`workflow_dispatch`), and documented
for manual/emergency use from an operator's laptop with AWS credentials.

## `scripts/deploy.sh <environment> <digest>`

**Arguments**:
- `environment`: `staging` | `production`
- `digest`: full `sha256:...` digest of the image to run (never a mutable tag)

**Required environment variables** (provided by the calling workflow from GitHub
Environment secrets/variables — see [data-model.md](../data-model.md#environment-config-not-data)):
`AWS_REGION`, `EC2_INSTANCE_ID`, `APP_URL`.

**Behavior**:
1. Validates `environment` (`staging`/`production` only) and `digest` (must match
   `sha256:` + 64 lowercase hex characters) before using either — `digest` in particular is
   embedded unquoted into the shell command AWS SSM executes on the instance, and can arrive
   from an operator-supplied `workflow_dispatch` input, not only the trusted automated build
   output, so this is a command-injection guard, not just a format check.
2. Resolves the image reference as `ghcr.io/eazysec/cicd-devsecops-demo@<digest>`.
3. Sends an `AWS-RunShellScript` SSM document to `EC2_INSTANCE_ID` that runs:
   `docker pull <ref> && docker rm -f app || true && docker run -d --name app -p 80:8080
   --restart unless-stopped -e ENVIRONMENT=<environment> -e ARTIFACT_DIGEST=<digest>
   --health-cmd ... <ref>`.
4. Polls `ssm get-command-invocation` until the command reaches a terminal state, with a bounded
   timeout (default 120s); a timeout is treated as failure, never as success-by-default.
5. On SSM success, calls `scripts/healthcheck.sh "$APP_URL/health" <environment> <digest>` to
   confirm the *externally observable* result, not just "the command ran on the box."
6. Exits non-zero on any failure (SSM failure, timeout, or health-check failure), with a clear
   message identifying which stage failed.

**Idempotency**: Running the same `(environment, digest)` pair twice is safe — it just redeploys
the same image.

**Explicitly out of scope**: no build step, no image push, no mutation of anything but the named
environment's running container. This script never has access to credentials for any other
environment (enforced by the calling workflow's OIDC role scoping, not by the script itself).

## `scripts/rollback.sh <environment>`

Thin wrapper: resolves the digest of the most recent **successful** GitHub Deployment to
`environment` *before* the current one (via the GitHub Deployments API,
see [data-model.md](../data-model.md#deploymentrecord)), then calls
`deploy.sh <environment> <that digest>`. Fails clearly (no fallback guess) if no prior successful
deployment exists for that environment (Edge Cases in spec.md).

## `scripts/healthcheck.sh <url> <environment> [expected-digest]`

Retries `GET <url>` with a bounded number of attempts and backoff (default: 10 attempts, 3s
apart, i.e. ≤30s total) until it gets `200` with a JSON body whose `environment` field matches,
and — if `expected-digest` is passed — whose deployment is confirmed via the corresponding GitHub
Deployment record (the `/health` payload itself does not need to echo the digest; the workflow
already knows what it just deployed). Non-zero exit and a clear message on timeout; never hangs
indefinitely (Edge Cases in spec.md).

## `scripts/smoke-test.sh <url>`

A handful of black-box HTTP checks beyond raw health (e.g. `GET /` returns `200` and contains the
expected project name string; `GET /health` JSON validates against the schema in
[app-endpoints.md](./app-endpoints.md)). Short-circuits with a non-zero exit and the first
failing check's name on failure.
