<!--
Sync Impact Report
Version change: none → 1.0.0 (initial ratification)
Modified principles: n/a (initial version)
Added sections: Core Principles (I–VII), Technology & Scope Constraints, Delivery Workflow, Governance
Removed sections: none
Templates requiring updates:
  - .specify/templates/plan-template.md ⚠ pending (will be checked at /speckit-plan time)
  - .specify/templates/spec-template.md ⚠ pending (will be checked at /speckit-specify time)
  - .specify/templates/tasks-template.md ⚠ pending (will be checked at /speckit-tasks time)
Follow-up TODOs: none — all placeholders resolved from the project brief.
-->

# cicd-devsecops-demo Constitution

## Core Principles

### I. Build Once, Promote the Same Artifact (NON-NEGOTIABLE)
A release produces exactly one immutable container image, identified by its registry digest.
That same digest — never a rebuild, never a re-tag from source — is deployed to staging and,
after verification, promoted unchanged to production. Any pipeline design that rebuilds the
application between environments is a constitution violation, regardless of convenience.
Rationale: this is the single architectural property the whole demo exists to prove; diverging
from it invalidates the pedagogical point of the entire pipeline.

### II. Security Gates Are Mandatory and Cannot Be Bypassed by the Author
Secret scanning and other designated mandatory gates run on every push and every pull request
and MUST block merge/build/deploy on failure. No mechanism (commit message flag, label, skip
file) may let the author of a change disable a mandatory gate on their own commit. Execution of
*non-mandatory* steps may be skipped by explicit, auditable policy (see Principle III), but
security gates are never in that set. Rationale: a demo that shows a trivially bypassable
security gate teaches the wrong lesson to an audience of engineers.

### III. Policy-Based Dynamic Execution, Not "Disable Checks"
The pipeline classifies every change and executes only the relevant steps, expressed as policy
("this change touches application code, therefore run tests") rather than as an escape hatch
("skip tests"). Every skip MUST be visible in the pipeline output with a stated reason. Docs-only
changes skip build/test/deploy steps; application changes run the full gate set. Rationale:
mirrors real-world CI cost/speed practice without teaching the audience that gates are optional.

### IV. Trunk-Based Development with Short-Lived Branches
`main` is always releasable. Work happens on short-lived branches merged via Pull Request after
required checks pass. No long-lived integration branches, no GitFlow `develop`/`release` branches.
Rationale: the simplest model that still demonstrates PR gating, and the current industry default;
GitFlow's extra ceremony would only obscure the CI/CD concepts being taught.

### V. Deterministic, Reproducible Demo Execution
Every mutable external dependency the live demo touches (Docker base images, GitHub Actions,
Python packages, vulnerability data) MUST be pinned or otherwise made to fail safe, and every
step used on stage MUST have a documented local fallback that does not depend on GitHub,
the registry, or the deployment platform being reachable. A new CVE, a sleeping free-tier
service, or a network hiccup on the day of the talk MUST NOT be able to derail the narrative.
Rationale: this repository's primary deliverable is a live conference demo, not a long-running
production system; reliability on stage outranks completeness.

### VI. Traceable Versioning
Every deployed artifact is traceable back to the commit that produced it through a consistent
chain: Commit → Conventional Commit type → SemVer bump → Git tag/GitHub Release → Docker image
tag/digest → environment. Version bumps follow SemVer strictly from Conventional Commit types
(fix→PATCH, feat→MINOR, breaking→MAJOR); no manual/ad-hoc version edits. Rationale: the audience
must be able to see, at any point, exactly which commit is running in which environment.

### VII. Minimum Viable Sophistication
No tool, workflow, or abstraction is added unless it answers a specific pedagogical or technical
requirement from this project's brief. Kubernetes, Helm, Argo CD, Terraform, service meshes, and
similar are out of scope unless a stated requirement cannot be met without them. When two
approaches are both legitimate, the simpler one that still teaches the concept correctly wins.
Rationale: tool sprawl dilutes the teaching point and increases the number of things that can
fail live.

## Technology & Scope Constraints

- Application: Python (Flask, chosen for minimal ceremony on stage) exposing `GET /` (human-
  readable status page) and `GET /health` (machine-readable JSON), honoring `PORT`.
- Quality stack: pytest, pytest-cov, Ruff — fast enough to run synchronously in a live demo.
- Secret scanning: Gitleaks, run on every push/PR; demo scenarios use only fabricated secrets,
  never real credentials.
- Container registry: GHCR (GitHub Container Registry) unless the planning phase documents a
  concrete reason to deviate.
- Deployment target: evaluated during planning against build-once/promote, immutable-digest
  deploys, staging/production separation, and rollback-to-known-artifact; the chosen platform
  and any rejected alternative must be recorded as an ADR.
- Environments: at minimum `staging` and `production`, modeled as GitHub Environments with
  their own secrets/variables/protection rules, least-privilege `GITHUB_TOKEN` permissions per
  workflow/job.
- Vulnerability scanning: Trivy, with an explicit, documented severity policy and exception
  process so that an unpatched CVE appearing on the morning of the talk cannot silently break
  the pipeline.

## Delivery Workflow

- GitHub-native events drive the pipeline: push to a working branch (fast feedback), pull
  request into `main` (quality + security gates), push/merge to `main` (release chain),
  `workflow_dispatch` (controlled/manual operations, demo convenience).
- Workflow logic that needs to be unit-tested or run identically on a laptop lives in
  `scripts/`, not inline in YAML; workflows orchestrate, scripts implement.
- Duplication between workflows is resolved via reusable workflows/composite actions where it
  measurably reduces maintenance burden, not preemptively.
- A local, GitHub-independent path (`scripts/demo-local.sh` and friends) must be able to
  demonstrate: lint → tests → secret scan → Docker build → (Trivy if available) → run →
  health check → smoke test, as the conference's Plan B.

## Governance

This constitution supersedes ad-hoc practice for this repository. Amendments are made via the
`/speckit-constitution` workflow, require a stated rationale, and bump the version per semantic
versioning (MAJOR: incompatible principle removal/redefinition; MINOR: new principle or materially
expanded guidance; PATCH: clarification/wording). Any plan, spec, or task list produced by Spec
Kit commands must be checked against these principles before implementation proceeds; unresolved
conflicts are documented and justified in the relevant plan's Complexity Tracking section rather
than silently overridden. Day-to-day development guidance beyond this constitution lives in
`README.md`.

**Version**: 1.0.0 | **Ratified**: 2026-09-22 | **Last Amended**: 2026-09-22
