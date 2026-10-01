# ADR 0009: Periodic image re-scan — active results, not another passive dashboard

**Status**: Accepted (2026-09-24)

## Context

[ADR 0004](./0004-build-once-promote.md) scans the built image exactly once, before it is ever
deployed, and [research.md D5](../../specs/001-cicd-devsecops-demo/research.md#d5-vulnerability-scanning-policy-trivy)
deliberately never re-checks it later — a CVE published after the build must never retroactively
fail an already-green pipeline. That leaves a real gap: nothing re-checks what is *actually
deployed* against newly-published CVEs for as long as it stays live. See
[research.md D12](../../specs/001-cicd-devsecops-demo/research.md#d12-periodic-re-scan-of-the-deployed-digest-with-an-active-not-passive-result).

## Decision

[`image-rescan.yml`](../../.github/workflows/image-rescan.yml): a weekly (+ on-demand) re-scan of
the currently-deployed digest for both `staging` and `production`. Full SARIF still goes to Code
Scanning, but a fixable HIGH/CRITICAL finding also opens/updates a GitHub Issue, closed
automatically once no longer reproduced.

## Rationale

- Reuses the exact decoupled-cadence pattern already defended for CodeQL
  ([ADR 0008](./0008-codeql-integration.md)) rather than inventing a new one: fast/blocking checks
  stay in the PR and build gates, slow/drift-driven checks run on their own schedule and never
  block anything.
- ADR 0008 itself already named an open risk: a decoupled scan that only feeds a dashboard nobody
  is forced to open is security theatre by this project's own definition
  (`docs/retex-webinar.md` §1.4/§1.5). Adding a third scan with the same passive result would
  repeat that mistake — and the stakes are higher here, since the finding concerns what is
  actually serving traffic right now, not a hypothetical exploit path in source code.
- An issue gives the finding an owner and a lifecycle (open → still-present comments → closed)
  instead of one more row in a tab.

## Rejected alternatives

- **Trigger on every push to `main`** — rejected: the goal is catching drift in an *external*
  vulnerability database against *unchanged* deployed code; a push only re-runs against code that
  just changed, which the build-time scan in `release.yml` already covers.
- **Fail the workflow instead of opening an issue** — rejected: a red run in the Actions list is
  indistinguishable from an infrastructure failure and has no persistent, triageable, closeable
  lifecycle the way a dedicated issue does.

## Consequences

- `resolve_deployment_digest.sh` (already used by `rollback.yml`) is reused as-is to find the
  digest to scan — no new lookup logic.
- On an environment with no deployment history yet, this job fails loudly rather than skipping
  silently, consistent with `rollback.sh`'s existing "fail clearly, never guess" behavior.
- **This does not retroactively fix ADR 0008's own open risk.** CodeQL still only uploads to Code
  Scanning; this ADR closes the loop for the *image* layer specifically, not the *source-code*
  layer. That gap stays explicitly open, not silently assumed solved by analogy.

## Addendum: `drift-check` job — declared vs. actually running

`resolve_deployment_digest.sh` (used by `rescan` above) only says what GitHub *believes* was
deployed successfully — it never confirms what is actually running on the instance. A manual,
out-of-band change to the container (bypassing `deploy.yml` entirely) would go completely
unnoticed by `rescan`, which would happily keep re-scanning the digest GitHub thinks is live.

Added a second job, `drift-check`, in the same workflow file rather than as extra steps in
`rescan`: same natural pipeline stage (periodic, post-deploy, against whatever's currently live —
D9's placement principle), but a genuinely different concern (declared vs. actual state, not
vulnerability content) with a genuinely different permission need (AWS/SSM access via OIDC). A
separate job keeps `rescan` free of any AWS credential at all, and each job's `permissions:`
stays scoped to only what it needs — the same per-job least-privilege discipline the README
documents as this project's contract for `GITHUB_TOKEN` scopes.

`scripts/read_deployed_digest.sh` (new) reads the running container's actual image reference via
SSM (`docker inspect app --format="{{.Config.Image}}"`) — read-only, never pulls or restarts
anything. `drift-check` compares this against `resolve_deployment_digest.sh`'s result and
opens/updates/closes a tracking issue on mismatch, same active-result discipline as `rescan`'s
CVE findings, same `security-rescan` label, distinct issue title so the two concerns never get
conflated in the tracker.

**Not verified end-to-end against real AWS/EC2** — no AWS credentials or Docker daemon available
in the sandbox this was built in. Shell syntax (`sh -n`) and the YAML are checked; the actual SSM
round-trip and the `docker inspect` format string are not empirically confirmed working yet. Test
this for real (`workflow_dispatch` on `image-rescan.yml`) before relying on it.
