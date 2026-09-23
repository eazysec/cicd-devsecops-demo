# Security Policy

This is a conference demo, not a production system handling real user data — but its whole
point is to demonstrate real DevSecOps practice, so this policy is written as if it mattered,
because the practices it describes are meant to be copied into projects where it does.

## Secret handling

- No credential of any kind is ever committed to this repository. All deployment credentials are
  short-lived, obtained via GitHub OIDC → AWS IAM role assumption (see
  [ADR 0001](docs/adr/0001-deployment-platform.md)) — there is no long-lived AWS access key
  anywhere in this project, in GitHub Secrets or otherwise.
- Every push and every Pull Request is scanned by [Gitleaks](https://github.com/gitleaks/gitleaks)
  (`.gitleaks.toml`), and this check is mandatory: it cannot be skipped by policy for any change
  type (constitution Principle II), and — once `docs/branch-protection.md` is applied — it is a
  required, non-bypassable status check on `main`, including for repository administrators.

### Fake-secret demo

The Conference Runbook's Scenario C deliberately commits a **fabricated, non-functional,
never-used** secret pattern — generated fresh each time by `scripts/generate-demo-secret.sh` — to
a disposable demo branch, solely to show the pipeline blocking a merge. This repository never
contains a real credential in any commit, branch, or its history. If you fork or replay this
demo, do the same — never substitute a real key "just to test it more realistically," and never
hardcode the generated value into a tracked file (see the second gotcha below for why).

**Two gotchas worth knowing**, both found while building this demo:

1. Gitleaks' default ruleset silently *allowlists* obviously-placeholder values (anything
   containing `EXAMPLE`/`TEST`, or low-entropy repeated patterns like `FAKEFAKEFAKE...`)
   precisely because those appear constantly in documentation and would otherwise spam every
   scan of every repo that quotes AWS's own docs. A fake secret used for this demo must
   therefore be random-looking enough to have realistic entropy — fake in the sense of "never a
   real credential," not in the sense of "obviously a placeholder string."
2. A value random-looking enough to satisfy gotcha #1 is, by construction, also real-looking
   enough to trip **GitHub's own push-protection secret scanning** — which blocked this
   repository's very first push when an earlier draft hardcoded such a value directly into
   `quickstart.md`. The fix in both cases is the same: never store the value at rest in a
   tracked file; generate it on demand (`scripts/generate-demo-secret.sh`) and only ever let it
   exist in the throwaway demo branch used to trigger the scenario. This is, incidentally, a
   nice extra teaching moment: GitHub's push protection is a first line of defense *before* code
   ever reaches a repository, and this project's own Gitleaks gate is the portable second line
   that still catches it even on a host without push protection.

### If a real secret is ever committed (here or in any project)

1. **Treat it as compromised immediately**, even if you believe it was never actually used or was
   caught within seconds. Assume it was seen by anyone with read access to the repository (and,
   for a public repo, potentially by automated scrapers) the moment it was pushed.
2. **Rotate/revoke it at the source** (the cloud provider, API vendor, etc.) — this is the actual
   fix. Removing the commit from Git does not un-expose a credential that has already been
   pushed.
3. **Assess Git history exposure**: if the secret was pushed (even briefly) to a shared branch or
   a public repository, assume every clone/fork/CI cache may already have it. History rewriting
   (`git filter-repo`, BFG) only helps future clones and is warranted mainly to stop the bleeding
   going forward and to keep the visible history clean — it is not, by itself, a remediation for
   the exposure that already happened.
