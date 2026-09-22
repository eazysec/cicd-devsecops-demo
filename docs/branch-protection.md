# Branch Protection for `main` (manual — run once)

This agent has no GitHub admin API access and cannot configure this. **NOT VERIFIED** until you
complete it. This is what makes Scenario B (failing test) and Scenario C (secret detected) in the
Conference Runbook actually block a merge, instead of just failing a check that nobody is forced
to look at.

Repo → Settings → Branches → Add branch protection rule (or Settings → Rules → Rulesets, either
works — a classic branch protection rule is described here for simplicity):

- **Branch name pattern**: `main`
- **Require a pull request before merging**: on
- **Require status checks to pass before merging**: on, with these required checks (exact names
  from `.github/workflows/pr-validation.yml`):
  - `Security Gate: Secret Scanning`
  - `Quality Gate: Lint`
  - `Quality & Security Gate: Tests, SAST, Dependency Scan` (renamed from `Quality Gate: Unit
    Tests + Coverage` when Bandit/pip-audit were added — **if you already configured branch
    protection with the old name, you must edit the rule and swap it for this one, or the check
    stops being enforced entirely** since GitHub matches required checks by exact name)
- **Require branches to be up to date before merging**: on (avoids merging a PR whose checks ran
  against a stale base)
- **Do not allow bypassing the above settings**: on — this is the setting that makes the
  mandatory gates apply to repository administrators too, not just ordinary contributors
  (constitution Principle II: the author of a change — including an admin — cannot wave through
  their own failing secret scan).
- **Restrict who can push to matching branches**: on, nobody — all changes to `main` go through a
  reviewed PR (constitution Principle IV, trunk-based development).

No status check for `Classify change` — it is an implementation detail other jobs depend on
(`needs: classify`), not itself a required gate.

**Status: NOT VERIFIED** — requires GitHub repository admin access this agent does not have.
