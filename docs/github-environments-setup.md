# GitHub Environments Setup (manual, run once)

Requires repository admin access. See
[data-model.md#environment-config-not-data](../specs/001-cicd-devsecops-demo/data-model.md#environment-config-not-data).

## 1. Create the two environments

Repo > Settings > Environments > New environment, twice: `staging`, `production`.

## 2. Environment variables (not secrets: none of these are sensitive)

For each environment, Settings > Environments > `<env>` > Environment variables:

| Variable | staging | production |
|---|---|---|
| `AWS_ROLE_ARN` | ARN of `cicd-demo-github-oidc-staging` (`docs/aws-setup.md` §4) | ARN of `cicd-demo-github-oidc-production` |
| `AWS_REGION` | `eu-west-3` | `eu-west-3` |
| `EC2_INSTANCE_ID` | the staging instance id | the production instance id |
| `APP_URL` | `http://<staging-elastic-ip-or-dns>` | `http://<production-elastic-ip-or-dns>` |

No value is shared between environments: each role ARN and instance id is unique per
environment (constitution Principle II / FR-040, least privilege).

## 3. Production protection rule

`production` environment > Deployment protection rules > **Required reviewers** > add at least
one reviewer (yourself, or a co-presenter). This is what makes `deploy-production` in
`release.yml` pause for a manual approval: the promotion gate shown on stage (spec.md
Assumptions). Required reviewers on Environments are available on public repositories on the
free plan. If this repository is ever made private, check that your plan still includes them
(GitHub Free for private repos does not); see the
[Determinism & Risk Register](../README.md#determinism--risk-register) in the README.

Leave `staging` without a protection rule, so staging deploys proceed automatically and only
production needs an explicit "go" on stage.

## 4. Make the GHCR package public (after the first release)

The first successful `release.yml` run creates the GHCR package
`ghcr.io/eazysec/cicd-devsecops-demo` as **private** (GHCR has no create-as-public option). Go to
the package's GitHub page > Package settings > Change visibility > **Public**. This lets the EC2
hosts `docker pull` without any registry credential (ADR 0003).

## 5. Repository-level (not environment-level) permissions

Settings > Actions > General > Workflow permissions: **Read repository contents permission** (the
read-only `GITHUB_TOKEN` baseline). Every workflow in this repo declares the broader permissions
it needs (`contents: write`, `packages: write`, `id-token: write`, etc.) at the job level, so the
repository default stays at the minimum.
