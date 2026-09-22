# Feature Specification: CI/CD DevSecOps Live Conference Demo

**Feature Branch**: `001-cicd-devsecops-demo`

**Created**: 2026-09-22

**Status**: Draft

**Input**: User description: "Full CI/CD DevSecOps live-demo pipeline: Flask app, dynamic
policy-based GitHub Actions pipeline, security gates, build-once/promote, staging/production
deployment, rollback, conference runbook" — expanded from a detailed French brief covering the
full commit-to-production lifecycle, dynamic/policy-based pipeline execution, mandatory security
gates, SemVer + Conventional Commits release automation, build-once/promote-the-same-artifact,
GHCR, Trivy scanning, GitHub Environments for staging/production, health checks, smoke tests,
rollback, a Conference Runbook, and a network-independent Emergency Demo Plan.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Happy Path: Application Change Reaches Production (Priority: P1)

A developer fixes a bug, opens a Pull Request, watches quality and security gates pass, merges
to `main`, and watches the same reasoning play out automatically: a new version is released, one
container image is built and scanned, deployed to staging, verified, promoted **unchanged** to
production, and verified again. The live status page visibly changes from the old version to the
new one.

**Why this priority**: This is the spine of the entire demo — every other scenario is a variation
or a failure branch of this one. Without this working end-to-end, nothing else matters.

**Independent Test**: Merge a small application fix to `main` and observe, without any other
scenario being implemented, that a new PATCH release is cut, exactly one image is built, that
image reaches staging then production, and the production page shows the new version and commit
SHA.

**Acceptance Scenarios**:

1. **Given** an open Pull Request from a short-lived branch with an application code change,
   **When** all required checks (secret scan, lint, unit tests, coverage, Docker build, image
   scan) pass, **Then** the PR is mergeable and merging triggers the release pipeline.
2. **Given** a merge to `main` that includes a `fix:` Conventional Commit, **When** the release
   workflow runs, **Then** the version is bumped by PATCH (e.g. `1.0.0` → `1.0.1`), a Git tag and
   GitHub Release are created, and exactly one container image is built and pushed to the
   registry.
3. **Given** a container image has been built and scanned once, **When** it is deployed to
   staging and passes health checks and smoke tests, **Then** the identical image digest is
   promoted to production without any rebuild step.
4. **Given** the production deployment has completed, **When** a viewer loads the production URL,
   **Then** the page shows environment `production`, the new version, the correct Git SHA, and a
   healthy status, and `GET /health` returns matching JSON.

---

### User Story 2 - Documentation-Only Change Skips Irrelevant Gates (Priority: P1)

A developer changes only `README.md`. The pipeline visibly runs the minimal relevant checks
(secret scan, docs/markdown lint) and explicitly skips — with a stated reason, not silently —
unit tests, coverage, Docker build, image scan, and deployment.

**Why this priority**: This is the single clearest illustration of policy-based dynamic execution
versus "run everything every time," and it is one of the four named conference scenarios (Scenario
D). It shares all of its infrastructure with Story 1 and adds no new deployment surface, so it is
low-risk to demonstrate live.

**Independent Test**: Open a PR that touches only `README.md` and confirm in the pipeline's
job/step summary that build, test, scan, and deploy steps show as skipped-with-reason while
security scanning still ran and passed.

**Acceptance Scenarios**:

1. **Given** a PR whose changed files are all documentation (e.g. under `README.md`, `docs/`),
   **When** the pipeline evaluates its policy, **Then** it runs secret scanning and a docs check,
   and marks unit tests, Docker build, image scan, and deploy as skipped with a visible reason.
2. **Given** the same documentation-only PR, **When** it is merged to `main`, **Then** no new
   release, image build, or deployment is triggered.
3. **Given** a PR that touches both `README.md` and application code, **When** the pipeline
   evaluates its policy, **Then** it treats the change as an application change and runs the full
   gate set (documentation changes never *reduce* required scope).

---

### User Story 3 - Secret Detected Blocks the Pipeline (Priority: P1)

A developer accidentally commits a fake credential. Secret scanning fails, the pipeline shows a
red/blocked security gate, and the PR cannot be merged — no override available to the author.

**Why this priority**: This is the project's core security teaching point (Scenario C) and a
constitutional non-negotiable (Principle II). It must be demonstrably impossible for the author
of the offending commit to wave it through.

