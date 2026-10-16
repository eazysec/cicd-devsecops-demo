# ADR 0001: Deployment platform, AWS EC2 + SSM Run Command

**Status**: Accepted (2026-09-22)

## Context

The initial requirements proposed Render for staging/production. During planning, the choice
moved to AWS Free Tier instead, since an AWS account was already available. See
[research.md D1](../../specs/001-cicd-devsecops-demo/research.md#d1-deployment-platform-staging--production)
for the full comparison.

## Decision

Two persistent `t3.micro` EC2 instances (staging, production), Docker Engine, deployed to via
AWS Systems Manager Run Command. GitHub Actions authenticates via OIDC to a per-environment IAM
role scoped to `ssm:SendCommand`/`ssm:GetCommandInvocation` against that environment's instance
only. No SSH, no long-lived AWS credentials in GitHub Secrets.

## Rejected alternatives

| Option | Rejected because |
|---|---|
| Render (Starter or free) | User has an AWS account and asked for AWS Free Tier |
| Google Cloud Run | Same, AWS preference overrides its superior native rollback ergonomics |
| AWS App Runner | Stops accepting new customers 2026-04-30, not viable for a new project |
| AWS Fargate | No free tier at all; ECS ceremony buys little for one small container |
| AWS Lambda (container image) | Requires ECR (not GHCR) and a Flask-on-Lambda adapter layer purely to satisfy the platform |
| EC2 + SSH deploy key | Works, but leaves a static credential in GitHub Secrets and an open inbound port, SSM avoids both |
| Single EC2 host for both environments | Cheaper, but weakens the staging/production blast-radius separation the requirements treat as a first-class concept |

## Consequences

- Setup requires manual, one-time AWS provisioning (`docs/aws-setup.md`).
- Always-on instances avoid the "sleeping free tier" determinism risk called out in the requirements,
  at a cost of ≈$15/month combined once any free-tier window expires.
- Rollback and promotion share one mechanism (`docker run` by digest via SSM), see
  [ADR 0005](./0005-rollback-strategy.md).