4. **Add a reviewed Gitleaks allowlist entry only if the finding was a genuine false positive**
   (see `.gitleaks.toml`'s header comment for the review rule) — never as a way to "make the red
   check go away" for a real finding.

## Vulnerability scanning policy (container images)

Every image built by `release.yml` is scanned with [Trivy](https://github.com/aquasecurity/trivy)
before it is eligible for staging/production. The gate blocks promotion only on `HIGH` or
`CRITICAL` severity findings that have a **known fix available** (`--ignore-unfixed`). See
[research.md D5](specs/001-cicd-devsecops-demo/research.md#d5-vulnerability-scanning-policy-trivy)
for the full rationale — in short: an unfixable finding can appear at any time and must never be
able to turn a previously-green pipeline red overnight, which would make the pipeline flaky and
untrustworthy rather than safer.

Reviewed exceptions to a *fixable* HIGH/CRITICAL finding (e.g. the fix isn't yet compatible with
the base image) go in `.trivyignore`, one CVE per line, each with a reviewer, a reason, and a
re-review date — added via normal PR review, never by the introducing change's own author acting
alone (the same non-bypass principle as secret scanning).

The full-severity SARIF report (everything, not just what blocks) is uploaded to **GitHub Code
Scanning** (Security tab), not just kept as a build artifact — a scanner whose output only exists
in a zip nobody opens unless something already failed elsewhere is its own kind of security
theatre (see `docs/retex-webinar.md`). Free for this repository (public); a private repo would
need the paid GitHub Code Security add-on for this same feature — see [GitHub's Advanced Security
billing docs](https://docs.github.com/en/billing/concepts/product-billing/github-advanced-security).

## Static analysis and dependency scanning policy (SAST/SCA)

Every push/PR touching application code runs [Bandit](https://bandit.readthedocs.io/) (SAST) and
[pip-audit](https://github.com/pypa/pip-audit) (dependency vulnerability scanning) alongside the
test suite — conditional gates, same as the tests, skipped with a stated reason for a
documentation-only change (see [ADR 0006](docs/adr/0006-security-tool-placement.md)). Both
currently block on any finding (no severity threshold, unlike Trivy) — the codebase is small
enough that this hasn't yet needed the same nuanced policy Trivy has; revisit if that stops being
true.

`pip-audit` audits the project path (`pip-audit .`), which resolves only the declared **runtime**
dependencies (`pyproject.toml`'s `[project.dependencies]`) — not the `[dev]` extra. A known
vulnerability in a dev-only tool (e.g. pytest itself) that never ships in the deployed container
therefore cannot block this gate; only what actually runs in production is in scope. See
[research.md D10](specs/001-cicd-devsecops-demo/research.md#d10-sastsca-tool-selection-bandit--pip-audit)
for why Bandit/pip-audit were chosen over Safety/Snyk, and why pip-audit and Trivy are both kept
despite auditing overlapping ground — they have different, complementary blind spots.

[CodeQL](.github/workflows/codeql.yml) runs a second, deliberately decoupled SAST pass: on push to
`main` and on a weekly schedule, never on a PR. Bandit is pattern-based and fast (seconds), so it
stays in the PR gate for immediate feedback; CodeQL does dataflow/taint-tracking analysis, which
is slower and not something a developer should wait on mid-review. It is informational, uploaded
to GitHub Code Scanning alongside Trivy's SARIF report, and never blocks a merge — see
[docs/retex-webinar.md §1.5](docs/retex-webinar.md) for why decoupling scan cadence from analysis
rigor is a deliberate architectural choice, and the security-theatre risk it introduces if nobody
actually reviews the results between scheduled runs.

## Dynamic analysis (DAST) policy

[OWASP ZAP](https://www.zaproxy.org/) runs a baseline (passive) scan against the `staging`
environment after every successful deploy that passes its health check and smoke test —
`environment: staging` only, never against `production` directly. Deliberately **informational**,
not a blocking gate: results land in a build artifact (`zap-baseline-report`) and a concise
summary in the run's Job Summary, not an auto-failed job. See [research.md
D9](specs/001-cicd-devsecops-demo/research.md#d9-security-tool-placement-co-located-by-pipeline-stage-not-grouped-by-category)
for the reasoning — DAST findings tend to need more contextual human judgment than a
CVE-with-a-known-fix does, which is exactly the "limits of automation" this project tries to
demonstrate honestly rather than force into a binary pass/fail it doesn't fit well.

**Not yet uploaded to Code Scanning**, unlike Trivy: `zap-baseline.py` doesn't natively emit
SARIF, and the available workarounds (an unofficial third-party converter, or reconfiguring the
scan to use ZAP's own Automation Framework instead of the simple baseline action) were judged too
fragile to ship without being able to test them end-to-end first. Tracked in **Possible
Enhancements** below rather than attempted half-verified.

## Dependency policy

Dependabot (`.github/dependabot.yml`) watches Python (`pip`), `Docker`, and `github-actions`
ecosystems weekly and opens PRs, which go through the same PR Validation gates as any other
change. This is ordinary repository hygiene, not part of the live demo narrative.

## Supply-chain hardening

Every GitHub Action used in this repository — including first-party `actions/*` — is pinned to a
full commit SHA (not a mutable tag), so a compromised or force-moved tag cannot silently change
what runs in CI. See [research.md D4](specs/001-cicd-devsecops-demo/research.md#d4-github-actions-supply-chain-pinning).

Not implemented, and deliberately deferred — see **Possible Enhancements** in the README — because
they add real setup cost without a strong teaching payoff for a two-endpoint demo app: SBOM
generation, build provenance/artifact attestations, and container image signing (e.g. cosign).

## Reporting

This is a public demo repository with no production users; there is no formal disclosure program.
If you find something concerning, open a GitHub issue.
