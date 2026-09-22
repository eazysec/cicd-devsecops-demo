# Phase 0 Research: CI/CD DevSecOps Live Conference Demo

Each decision follows: **Decision** / **Rationale** / **Alternatives considered**.
Constitution references: [[constitution]] (`.specify/memory/constitution.md`) Principles I–VII.

---

## D1. Deployment platform: staging & production

**Decision**: Two persistent AWS EC2 instances (one per environment, `t3.micro`), each running the
Docker Engine, deployed to via **AWS Systems Manager (SSM) Run Command** — no SSH, no long-lived
AWS keys. GitHub Actions authenticates to AWS with **OIDC** (`aws-actions/configure-aws-credentials`)
and assumes a narrowly-scoped IAM role (permissions limited to `ssm:SendCommand` /
`ssm:GetCommandInvocation` against the two named instances). The deploy command is always
`docker rm -f app || true && docker run -d --name app -p 80:8080 --restart unless-stopped
ghcr.io/eazysec/cicd-devsecops-demo@sha256:<digest>`; rollback is the identical command with the
previous digest. Images are pulled directly from the **public** GHCR package — no registry
credential needs to live on the instance at all.

**Rationale**:
- **This decision was made by the user**, who already has an AWS account and asked for AWS Free
  Tier explicitly, overriding the brief's original Render suggestion — see the recorded
  clarification in this feature's history.
- AWS **App Runner** — the most Render-like managed option — stops accepting new customers as of
  2026‑04‑30 (confirmed via AWS documentation search, current as of this research), so it is not a
  viable choice for a project starting now.
- AWS **Fargate** has no free-tier allowance at all (billed from the first second); it also adds
  ECS cluster/service/task-definition ceremony that buys little for a single small container.
- AWS **Lambda** container images are billed under a genuinely perpetual free tier (1M requests +
  400k GB-s/month) and support digest-pinned deployment, but (a) they **require** the image to
  live in Amazon ECR, not GHCR — forcing a second registry and extra push/auth plumbing — and (b)
  running Flask on Lambda needs an adapter layer (e.g. AWS Lambda Web Adapter), which is an
  implementation detail purely to satisfy the hosting platform and would distract from the CI/CD
  narrative on stage.
- A plain, persistent EC2 Docker host is the option a DevOps-literate conference audience
  recognizes instantly ("GitHub Actions tells the box to run this exact image digest"), never
  sleeps or cold-starts (unlike Render's free tier or, to a lesser extent, scale-to-zero
  platforms), and keeps the registry decision (GHCR) unchanged.
- SSM Run Command instead of SSH removes an entire class of live-demo risk (no inbound port 22,
  no SSH key to leak or rotate, no "is the key in the right GitHub Secret" failure mode) and
  satisfies the constitution's least-privilege requirement (Principle II/FR-040) better than a
  static AWS access key pair would.

**Alternatives considered**:
- *Render (Starter, paid)* — simplest control-plane, deploy-by-digest and rollback are first-class
  Render features; rejected only because the user has an AWS account and asked for AWS Free Tier.
- *Google Cloud Run* — best-in-class native digest/revision rollback and traffic splitting;
  rejected for the same reason (user preference for AWS + existing account).
- *AWS Lightsail Containers* — managed and Render-like, but no perpetual free tier and its image
  distribution model (push via `lightsail push-container-image` into its own private registry, or
  reference a public image) is less standard than EC2 + Docker and less documented for
  digest-pinned promote/rollback.
- *EC2 with SSH deploy key* — simpler IAM setup than OIDC+SSM, but leaves a static credential in
  GitHub Secrets and an open inbound port; rejected on least-privilege/security grounds given the
  constitution explicitly calls this out.
- *Single EC2 instance hosting both environments as two containers behind a reverse proxy* —
  cheaper, but weakens the staging/production separation the brief calls a first-class concept
  (separate credentials, blast radius); rejected as false economy for ~$7–8/month of savings.

