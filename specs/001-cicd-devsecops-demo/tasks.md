# Tasks: CI/CD DevSecOps Live Conference Demo

**Input**: Design documents from `/specs/001-cicd-devsecops-demo/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Included — this feature's whole subject is CI/CD quality gates, so the test suite is
part of the deliverable, not optional scaffolding (constitution Principle II/III).

**Format**: `[ID] [P?] [Story] Description with exact file path`. `[P]` = parallelizable (distinct
files, no unmet dependency). Story labels map to spec.md: **US1**=Happy path, **US2**=Docs-only
skip, **US3**=Secret blocks pipeline, **US4**=Failing test blocks merge, **US5**=Rollback.

**Agent-executable vs. manual**: tasks marked **(manual)** create real external resources (AWS,
GitHub) this agent has no credentials for; the agent instead produces the exact
script/config/instructions so a human can execute them, and the corresponding validation is
reported `NOT VERIFIED` until done.

---

## Phase 1: Setup

- [ ] T001 Create the repository skeleton directories: `app/templates/`, `tests/unit/`,
      `tests/integration/`, `scripts/`, `.github/workflows/`, `.github/actions/classify-change/`,
      `docs/adr/`, `docs/diagrams/` (per plan.md Project Structure)
- [ ] T002 Create `pyproject.toml` with project metadata, runtime deps (`flask`, `gunicorn`) and
      dev deps (`pytest`, `pytest-cov`, `ruff`) as optional-dependencies group `dev`, plus
      `[tool.pytest.ini_options]`, `[tool.coverage.run]`, and `[tool.ruff]` sections
- [ ] T003 [P] Create `.gitignore` (Python: `.venv/`, `__pycache__/`, `.pytest_cache/`,
      `.coverage`, `*.egg-info/`) and add `.claude/` per Spec Kit's own security note
- [ ] T004 [P] Create `.dockerignore` (`.git`, `.venv`, `tests/`, `specs/`, `docs/`, `*.md` except
      none needed at runtime)
- [ ] T005 [P] Create `.gitleaks.toml` with the default ruleset extended, and an empty, documented
      `[[allowlist]]` section whose header comment states the exception rule from FR-014
      (reviewed + justified, never usable by the introducing PR's own author to silently pass)
- [ ] T006 [P] Create `.trivyignore` with a header comment documenting the D5 policy (only
      no-fix-available or sub-HIGH findings may appear here, each line commented with CVE id,
      reason, and a re-review date)
- [ ] T007 [P] Create `.github/dependabot.yml` covering `pip` (`/`), `docker` (`/`), and
      `github-actions` (`/`) ecosystems, weekly schedule, per spec.md Assumptions (Dependabot is
      hygiene, not part of the live narrative)

**Checkpoint**: repo scaffolding exists; nothing runnable yet.

---

## Phase 2: Foundational (blocking prerequisites)

**⚠️ No user story phase may start before this phase is complete.**

- [ ] T008 Implement `app/version.py`: reads `VersionMetadata` fields from environment variables
      per data-model.md — `APP_VERSION` (validate `^\d+\.\d+\.\d+$`, default `"0.0.0-dev"`),
      `GIT_SHA` (default `"unknown"`), `BUILD_TIME` (default `"unknown"`), `ENVIRONMENT` (must be
      one of `staging`/`production`/`local`, default `"local"`), `ARTIFACT_DIGEST` (optional,
      `None` if unset) — invalid `APP_VERSION`/`ENVIRONMENT` values raise a clear error at
      startup rather than serving bad data
- [ ] T009 Implement `app/__init__.py` Flask app factory (`create_app()`) wiring config from
      `app/version.py` and registering the blueprint from `app/routes.py`
- [ ] T010 Implement `app/routes.py`: `GET /` renders `app/templates/index.html` with the
      `VersionMetadata` fields (always `200`, per contracts/app-endpoints.md); `GET /health`
      returns the exact JSON shape and field constraints from
      contracts/app-endpoints.md (`status` literal `"healthy"`, `application` literal
      `"cicd-devsecops-demo"`, `version` matching `^\d+\.\d+\.\d+$` or the dev default,
      `environment` one of the three enum values, `commit` non-empty)
- [ ] T011 Implement `app/templates/index.html`: large type, high-contrast, minimal-clutter status
      page (FR-004) showing title `🚀 DevOps / DevSecOps Live Demo`, project name
      `cicd-devsecops-demo`, version, environment, health status, Git SHA, build time, and
      digest ("n/a" when absent) — FR-001
- [ ] T012 Implement `app/main.py`: entrypoint calling `create_app()` and binding to
      `0.0.0.0:$PORT` (default `8080` if `PORT` unset) — FR-003
- [ ] T013 [P] Write `tests/unit/test_version.py` asserting every validation rule from
      data-model.md's VersionMetadata table (valid/invalid SemVer, invalid environment value
      rejected, all four defaults applied when env vars are unset)
- [ ] T014 [P] Write `tests/integration/test_endpoints.py` using Flask's test client: `GET /`
      returns `200` and contains the project name and version strings; `GET /health` returns
      `200`, `Content-Type: application/json`, and a body matching every field/constraint in
      contracts/app-endpoints.md
- [ ] T015 Create `Dockerfile`: `python:3.13-slim` (or equivalent) base, `linux/amd64` (D7),
      non-root `USER` (FR-029), `ARG`/`ENV` for `APP_VERSION`/`GIT_SHA`/`BUILD_TIME` baked at
      build time (data-model.md note: `ENVIRONMENT`/`ARTIFACT_DIGEST` are **not** baked in — they
      stay run-time `-e` vars), `gunicorn` as the run command (not Flask's dev server), a
      `HEALTHCHECK` instruction hitting `GET /health` (FR-030)
- [ ] T016 Implement `scripts/classify_change.py`: pure function + CLI (`--changed-files ...`)
      implementing the `ChangeClassification` rules from data-model.md — doc-like paths
      (`**/*.md`, `docs/**`) only ⇒ `docs_only`; any path under `.github/workflows/`, `Dockerfile`,
      `scripts/` ⇒ `pipeline_infra`; anything else ⇒ `application`; a mix of docs + non-docs paths
      MUST resolve to `application`, never `docs_only` (FR-015); prints `change_type` plus one
      `reasons` line per decision
- [ ] T017 [P] Write `tests/unit/test_classify_change.py` covering: docs-only input → `docs_only`;
      mixed docs+code input → `application` (never downgraded); workflow/Dockerfile/scripts path →
      `pipeline_infra`; empty input → sensible default
- [ ] T018 Implement `scripts/healthcheck.sh <url> <environment> [expected-digest]` per
      contracts/deploy-script.md: bounded retries (default 10 attempts, 3s apart, ≤30s total),
      exits non-zero with a named failure reason on timeout or environment mismatch, never hangs
      indefinitely (Edge Cases in spec.md)
- [ ] T019 [P] Implement `scripts/smoke-test.sh <url>` per contracts/deploy-script.md: checks
      `GET /` for `200` + project-name string, `GET /health` for schema validity; exits non-zero
      naming the first failing check
- [ ] T020 Create `.github/actions/classify-change/action.yml`: composite action running
      `python3 scripts/classify_change.py --changed-files ${{ steps.diff.outputs.files }}` (using
      `git diff --name-only` against the PR base or previous push SHA) and exposing
      `change_type` as an action output, so no workflow duplicates this logic (plan.md Structure
      Decision)

**Checkpoint**: `pytest` passes, `docker build` succeeds, the classifier is independently
testable. All user stories can now proceed.

---

## Phase 3: User Story 1 — Happy Path to Production (P1) 🎯 MVP

**Goal**: merge → release → build once → scan → staging → verify → promote same digest →
production → verify (spec.md US1).

**Independent Test**: quickstart.md §5.3–5.4.

- [ ] T021 [US1] Create `.github/workflows/pr-validation.yml`: triggers on `push` (non-`main`
      branches) and `pull_request` (→ `main`); jobs run **unconditionally** in this phase (no
      skip logic yet — that is US2's job): call `.github/actions/classify-change`, Gitleaks
      (`gitleaks-action`, pinned by SHA per D4), Ruff lint, `pytest --cov`; all four are declared
      as required status checks in the job names so a `main` branch ruleset can reference them
- [ ] T022 [US1] Create `.github/release-please-config.json` and
      `.github/.release-please-manifest.json`: single package at repo root, `release-type` chosen
      per research.md D2 (`simple`, current version `1.0.0`), Conventional Commits mapping
      (`fix`→patch, `feat`→minor, `!`/`BREAKING CHANGE`→major) — FR-024
- [ ] T023 [US1] Create `.github/workflows/release.yml`: triggers on `push` to `main`; step 1 runs
      `googleapis/release-please-action` (pinned by SHA); if it reports a release was created,
      step 2 builds the Docker image **once** with `docker/build-push-action` (pinned by SHA),
      tags it with the released SemVer and the Git SHA, pushes to GHCR, and captures the pushed
      **digest** as a job output (Principle I — no other job in this repo may build this image)
- [ ] T024 [US1] Extend `release.yml`: after push, run `aquasecurity/trivy-action` (pinned by SHA)
      against the pushed image reference with the D5 policy (`severity: HIGH,CRITICAL`,
      `ignore-unfixed: true`, `exit-code: 1`), uploading the SARIF report as a build artifact
      regardless of pass/fail (FR-032/FR-033)
- [ ] T025 [US1] Create `.github/workflows/deploy.yml` as a `workflow_call` reusable workflow with
      inputs `environment` (`staging`|`production`) and `digest` (string): configures AWS
      credentials via OIDC (`aws-actions/configure-aws-credentials`, pinned by SHA) assuming the
      environment-scoped role, runs `scripts/deploy.sh "$environment" "$digest"`, then creates/
      updates a GitHub Deployment + Deployment Status against that environment recording
      `digest`/`version` in the payload (data-model.md DeploymentRecord) — the `production` job
      uses `environment: production` so the repo's required-reviewers protection rule applies
- [ ] T026 [US1] Wire `release.yml` to call `deploy.yml` twice after a successful build+scan: once
      with `environment: staging`, and — only if the staging call succeeds — once with
      `environment: production`, both passing the **same** digest output from T023 (never a
      second build) — Principle I enforcement point
- [ ] T027 [US1] Implement `scripts/deploy.sh <environment> <digest>` per
      contracts/deploy-script.md: resolves `ghcr.io/eazysec/cicd-devsecops-demo@<digest>`, sends
      an `AWS-RunShellScript` SSM document to `$EC2_INSTANCE_ID` running
      `docker pull ... && docker rm -f app || true && docker run -d --name app -p 80:8080
      --restart unless-stopped -e ENVIRONMENT=<environment> -e ARTIFACT_DIGEST=<digest> <ref>`,
      polls `aws ssm get-command-invocation` to a terminal state with a 120s bounded timeout
      (timeout ⇒ failure), then calls `scripts/healthcheck.sh "$APP_URL/health" <environment>`
- [ ] T028 [P] [US1] Write `docs/adr/0001-deployment-platform.md`: record decision D1 (AWS EC2 +
      SSM, OIDC, no SSH) including the user's explicit AWS-preference override of the brief's
      original Render suggestion, and the rejected alternatives (Render, Cloud Run, App Runner,
      Fargate, Lambda) with the one-line reason each was rejected
- [ ] T029 [P] [US1] Write `docs/adr/0002-release-automation.md` recording decision D2
      (Release Please over semantic-release)
- [ ] T030 [P] [US1] Write `docs/adr/0003-registry.md` recording decision D3 (public GHCR)
- [ ] T031 [P] [US1] Write `docs/adr/0004-build-once-promote.md` documenting exactly which
      workflow step performs the single build (T023) and how T026 guarantees no rebuild
      (Principle I)
- [ ] T032 [US1] Write `docs/diagrams/pipeline.mmd` (or inline in README, T0## in Polish): Mermaid
      diagram of the full pipeline exactly as enumerated in spec.md/brief §34
      (Developer→Branch→PR→Gates→main→Release→Build Once→Scan→Registry→Staging→Verification→
      Promotion→Production→Verification/Rollback) — FR-044
- [ ] T033 **(manual)** [US1] `docs/aws-setup.md`: step-by-step instructions (this agent cannot
      execute them — no AWS credentials) to create the two `t3.micro` EC2 instances (Amazon Linux,
      SSM Agent + Docker pre-installed via user-data), the IAM OIDC provider for
      `token.actions.githubusercontent.com`, and the two environment-scoped IAM roles
      (`ssm:SendCommand`/`ssm:GetCommandInvocation` limited to each instance's ARN) — referenced
      by T025/T027
- [ ] T034 **(manual)** [US1] `docs/github-environments-setup.md`: exact steps to create the
      `staging` and `production` GitHub Environments, their `AWS_ROLE_ARN`/`EC2_INSTANCE_ID`/
      `APP_URL` variables and secrets, and the `production` required-reviewers protection rule
      (data-model.md Environment config table)

**Checkpoint**: with T033/T034 done manually, a merge to `main` should flow end-to-end. Code side
is independently verifiable via quickstart.md §1–4 without any of the manual steps.

---

## Phase 4: User Story 2 — Documentation-Only Change Skips Gates (P1)

**Goal**: a docs-only PR visibly skips build/test/scan/deploy with a stated reason (spec.md US2).

**Independent Test**: quickstart.md §5.1.

- [ ] T035 [US2] Extend `.github/workflows/pr-validation.yml` (T021): gate the unit-tests job
      behind `if: needs.classify.outputs.change_type != 'docs_only'`; Gitleaks and lint remain
      unconditional (FR-016) — this is the only change from T021's unconditional version
- [ ] T036 [US2] Add a `GITHUB_STEP_SUMMARY` write to every conditionally-skipped job (and to jobs
      that ran) stating the change type and the reason it ran/was skipped, so the pipeline run's
      summary page reads like the brief's example table (§6) rather than leaving skipped jobs
      unexplained (FR-018)
- [ ] T037 [US2] Confirm (via T023's own logic — no code change expected, verification task) that
      a `docs:`-only commit produces no Release Please version bump, so `release.yml`'s build step
      never runs for a docs-only merge — document this inference in
      `docs/adr/0002-release-automation.md` (extends T029) rather than adding new gating logic
- [ ] T038 [P] [US2] Write `tests/unit/test_classify_change.py` additional cases (extends T017):
      a PR touching only `README.md` plus a nested `docs/*.md` file still resolves to `docs_only`

**Checkpoint**: docs-only and mixed PRs both behave per spec.md Edge Cases; US1's full-run path is
untouched for application changes.

---

## Phase 5: User Story 3 — Secret Detected Blocks the Pipeline (P1)

**Goal**: a fake secret fails Gitleaks, blocks merge, with no author-facing bypass (spec.md US3).

**Independent Test**: quickstart.md §2.

- [ ] T039 [US3] Flesh out `.gitleaks.toml` (extends T005): confirm the default+extended ruleset
      catches common fake-but-realistic patterns (AWS-style `AKIA...`, generic high-entropy
      strings); document in a header comment that `[[allowlist]]` entries require a PR review
      from someone other than the introducing PR's author before merge (enforced by normal GitHub
      review rules, not by tooling) — FR-014
- [ ] T040 **(manual)** [US3] `docs/branch-protection.md`: exact ruleset/branch-protection settings
      for `main` (this agent cannot configure them without repo admin API access) — required
      status checks include the Gitleaks job by name from T021, no bypass list includes the PR
      author's own role, administrators not exempted from the secret-scan check
- [ ] T041 [US3] Write `SECURITY.md` §"Compromised secret response": treat as compromised
      immediately, rotate/revoke at the provider, assess Git history exposure, and note when
      history rewrite is warranted vs. rotation alone being sufficient (FR-013)
- [ ] T042 [US3] Write `SECURITY.md` §"Fake-secret demo": explicit statement that the repository's
      demo scenario (quickstart.md §2) uses only a syntactically-matching, non-functional value,
      and this is the only place a "secret-like" string may ever appear in this repo

**Checkpoint**: quickstart.md §2 reproduces a real Gitleaks failure locally; T040 (once applied)
makes it a real blocking PR check on GitHub.

---

## Phase 6: User Story 4 — Failing Test Blocks Merge (P2)

**Goal**: a broken unit test blocks merge; fixing it unblocks the same PR (spec.md US4).

**Independent Test**: quickstart.md's pattern — break `tests/unit/test_version.py`, confirm the
PR check fails, fix it, confirm it passes; mechanically already covered by T021's unit-test job
and T035's gating (tests always run for non-docs changes), so this phase adds documentation only.

- [ ] T043 [US4] Add a "Scenario B: test failure" subsection to the README Conference Runbook
      (Polish phase owns the README file itself; this task supplies the exact
      break-commit/fix-commit diff and expected Checks UI state to drop into it) —
      cross-reference quickstart.md

**Checkpoint**: no new code; the mandatory-gate design from Phase 2/3 already satisfies FR-009.

---

## Phase 7: User Story 5 — Production Rollback (P3)

**Goal**: restore production to the previous known-good digest, automatically on a failed
post-deploy check or manually via `workflow_dispatch` (spec.md US5).

**Independent Test**: quickstart.md §5.5.

- [ ] T044 [US5] Implement `scripts/resolve_previous_digest.py`: **pure function** taking a list of
      `{ref, status, payload}` deployment records (data-model.md DeploymentRecord shape) for one
      environment and returning the digest of the most recent `status == "success"` record
      *before* the current one, or a clear "no prior known-good deployment" error (Edge Cases in
      spec.md) — deliberately network-free so it is unit-testable
- [ ] T045 [P] [US5] Write `tests/unit/test_resolve_previous_digest.py` covering: normal case
      (returns the prior digest), no-prior-deployment case (raises/returns the documented error),
      records-out-of-order case (sorts by creation time, not list order)
- [ ] T046 [US5] Implement `scripts/rollback.sh <environment>`: fetches recent Deployments for
      `environment` via `gh api repos/:owner/:repo/deployments` (or the equivalent REST call),
      pipes them into `scripts/resolve_previous_digest.py`, then calls
      `scripts/deploy.sh <environment> <resolved-digest>` (contracts/deploy-script.md)
- [ ] T047 [US5] Create `.github/workflows/rollback.yml`: `workflow_dispatch` with inputs
      `environment` (required) and `digest` (optional — if supplied, skip resolution and pass it
      straight to `deploy.sh`, enabling both "rollback to previous" and "promote/redeploy a named
      digest" from the same entrypoint per FR-022); records the rollback as a GitHub Deployment
      with a distinguishing payload field (`triggered_by: "rollback"`) for traceability (FR-042)
- [ ] T048 [US5] Extend `deploy.yml`'s production job (T025): on `scripts/deploy.sh` health-check
      failure, automatically invoke the same rollback path (T046) against `production` before
      failing the job, so a bad promotion self-heals without waiting for a human to notice
      (Acceptance Scenario 1) — the job still ends in `failure` (so the release is visibly not
      fully successful) even though production is restored
- [ ] T049 [P] [US5] Write `docs/adr/0005-rollback-strategy.md`: document that rollback always
      redeploys an existing digest (never rebuilds), the GitHub Deployments API as the source of
      truth for "previous known-good," and the documented limitation if AWS/SSM/GHCR retention
      ever makes a specific old digest unpullable (FR-043)

**Checkpoint**: rollback is fully implemented and independently testable (T045 requires no live
infrastructure); its live-demo appearance remains optional per spec.md Assumptions.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T050 Write `README.md` covering every section required by FR-045: objective, architecture
      (embed `docs/diagrams/pipeline.mmd`), prerequisites, local install, local tests, Docker
      usage, Git strategy (trunk-based, per constitution Principle IV), CI/CD events, PR pipeline,
      `main` pipeline, versioning/release automation, registry, staging, production, security,
      dynamic pipeline policy, required secrets/variables (names + purpose, no values), deployment
      platform (link ADRs), rollback, troubleshooting
- [ ] T051 Add "🎤 Conference Runbook" section to `README.md` (FR-046): 10–15 minute primary
      scenario built from quickstart.md §5.1–5.4 plus T043's Scenario B insert, each step listing
      what is shown / concept taught / exact command / expected result / recovery plan if it fails
      — Scenario E (rollback, T044–T048) included as an explicitly-labeled optional/backup segment
      per spec.md Assumptions
- [ ] T052 Add "Emergency Demo Plan" section to `README.md` (FR-047) documenting
      `scripts/demo-local.sh` usage and what it proves without any network dependency
- [ ] T053 Implement `scripts/demo-local.sh`: sequential, short, readable POSIX-sh orchestrating
      Ruff → pytest → Gitleaks (if installed) → `docker build` → Trivy (if installed, else a
      visible "skipped: not installed" line, never a failure) → `docker run` → `scripts/
      healthcheck.sh` → `scripts/smoke-test.sh`, stopping at and naming the first failing stage
      (FR-047/FR-048)
- [ ] T054 Add a "Determinism & Risk Register" section to `README.md` (FR-049): table of every
      risk identified in spec.md Edge Cases / brief §29 (mutable Action refs → D4's SHA pinning;
      new CVE morning-of → D5's fix-available-only policy; sleeping free tier → D1's always-on
      EC2; GitHub/registry/AWS unreachable → the Emergency Demo Plan; GitHub plan-gated features →
      N/A, repo confirmed public) with its mitigation
- [ ] T055 Finalize `SECURITY.md` (extends T041/T042): add vulnerability policy section
      documenting D5 verbatim, dependency policy (Dependabot config from T007), and the exception
      process (`.trivyignore`/`.gitleaks.toml` allowlist review rule)
- [ ] T056 Write `docs/diagrams/dynamic-pipeline.mmd`: second Mermaid diagram specifically for the
      policy-based execution flow (change → classify → mandatory gates always → conditional gates
      per type → visible skip reasons), referenced from README (brief §34, optional-but-valuable
      per FR-044's spirit)
- [ ] T057 Pass over every workflow/action file created in Phases 3–7 (T021, T023–T025, T047,
      T020) replacing any `uses: owner/action@vX` with `uses: owner/action@<full-sha> # vX.Y.Z`
      (D4) — verification pass, not new functionality
- [ ] T058 Add explicit `permissions:` blocks (least privilege, e.g. `contents: read` by default,
      `id-token: write` + `contents: write` only on the specific jobs that need OIDC/tag-push) and
      `timeout-minutes:` to every job in every workflow file from Phases 3–7 (brief §30, FR-040)
- [ ] T059 Add `concurrency:` groups to `pr-validation.yml` (cancel superseded runs on the same PR)
      and `release.yml` (prevent overlapping releases on `main`) — brief §30
- [ ] T060 Run and record local validation: `ruff check .`, `pytest --cov=app
      --cov-report=term-missing`, `gitleaks detect --no-banner --source .`, `docker build`,
      `docker run` + `scripts/healthcheck.sh` + `scripts/smoke-test.sh`, `actionlint` or
      equivalent YAML/workflow validation if available, `shellcheck scripts/*.sh` if available —
      record PASS/FAIL/NOT VERIFIED per check for the final report (brief §36)

---

## Dependencies & Execution Order

- **Phase 1 → Phase 2**: strict (Setup creates the files Foundational tasks populate).
- **Phase 2 → all of Phase 3–7**: strict (`app/`, `scripts/classify_change.py`,
  `.github/actions/classify-change`, `scripts/healthcheck.sh`/`smoke-test.sh` are consumed by
  every later workflow task).
- **Phase 3 (US1) → Phase 4 (US2)**: T035 edits the exact file T021 creates — sequential.
- **Phase 3 (US1) → Phase 7 (US5)**: T048 edits the exact job T025 creates — sequential; T044–T046
  are otherwise independent of US1 and could be built in parallel with Phase 3 if desired.
- **Phase 5 (US3), Phase 6 (US4)**: depend only on Phase 2/3's `pr-validation.yml` existing; no
  code changes of their own beyond T039/T041/T042/T043 (documentation), so they can run in
  parallel with each other and with Phase 4.
- **Phase 8 (Polish)**: depends on every ADR/script/workflow file existing (reads/wraps them); run
  last, except T053 (`demo-local.sh`) which only needs Phase 2 and can be pulled forward if the
  Emergency Demo Plan is needed before the full pipeline is wired up.

```text
Setup (P1) → Foundational (P2) → US1 (P3) → US2 (P4) ↘
                                        ↘ US3 (P5) ─→ Polish (P8)
                                        ↘ US4 (P6) ↗
                                        ↘ US5 (P7) ↗
```

## Parallel Execution Examples

- Within Phase 1: T003, T004, T005, T006, T007 (five independent files).
- Within Phase 2: T013 and T014 (tests) can be written in parallel with each other once T008–T012
  land, and T017 in parallel once T016 lands; T018/T019 are independent of the app code entirely.
- Within Phase 3: T028–T031 (four ADRs) are fully parallel once T021–T027 establish what they
  document.
- Across phases: Phase 5 (US3) and Phase 6 (US4) touch no shared files with each other or with
  Phase 4 (US2) beyond the already-merged T021/T035 — safe to parallelize once Phase 4 lands.

## Implementation Strategy

**MVP = Phase 1 + Phase 2 + Phase 3 (US1)**: this alone proves build-once/promote,
staging→production, and the visible version bump — the spine the brief calls non-negotiable.
Everything else (US2–US5) is layered on without modifying US1's core files except the two
documented, deliberate touch points (T035, T048). Manual `(manual)` tasks (T033, T034, T040) are
the only items outside this agent's ability to execute directly; every other task produces
verifiable, locally-testable artifacts.
