# ADR 0002: Release automation — Release Please over semantic-release

**Status**: Accepted (2026-09-22)

## Context

The brief asked for SemVer + Conventional Commits + release automation, and named
semantic-release and Release Please as candidates. See
[research.md D2](../../specs/001-cicd-devsecops-demo/research.md#d2-release-automation-conventional-commits--semver).

## Decision

Use **Release Please** (`googleapis/release-please-action`), `release-type: simple`, tracked via
`release-please-config.json` / `.release-please-manifest.json` at the repo root.

## Rationale

- Its "Release PR" model gives the conference presenter a visible, deliberate, mergeable moment
  (`chore(main): release 1.0.1`) instead of an invisible release firing the instant a commit
  lands — a better teaching moment and more controllable live.
- No Node.js plugin ecosystem or publish credentials needed for a Python project.
- A `docs:`-only or `chore:`-only commit never triggers a version bump, which is what makes
  Scenario D (spec.md US2) naturally never reach the build step in `release.yml` — no extra
  gating logic required there.

## Consequences

- The version live on stage lags one extra merge (the Release PR) behind the fix/feature PR —
  this is a deliberate, visible two-step release, not a limitation to work around.
- `release-please-config.json`/`.release-please-manifest.json` must stay in sync with the actual
  released version; Release Please itself keeps the manifest updated automatically.