**Cost note**: `t3.micro` × 2 is AWS Free-Tier eligible (750 hrs/month combined limit) for the
first 12 months of an AWS account; if this account is past that window, actual cost is
≈$15/month combined (documented in README cost section) — still within "free or very low cost."

**Determinism mitigations**: instances are always-on (no cold start to manage live); SSM Run
Command has a bounded timeout with explicit success/failure status polled by the workflow (FR-039
health check follows regardless); Elastic IPs (or stable public DNS via Route 53/EC2 public DNS)
keep the staging/production URLs constant across redeploys so they can be bookmarked before the
talk.

---

## D2. Release automation: Conventional Commits → SemVer

**Decision**: **Release Please** (`googleapis/release-please-action`), configured with
`release-type: simple` (or `python`, evaluated at implementation time) and a manifest tracking the
single package version.

**Rationale**: Release Please's "Release PR" model is more demo-friendly than semantic-release's
immediate-on-merge model: the bot opens/updates a visible `chore(main): release 1.0.1` PR as
commits land, and the presenter merges that PR live as an explicit, visible, low-risk step — a
better teaching moment for "release is a deliberate action driven by Conventional Commits," and
more deterministic (nothing publishes until that merge happens, so there's no race with other
on-stage actions). It also needs no Node.js plugin ecosystem or `.npmrc`/publish credentials for a
Python project, keeping the pipeline's dependency surface smaller (Principle VII).

**Alternatives considered**:
- *semantic-release* — powerful and widely used, but immediate-publish-on-merge is a worse fit for
  a live demo (less visible/controllable moment) and its plugin config is heavier for a non-npm
  project.
- *Manual `bump2version`/hand-edited version* — rejected: violates FR-024 (no manual version
  editing) and Principle VI (traceability must be mechanical, not a human remembering to bump a
  file).

---

## D3. Container registry

**Decision**: GitHub Container Registry (GHCR), package visibility set to **public** after first
push.

**Rationale**: Free for public repositories, authenticates in-workflow with the ambient
`GITHUB_TOKEN` (no extra PAT/secret to manage), and a public package means the EC2 hosts need zero
registry credentials to pull — the smallest possible secret surface for D1's deploy step.

**Alternatives considered**: Docker Hub (extra account/secret, rate limits on anonymous pulls);
Amazon ECR (would remove the "zero registry credential on the box" property and require a second
registry login step; only clearly better if the platform *required* ECR, e.g. Lambda, which D1
rejected).

---

## D4. GitHub Actions supply-chain pinning

**Decision**: Every Action reference (including first-party `actions/*` and `docker/*`) is pinned
to a full commit SHA, with a trailing `# vX.Y.Z` comment for human readability; Dependabot is
configured for the `github-actions` ecosystem so SHA bumps still arrive as reviewable PRs.

**Rationale**: SHA pinning is the current baseline recommendation (GitHub's own hardening guidance
and OpenSSF Scorecard) against a tag being force-moved or a compromised action publishing a new
version under an existing tag; it is a concrete, visible artifact for the "supply-chain security"
part of the talk. Dependabot keeps the maintenance cost near zero.

**Alternatives considered**: Pin by major version tag only (`@v4`) — simpler to read, but
strictly weaker supply-chain guarantee; rejected since the SHA-pinning cost is fully absorbed by
Dependabot automation.

---

## D5. Vulnerability scanning policy (Trivy)

