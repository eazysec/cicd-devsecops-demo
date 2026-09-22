# Quickstart: Validate the Feature End-to-End

Prerequisites: Python 3.13, Docker, (optionally) AWS CLI configured for manual deploy testing.

## 1. Local app

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -e ".[dev]"
ruff check .
pytest --cov=app --cov-report=term-missing
PORT=8080 flask --app app.main run
curl -s localhost:8080/health | python3 -m json.tool
```

**Expected**: lint clean, tests green, coverage report printed, `/health` returns
`{"status": "healthy", "application": "cicd-devsecops-demo", "version": "0.0.0-dev", "environment":
"local", "commit": "unknown"}` (or equivalent dev defaults per
[app-endpoints.md](./contracts/app-endpoints.md)).

## 2. Secret scanning (fake secret scenario — Scenario C)

The fake value MUST still look like a real credential to Gitleaks' default rules: a low-entropy
placeholder like `AKIAFAKEFAKEFAKEFAKE` or anything containing `EXAMPLE`/`TEST` is silently
*allowlisted* by Gitleaks' own default config (to avoid flagging AWS's own documentation samples
that appear all over open-source repos) — so it will NOT trigger a finding, which defeats the
demo. Use `scripts/generate-demo-secret.sh` to produce a fresh, random-looking (never real, never
reused) value — **never hardcode one in a tracked file**: a fixed literal value sitting in a
committed file is exactly what GitHub's own push-protection secret scanning is designed to catch,
and it will block the push of the file containing it (discovered the hard way — an earlier
version of this doc hardcoded one and got blocked pushing this very file):

```bash
git checkout -b demo/fake-secret
scripts/generate-demo-secret.sh >> app/scratch_do_not_commit.py
git add -A && git commit -m "chore: trigger fake secret for demo"
gitleaks detect --no-banner --source . --config .gitleaks.toml
```

**Expected**: Gitleaks exits non-zero. The `aws-access-token` rule always fires (fixed `AKIA...`
pattern match, not entropy-dependent); a second `generic-api-key` finding on the secret line may
or may not also appear, depending on the random value's entropy — either way, exit code is
non-zero and the run is blocked, which is the only thing the demo depends on. Then:

```bash
git reset --hard HEAD~1   # clean up the local demo branch before pushing anything real
```

## 3. Docker build + run (Emergency Demo Plan core)

```bash
bash scripts/demo-local.sh
```

**Expected**: sequential PASS output for lint → tests → secret scan → Docker build → (Trivy if
`trivy` is installed locally, else a visible "skipped: not installed" line, not a failure) →
`docker run` → `scripts/healthcheck.sh` against `localhost:8080/health` → `scripts/smoke-test.sh`.
Exits non-zero on the first failing stage, with that stage named.

## 4. Policy classification unit test

```bash
python3 scripts/classify_change.py --changed-files README.md
python3 scripts/classify_change.py --changed-files app/routes.py tests/unit/test_version.py
```

**Expected**: first call prints `docs_only`; second prints `application`.

## 5. Full pipeline (requires the GitHub repository + configured environments)

1. Open a PR that changes only `README.md` → confirm in the Checks UI that build/test/scan/deploy
   show as skipped with a reason, and only secret-scan + docs checks ran (Scenario D,
   SC-002).
2. Open a PR with an application `fix:` commit and a deliberately failing test → confirm merge is
   blocked (Scenario B) → push a fix → confirm it becomes mergeable.
3. Merge that PR → confirm the Release Please PR appears/updates → merge the Release PR → confirm
   exactly one image is built, scanned, and its digest deployed to staging then promoted
   unchanged to production (Scenario A, SC-001/SC-005).
4. Compare the digest recorded on the `staging` and `production` GitHub Deployments for that
   release → confirm identical (SC-005).
5. (Optional/backup) Trigger `rollback.yml` via `workflow_dispatch` against `production` → confirm
   the previous digest is restored and health-checked (Scenario E, SC-006).

Each step above maps 1:1 to an acceptance scenario in [spec.md](./spec.md) and is the basis for
the Conference Runbook in `README.md`.
