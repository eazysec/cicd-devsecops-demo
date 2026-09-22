# GitHub Environments Setup (manual — run once)

This agent has no GitHub admin API access for this repository and cannot run these steps for
you. **NOT VERIFIED** until you complete them. See
[data-model.md#environment-config-not-data](../specs/001-cicd-devsecops-demo/data-model.md#environment-config-not-data).

## 1. Create the two environments

Repo → Settings → Environments → New environment, twice: `staging`, `production`.

## 2. Environment variables (not secrets — none of these are sensitive)

For each environment, Settings → Environments → `<env>` → Environment variables:

| Variable | staging | production |
|---|---|---|
| `AWS_ROLE_ARN` | the staging role ARN from `docs/aws-setup.md` §3 | the production role ARN |
| `AWS_REGION` | your chosen region, e.g. `eu-west-3` | same |
| `EC2_INSTANCE_ID` | the staging instance id | the production instance id |
| `APP_URL` | `http://<staging-elastic-ip-or-dns>` | `http://<production-elastic-ip-or-dns>` |

No secret is duplicated between environments with the same value — each role ARN and instance id
is unique per environment by construction (constitution Principle II / FR-040 least privilege).

## 3. Production protection rule

`production` environment → Deployment protection rules → **Required reviewers** → add at least
one reviewer (yourself, or a co-presenter). This is what makes `deploy-production` in
`release.yml` pause for a manual approval click — the intended promotion-gate teaching moment
(spec.md Assumptions). Required reviewers on Environments are available on public repositories on
the free plan; if this repository is ever made private, re-verify this feature is still available
on your plan (GitHub Free for private repos does not include required reviewers) — see
[Determinism & Risk Register](../README.md#determinism--risk-register) in the README.

Optionally leave `staging` with no protection rule, so staging deploys proceed automatically —
only production should feel like a deliberate "go" moment on stage.

## 4. Make the GHCR package public (after the first release)

The first successful `release.yml` run creates the GHCR package
`ghcr.io/eazysec/cicd-devsecops-demo` as **private** by default (GHCR always does this — there is
no create-as-public option). Go to the package's GitHub page → Package settings → Change
visibility → **Public**. This is required for the EC2 hosts to `docker pull` without any
registry credential (ADR 0003).

## 5. Repository-level (not environment-level) permissions

Settings → Actions → General → Workflow permissions: **Read repository contents permission**
(the default `GITHUB_TOKEN` read-only baseline) — every workflow in this repo explicitly declares
the broader permissions (`contents: write`, `packages: write`, `id-token: write`, etc.) it needs
at the job level, so the repository default should stay at the minimum.

**Status: NOT VERIFIED** — requires GitHub repository admin access this agent does not have.