**Decision**: Trivy scans the built image before it is eligible for staging. The gate **fails**
the pipeline only on `CRITICAL` or `HIGH` severity findings **that have a known fix available**.
Findings with no fix available, or below HIGH, are reported (job summary + uploaded SARIF) but do
not block. A checked-in `.trivyignore` allows a reviewed, per-CVE exception, each line commented
with the reason and a re-review date; exceptions are added via normal PR review (not by the
change's own author unilaterally merging past the gate — the PR review requirement is the control).
The Trivy vulnerability DB used in CI is refreshed on a schedule the team controls (daily
`workflow_dispatch`/cron cache refresh job) rather than implicitly on every run, and the exact
image used for the live demo is scanned and frozen the day before the talk, not rebuilt on stage.

**Rationale**: Directly answers the brief's explicit worry ("a new CVE on the morning of the talk
must not make the pipeline flaky"): "no fix available" can never regress from green to red
overnight, because those findings never block in the first place; the only way a previously-green
image goes red is a *new fixable* HIGH/CRITICAL in a dependency that hasn't been rebuilt — which,
under Principle I (build once), doesn't happen to an already-promoted artifact, only to the *next*
build.

**Alternatives considered**: Block on any HIGH/CRITICAL regardless of fix availability — simpler
policy, but directly contradicts the brief's determinism requirement (an unfixable transitive CVE
could appear at any time and permanently block releases). Ignore Trivy results entirely — rejected,
defeats FR-032/FR-033 and Principle II's intent.

---

## D6. Local application stack

**Decision**: Python 3.13, Flask + Gunicorn (production WSGI server inside the container; Flask's
dev server for local `flask run` only), pytest + pytest-cov for tests/coverage, Ruff for lint
(and import sorting), Gitleaks for secret scanning (official `gitleaks-action`), Trivy
(`aquasecurity/trivy-action`) for image scanning.

**Rationale**: Matches the brief's proposed stack; Python 3.13 is stable and broadly supported by
this date; Gunicorn avoids running Flask's development server in the container (a real, if minor,
production/security smell worth avoiding even in a demo). Ruff replaces a
flake8+isort+black combo with one fast, single-dependency tool — fewer moving parts (Principle
VII) without losing lint/format coverage.

**Alternatives considered**: FastAPI — no concrete advantage for a two-endpoint status app;
Flask's simplicity and audience familiarity win. `unittest` instead of pytest — pytest's fixtures
and concise assertions are simply better ergonomics for a live-coded/live-explained test suite.

---

## D7. CPU architecture

**Decision**: Build and run `linux/amd64` only (matches default GitHub-hosted runners and
`t3.micro`).

**Rationale**: Avoids `buildx` cross-compilation/QEMU emulation, which is both slower (worse for a
live demo's time budget, FR-008) and one more thing that can behave unexpectedly on stage.

**Alternatives considered**: Multi-arch (`amd64`+`arm64`) to allow a cheaper Graviton
(`t4g.micro`) instance — real cost saving, but adds build complexity and a new failure surface for
a marginal saving; documented as a Possible Enhancement instead.

---

## D8. Secret-scanning execution mode: gitleaks CLI directly, not gitleaks-action

**Decision**: `pr-validation.yml`'s secret-scan job installs the open-source `gitleaks` CLI
directly (pinned version, checksum-verified download) and runs `gitleaks detect`, rather than
using the `gitleaks/gitleaks-action` wrapper originally planned.

**Rationale**: this repository is owned by the `eazysec` GitHub **organization** (confirmed via
the GitHub API), and `gitleaks/gitleaks-action`'s own documentation states a paid
`GITLEAKS_LICENSE` is required for organization-owned repositories (free only for personal-user
repos). That directly conflicts with this project's "free or very low cost" constraint (brief
§17) and would have made the PR pipeline fail for a reason invisible until someone actually ran
it against this specific repository. The underlying `gitleaks` binary itself is MIT-licensed
open source with no such restriction — running it directly sidesteps the wrapper's business
model entirely while producing identical detection behavior (same engine, same `.gitleaks.toml`).

**Alternatives considered**: Pay for a `GITLEAKS_LICENSE` — rejected, contradicts the free/low-cost
requirement for no real benefit (the wrapper mainly adds PR-comment automation, which
`GITHUB_TOKEN`-based required-status-check reporting already covers for this demo's purposes).
Use a different secret scanner (e.g. TruffleHog) — rejected, no reason to abandon Gitleaks itself,
which was explicitly proposed in the brief and works fine as a plain CLI invocation.

**How this was caught**: discovered during implementation validation, not left to be discovered
live at the conference — see the corresponding entry in
[Determinism & Risk Register](../../README.md#determinism--risk-register).
