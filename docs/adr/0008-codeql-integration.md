# ADR 0008: CodeQL integration — decoupled cadence, not a PR gate

**Status**: Accepted (2026-09-23)

## Context

[ADR 0007](./0007-sast-sca-tool-selection.md) picked Bandit for SAST inside the PR gate. Bandit is
pattern-based: fast, but shallow — it cannot trace how a value flows from an untrusted input to a
dangerous sink across function boundaries. CodeQL does that (dataflow/taint-tracking analysis), at
the cost of being slower and heavier. The question was not "Bandit or CodeQL" but whether — and
how — to run both without forcing a merge-blocking gate to pay CodeQL's cost.
See [research.md D11](../../specs/001-cicd-devsecops-demo/research.md#d11-adding-codeql-decoupling-scan-cadence-from-analysis-rigor).

## Decision

Add [`.github/workflows/codeql.yml`](../../.github/workflows/codeql.yml) as a separate workflow,
triggered on `push` to `main`, a weekly `schedule`, and manual `workflow_dispatch` — never on
`pull_request`. Findings upload to GitHub Code Scanning, the same sink Trivy's SARIF report
already uses. Informational only: nothing in this workflow can block a merge.

## Rationale

- A PR gate should stay fast enough to be respected, not silently tolerated or disabled — Bandit
  fits that budget, CodeQL does not.
- Splitting "blocks every change, fast" from "as thorough as possible, deferred" lets each tool be
  good at the property it's actually suited for, instead of compromising one tool on both axes.
- Reusing Code Scanning as the sink (rather than building a second bespoke report path) keeps one
  consumer for multiple SARIF-native tools — the same reasoning that made Trivy's Code Scanning
  upload cheap in the first place.

## Rejected alternatives

- **CodeQL inside `pr-validation.yml`, alongside Bandit** — rejected: adds real minutes to every
  PR's required checks, on a two-endpoint codebase where CodeQL's marginal detection value over
  Bandit is close to zero. Paying that cost on every PR isn't justified by what it would actually
  catch here.
- **Not adding CodeQL** — considered, but the decoupled-cadence pattern (fast blocking gate +
  slower deferred deep scan) is itself a transferable architecture lesson worth demonstrating,
  independent of how much this specific small app benefits from CodeQL's extra depth.

## Consequences

- A second SAST tool exists, deliberately overlapping Bandit's ground on Python source — justified
  the same way pip-audit/Trivy overlap is justified in ADR 0007: different analysis technique,
  different blind spots, not redundant.
- **This decoupling reintroduces the same blind spot documented in ADR 0006/`docs/retex-webinar.md`
  §1.4** — a tool that runs without blocking anyone and reports into a tab nobody is required to
  open is security theatre by this project's own definition, unless someone actually reads Code
  Scanning between scheduled runs. This is not resolved by this ADR; it is named as an open risk
  in [`docs/retex-webinar.md` §1.5](../retex-webinar.md#15-découpler-cadence-de-scan-et-rigueur-danalyse--bonne-architecture-nouveau-risque-de-théâtre).