**Independent Test**: Push a branch containing a clearly fake, purpose-built secret pattern (e.g.
a dummy AWS-style key) and confirm the secret-scanning check fails, is marked required, and blocks
the PR merge button — independent of whether any other job passes.

**Acceptance Scenarios**:

1. **Given** a commit containing a fake secret matching a known secret pattern, **When** the
   pipeline runs, **Then** the secret-scanning gate fails and is reported as a required, blocking
   check.
2. **Given** a failed secret-scanning gate on a PR, **When** the PR author has no special
   repository role, **Then** the author has no in-pipeline mechanism (label, flag, commit
   message directive) to mark the gate as skipped or passing.
3. **Given** the offending commit is amended to remove the fake secret, **When** the pipeline
   re-runs, **Then** the secret-scanning gate passes and the PR becomes mergeable again (subject
   to the other gates).

---

### User Story 4 - Failing Test Blocks Merge and Deployment (Priority: P2)

A developer opens a PR that breaks a unit test. The test gate fails, the PR is blocked from
merging, and no release or deployment happens. After the fix, the same PR passes and proceeds
normally.

**Why this priority**: This is the standard "quality gate" teaching moment (Scenario B) and
reuses the same PR pipeline as Stories 1–3, so it adds negligible new surface.

**Independent Test**: Push a commit with a deliberately failing unit test, confirm the PR is
blocked from merging, then push a fix commit and confirm the same PR becomes mergeable and, once
merged, flows through release and deployment normally.

**Acceptance Scenarios**:

1. **Given** a PR containing a failing unit test, **When** the pipeline runs, **Then** the test
   gate fails, is reported as required, and blocks merge.
2. **Given** the failing test is fixed and pushed to the same branch, **When** the pipeline
   re-runs, **Then** all required gates pass and the PR becomes mergeable.

---

### User Story 5 - Production Rollback to a Known-Good Artifact (Priority: P3)

Production fails its post-deploy health check or smoke test after a promotion. The pipeline (or
an operator via a controlled manual action) restores production to the immediately preceding
known-good artifact, identified by its registry digest, without rebuilding anything, and
production is verified healthy again.

**Why this priority**: Important for teaching resilience and for demonstrating that "build once"
pays off at rollback time too, but it is the most timing-sensitive scenario to trigger live
(Scenario E), so it is lower priority than the deterministic core path and is treated as an
optional/backup demo beat rather than a guaranteed stage moment (see Assumptions).

**Independent Test**: With a previous successful production deployment on record, invoke the
rollback path (automatically on a simulated health-check failure, or manually via a controlled
operation) and confirm production ends up running the prior artifact's exact digest, verified
healthy, with the action recorded in the deployment history.

**Acceptance Scenarios**:

1. **Given** a production deployment whose post-deploy health check fails, **When** the failure
   is detected, **Then** the pipeline automatically redeploys the last known-good artifact digest
   to production rather than continuing to serve or retry the failing one.
2. **Given** an operator wants to roll back deliberately (not triggered by a failure), **When**
   they invoke the manual rollback operation and specify a target known-good version/digest,
   **Then** production is redeployed to that exact digest without any build step.
3. **Given** a rollback has completed, **When** a viewer loads the production page, **Then** it
   shows the restored version, its original commit SHA, and a healthy status.

---

### Edge Cases

- A PR changes both documentation and application code → treated as a full application change
  (policy never under-scopes based on partial docs changes).
- A vulnerability scan finds a HIGH/CRITICAL CVE with no available fix on the morning of the
  conference → pipeline must not become spuriously red; see FR-041/FR-042 for the exception
  policy.
- Two PRs merge to `main` in quick succession → each merge produces its own release; the system
  does not deploy an in-between state, only the final artifact of each completed release.
- `workflow_dispatch` is used to force a specific version/digest to be (re)promoted → this is a
  controlled, audited operation, distinct from ordinary merge-triggered releases.
- The deployment platform, registry, or GitHub itself is unreachable during the live demo → the
  local Emergency Demo Plan (FR-047–FR-050) must independently demonstrate the pre-deploy portion
  of the pipeline (lint → tests → secret scan → Docker build → scan → run → health check → smoke
  test) without any of those services.
- A secret-scanning finding is a false positive → documented exception process (FR-014) allows a
  reviewed, auditable allowlist entry; it must not be usable by a commit's own author as a silent
  bypass.
- Health check/smoke test after a staging or production deploy times out rather than failing
  fast → the pipeline must not hang indefinitely; retries are bounded and a timeout is treated as
  a failure.
