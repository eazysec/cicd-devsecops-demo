# Branch Protection for `main` (manual, run once)

Requires repository admin access. This is what makes Scenario B (failing test) and Scenario C
(secret detected) in the Conference Runbook actually block a merge, instead of just failing a
check nobody is forced to look at.

Repo > Settings > Branches > Add branch protection rule (Settings > Rules > Rulesets works too;
a classic branch protection rule is described here for simplicity):

- **Branch name pattern**: `main`
- **Require a pull request before merging**: on
- **Require status checks to pass before merging**: on, with these required checks (exact names
  from `.github/workflows/pr-validation.yml`):
  - `Security Gate: Secret Scanning`
  - `Quality Gate: Lint`
  - `Quality & Security Gate: Tests, SAST, Dependency Scan`. It was previously named
    `Quality Gate: Unit Tests + Coverage`, before Bandit/pip-audit were added. GitHub matches
    required checks by exact name, so **a rule still using the old name no longer enforces the
    check**: edit it and use the new name.
- **Require branches to be up to date before merging**: on (avoids merging a PR whose checks ran
  against a stale base)
- **Do not allow bypassing the above settings**: on. This makes the mandatory gates apply to
  repository administrators too (constitution Principle II: the author of a change, admin
  included, cannot wave through their own failing secret scan).
- **Restrict who can push to matching branches**: on, nobody. All changes to `main` go through a
  reviewed PR (constitution Principle IV, trunk-based development).

No status check for `Classify change`: it is an implementation detail other jobs depend on
(`needs: classify`), not a required gate itself.