- Rollback is requested but no prior known-good artifact/digest exists → the operation must fail
  clearly rather than deploying an undefined state.

## Requirements *(mandatory)*

### Functional Requirements — Application

- **FR-001**: The demo application MUST expose `GET /`, a human-readable status page showing at
  minimum: the app title, project name (`cicd-devsecops-demo`), application version, environment
  (`staging`/`production`), health status, Git commit SHA, build date/time, and artifact
  digest/identifier when available.
- **FR-002**: The demo application MUST expose `GET /health` returning machine-readable JSON
  containing at least `status`, `application`, `version`, `environment`, and `commit`.
- **FR-003**: The application MUST listen on the port given by the `PORT` environment variable.
- **FR-004**: The status page MUST remain legible when projected (large type, high contrast,
  minimal clutter).

### Functional Requirements — Quality Gates

- **FR-005**: The pipeline MUST run automated unit tests and endpoint tests for every application
  code change.
- **FR-006**: The pipeline MUST run static lint checks for every application code change.
- **FR-007**: The pipeline MUST measure and report test coverage for every application code
  change.
- **FR-008**: All quality-gate checks required for a given change type MUST complete within a
  time budget compatible with a live demo (target: total PR pipeline time under ~3 minutes for a
  small change).
- **FR-009**: A failing required quality-gate check MUST block the Pull Request from being merged.

### Functional Requirements — Security Gates

- **FR-010**: The pipeline MUST run secret scanning on every push and every Pull Request,
  regardless of change type (docs-only included).
- **FR-011**: A secret-scanning failure MUST be a required, blocking check with no author-facing
  bypass mechanism.
- **FR-012**: The repository MUST include a demonstration scenario that triggers secret scanning
  using only a fabricated, non-functional secret value; no real credential may ever be committed.
- **FR-013**: Documentation (`SECURITY.md`) MUST describe the real-world response procedure if an
  actual secret is committed (treat as compromised, rotate/revoke, address Git history).
- **FR-014**: Any mechanism for excepting a specific, reviewed finding (e.g. a confirmed false
  positive) MUST be explicit, visible in the repository (e.g. a checked-in allowlist with
  justification), and MUST NOT be triggerable by an unreviewed change from the same PR that
  introduces the finding.

### Functional Requirements — Dynamic / Policy-Based Pipeline

- **FR-015**: The pipeline MUST classify each change (by changed file paths and/or commit
  metadata) into at least: documentation-only, application change, and infrastructure/pipeline
  change, and select the step set accordingly.
- **FR-016**: Mandatory gates (secret scanning; for application changes, tests/lint/coverage;
  where Docker artifacts are produced, the image vulnerability scan) MUST run regardless of
  policy and MUST NOT be individually disableable by an author-controlled input (commit message,
  PR label, path change) on their own change.
- **FR-017**: Conditional gates (build, image scan, deploy, integration tests) MUST run only when
  relevant to the classified change type.
- **FR-018**: Every skipped step MUST be visibly reported as skipped along with the reason,
  never silently omitted from the pipeline's summary.

### Functional Requirements — GitHub Events & Git Strategy

- **FR-019**: A push to a non-`main` working branch MUST trigger fast feedback checks scoped to
  what changed.
- **FR-020**: A Pull Request targeting `main` MUST run the full applicable set of quality and
  security gates and MUST block merge on required-gate failure.
- **FR-021**: A push/merge to `main` MUST trigger the official release chain (version, build,
  scan, staging deploy, promotion) and MUST NOT run it on branch pushes or PRs.
- **FR-022**: `workflow_dispatch` MUST support at least one controlled, human-triggered operation
  useful for the demo (e.g. forcing a promotion or a rollback to a named version/digest).
- **FR-023**: The repository MUST use trunk-based development: `main` is always releasable, work
  happens on short-lived branches merged via reviewed Pull Requests, and required status checks
  gate the merge.

### Functional Requirements — Versioning & Release

- **FR-024**: The system MUST derive version bumps from Conventional Commit types on `main`
  following SemVer (`fix` → PATCH, `feat` → MINOR, breaking change → MAJOR), with no manual
  version editing.
- **FR-025**: Each release MUST produce a Git tag and, MUST create a corresponding GitHub Release
  with generated release notes/changelog.
- **FR-026**: The system MUST make the chain Commit → Release → Version → Image → Environment
  traceable, i.e. given a running environment, the exact commit and release that produced it MUST
  be discoverable from the running application and/or the registry/release metadata.

### Functional Requirements — Build, Artifact, Registry

- **FR-027**: The pipeline MUST build the application's container image at most once per release.
- **FR-028**: The built image MUST be pushed to a container registry, tagged with at least the
  SemVer version and the Git SHA, and addressable by an immutable digest.
- **FR-029**: The image MUST run as a non-root user, contain no secrets, and be built from a
  `.dockerignore`-scoped context.
- **FR-030**: The image MUST expose a Docker-level health check aligned with `GET /health`.
- **FR-031**: The project MUST build and run correctly on a local developer machine without any
  CI or cloud dependency.

### Functional Requirements — Vulnerability Scanning

- **FR-032**: Every built image MUST be scanned for known vulnerabilities before it is eligible
  for promotion to staging.
- **FR-033**: The pipeline MUST enforce an explicit, documented severity policy (which severities
  block promotion) rather than an implicit or all-or-nothing rule.
- **FR-034**: The system MUST provide a documented, auditable exception mechanism for
  vulnerabilities with no available fix, so that a newly published CVE on the day of the
  conference cannot silently or unpredictably fail the pipeline.

### Functional Requirements — Environments, Staging, Production

- **FR-035**: The system MUST model at least `staging` and `production` as distinct environments
  with separate credentials, variables, and URLs.
- **FR-036**: Staging deployment MUST be followed by an automated health check and smoke test
  before the artifact is eligible for promotion.
- **FR-037**: Production MUST receive the exact same artifact digest that was validated in
  staging — never a rebuilt or re-tagged equivalent.
- **FR-038**: The system MUST be able to demonstrate, on demand, that the digest running in
  staging and the digest running in production for a given release are identical.
- **FR-039**: Production deployment MUST be followed by an automated health check and smoke
  test.
- **FR-040**: GitHub Actions credentials/tokens used for deployment MUST follow least privilege
  (scoped per job/environment, no broader than required).

### Functional Requirements — Rollback

- **FR-041**: The system MUST be able to redeploy a previously built, known-good artifact
  (identified by digest or version) to production without rebuilding it.
- **FR-042**: A rollback action MUST be traceable (who/what triggered it, which artifact was
  restored, when).
- **FR-043**: If the chosen deployment platform limits any rollback property described above, the
  limitation MUST be documented along with the best realistic alternative.

### Functional Requirements — Documentation, Runbook, Determinism

- **FR-044**: The repository MUST include a Mermaid diagram of the complete pipeline
  (Developer → Branch → PR → Gates → main → Release → Build Once → Scan → Registry → Staging →
  Verification → Promotion → Production → Verification/Rollback).
- **FR-045**: The `README.md` MUST let another engineer reproduce the full demo without
  additional context, covering at minimum: architecture, setup, local testing, Docker usage, Git
  strategy, CI/CD events and pipelines, versioning/release automation, registry, staging,
  production, security, the dynamic pipeline policy, required secrets/variables, the deployment
  platform, rollback, troubleshooting, the Conference Runbook, and the Emergency Demo Plan.
- **FR-046**: The README MUST include a "🎤 Conference Runbook" section with a 10–15 minute
  primary scenario, where each step states what is shown, the concept it teaches, the exact
  command run, the expected result, and the recovery plan if it fails.
- **FR-047**: The repository MUST include a local, network-independent Emergency Demo Plan
  (scripts under `scripts/`) able to run lint → tests → secret scan → Docker build → (image scan
  if available) → container run → health check → smoke test without GitHub, the registry, or the
  deployment platform being reachable.
- **FR-048**: Emergency Demo Plan scripts MUST be short, readable, and independently runnable
  outside of CI.
- **FR-049**: The design MUST identify sources of non-determinism relevant to a live demo
  (mutable dependency versions, mutable Action refs, new CVEs, sleeping free-tier services,
  network/DNS, GitHub plan-gated features) and pin or mitigate each one, or provide a fallback.
- **FR-050**: The repository MUST document its security posture in `SECURITY.md` (secret
  handling, vulnerability policy, dependency policy, compromised-secret response, exception
  process).

### Key Entities

- **Application Version**: SemVer string identifying a release of the demo app; drives the
  version shown on the status page.
- **Pipeline Run**: One execution of a GitHub Actions workflow triggered by a push, PR, merge, or
  `workflow_dispatch`; has a classified change type and a resulting set of executed/skipped
  gates.
- **Gate**: A named check (e.g. secret scan, unit tests, image scan) classified as mandatory,
  conditional, or optional/informational, with a pass/fail/skip(reason) outcome.
- **Artifact**: An immutable container image identified by a registry digest, tagged with SemVer
  version and Git SHA, built at most once per release and reused across environments.
- **Environment**: A named deployment target (`staging`, `production`) with its own credentials,
  variables, URL, and currently-deployed artifact reference.
- **Release**: A tagged, versioned unit of work on `main`, linked to the commits it contains, the
  artifact it produces, and the environments it has reached.
- **Deployment Event**: A record of an artifact being deployed (or rolled back) to an
  environment, including outcome (healthy/failed) and, for rollbacks, the artifact restored.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An application bugfix merged to `main` results in a visibly updated PATCH version
  (e.g. `1.0.0` → `1.0.1`) on the production status page within one pipeline run, with no manual
  version editing.
- **SC-002**: A documentation-only change completes its pipeline run without executing any build,
  test-suite, image-scan, or deploy step, and this is visible in the run's summary.
- **SC-003**: A change containing a fabricated secret is blocked from merging by a required check
  in 100% of attempts, with no author-accessible way to override it.
- **SC-004**: A change containing a failing test is blocked from merging by a required check, and
  the same change becomes mergeable immediately after the test is fixed, with no other manual
  intervention.
- **SC-005**: For any given release, the container image digest recorded in the staging
  deployment and the digest recorded in the production deployment are identical, verifiable by
  inspection (not by re-trusting a rebuild).
- **SC-006**: A production deployment is followed by an automated verification step, and a
  simulated verification failure results in production being restored to a previously known-good
  artifact without a rebuild.
- **SC-007**: The primary live-demo scenario (happy path + at least one gate-failure scenario) is
  presentable end-to-end within 10–15 minutes.
- **SC-008**: The local Emergency Demo Plan reproduces lint, test, secret-scan, build, run, and
  health/smoke verification with zero reachable network dependency on GitHub, the registry, or
  the deployment platform.
- **SC-009**: Given any running environment (staging or production), an engineer can determine
  the exact source commit and release version that produced it using only information exposed by
  the running application and/or the registry, within under one minute.

## Assumptions

- The deployment platform (Render vs. an alternative) is a technical/architectural decision, not
  a business-scope decision; it is made and justified as an ADR during the planning phase against
  the criteria in the brief (immutable digest deploys, staging/production separation, rollback,
  cost, reliability, conference-friendliness), not asked as a clarification here.
- Likewise, the specific release-automation tool (e.g. semantic-release vs. Release Please vs. a
  minimal custom script) is decided and justified as an ADR during planning; the requirement here
  is only the observable behavior (FR-024–FR-026).
- The GitHub repository `eazysec/cicd-devsecops-demo` is public, which is assumed to unlock
  GitHub Environment protection rules (e.g. required reviewers) and unlimited Actions minutes on
  the free plan; if the repository is later made private, this MUST be re-verified and documented
  as a limitation.
- Production promotion uses a manual approval step (a GitHub Environment required reviewer) by
  default, since it is available on this public repository at no cost and is a strong,
  low-risk-to-demo teaching moment about promotion gates; this can be relaxed to automatic
  promotion via configuration if the presenter prefers a fully hands-off flow.
- Rollback (User Story 5 / Scenario E) is treated as an optional/backup demo beat rather than a
  guaranteed segment of the primary 10–15 minute run, because deliberately and reliably
  triggering a production failure live is inherently less deterministic than the other scenarios;
  it MUST still be fully implemented and independently verifiable before/after the live segment.
- The application has no authentication/authorization requirements; it is a read-only status
  display with no user accounts or sensitive data.
- "Integration tests" beyond health checks/smoke tests are in scope only if they add clear demo
  value (e.g. verifying the deployed artifact's `/health` payload matches the release metadata);
  no separate integration test environment is introduced.
- Supply-chain hardening beyond secret scanning and image vulnerability scanning (SBOM,
  provenance/attestations, image signing) is documented as a "Possible Enhancements" item rather
  than implemented, unless doing so is low-cost and directly supports another requirement (e.g. an
  SBOM emitted as a scan by-product).
- Dependabot is configured for Python, Docker, and GitHub Actions dependencies as a repository
  hygiene practice, but is not part of the live-demo narrative.
