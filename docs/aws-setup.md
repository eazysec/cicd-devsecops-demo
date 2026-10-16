# AWS Setup (manual, run once before the first deploy)

One-time AWS provisioning for this project, and the reference for what is actually deployed.
See [ADR 0001](./adr/0001-deployment-platform.md) for why this shape was chosen (EC2 + SSM,
OIDC, no SSH).

Region: `eu-west-3`. Account and instance IDs are replaced by `<ACCOUNT_ID>` and
`<STAGING_INSTANCE_ID>` / `<PRODUCTION_INSTANCE_ID>` placeholders. Never paste secrets (access
keys, tokens, passwords) in this file.

One instance and one IAM role per environment; never share an instance or role between
`staging` and `production`.

| Resource | Staging | Production |
|---|---|---|
| EC2 instance | `<STAGING_INSTANCE_ID>` | `<PRODUCTION_INSTANCE_ID>` |
| Instance role (both) | `cicd-demo-ec2-ssm-role` | `cicd-demo-ec2-ssm-role` |
| GitHub deploy role | `cicd-demo-github-oidc-staging` | `cicd-demo-github-oidc-production` |
| Deploy role permissions policy | `cicd-demo-ssm-deploy-staging` | `cicd-demo-ssm-deploy-production` |

## 1. Create the EC2 instance role

IAM role `cicd-demo-ec2-ssm-role`, attached to both instances as their instance profile. It lets
the SSM Agent register the instance (Amazon Linux 2023 ships with the SSM Agent pre-installed and
running).

**Trust policy:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**Permissions:** the AWS-managed policy `AmazonSSMManagedInstanceCore`
(`arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore`).

## 2. Launch the EC2 instances

For **each** environment:

1. Launch a `t3.micro` instance, Amazon Linux 2023 AMI (x86_64, matching the `linux/amd64` image
   built by CI, see research.md D7), in a VPC with outbound internet access (to reach GHCR and
   the SSM endpoints) and inbound **only** on port 80 from the internet. No port 22: SSM Run
   Command replaces SSH entirely.
2. Attach `cicd-demo-ec2-ssm-role` (step 1) as the instance profile.
3. User data (cloud-init), to install and start Docker:
   ```bash
   #!/bin/bash
   dnf install -y docker
   systemctl enable --now docker
   ```
4. Allocate and associate an Elastic IP (or otherwise give the instance a stable public DNS
   name) so `APP_URL` never changes across redeploys. Bookmark it before the talk.
5. Record the instance id (`i-...`): it becomes the `EC2_INSTANCE_ID` GitHub Environment
   variable (see `docs/github-environments-setup.md`).

## 3. Create the GitHub OIDC identity provider (once per account)

In IAM > Identity providers > Add provider:
- Provider type: OpenID Connect
- Provider URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`

Resulting ARN: `arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com`.

Skip this step if the account already has this provider from another project: it is
account-wide, not per-repository.

## 4. Create one GitHub deploy role per environment

Roles `cicd-demo-github-oidc-staging` and `cicd-demo-github-oidc-production`. Below,
`<ENVIRONMENT>` is `staging` or `production`, and `<INSTANCE_ID>` the matching instance.

**Trust policy**, restricted to this repository and this environment only (least privilege,
constitution Principle II / FR-040):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com" },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:eazysec/cicd-devsecops-demo:environment:<ENVIRONMENT>",
            "repo:eazysec@*/cicd-devsecops-demo@*:environment:<ENVIRONMENT>"
          ]
        }
      }
    }
  ]
}
```

**Gotcha:** GitHub's OIDC `sub` claim does not always use the plain
`repo:OWNER/REPO:environment:ENV` form. It can embed the organization's and repository's
immutable numeric IDs instead, as `repo:OWNER@OWNER_ID/REPO@REPO_ID:environment:ENV` (this keeps
the trust valid across an org/repo rename). A trust policy with only the plain-name pattern
rejects every attempt with `Not authorized to perform sts:AssumeRoleWithWebIdentity`. The
two-pattern `StringLike` list above accepts either form.

To see which form your account issues, run `deploy.yml` via `workflow_dispatch` with the `debug`
input set to `true`: a step prints the decoded token claims (`sub`, `aud`, etc.) before the AWS
auth step. It is off by default and only exists on the manual path, so if an automatic deploy
fails, re-run the same digest manually with `debug: true`.

**Permissions policy** (`cicd-demo-ssm-deploy-<ENVIRONMENT>`), scoped to that environment's
instance only:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["ssm:SendCommand"],
      "Resource": [
        "arn:aws:ec2:eu-west-3:<ACCOUNT_ID>:instance/<INSTANCE_ID>",
        "arn:aws:ssm:eu-west-3::document/AWS-RunShellScript"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["ssm:GetCommandInvocation"],
      "Resource": "*"
    }
  ]
}
```

`ssm:GetCommandInvocation` does not support resource-level restriction, so `"*"` is required:
an accepted, read-only exception to strict least privilege.

Record each role's ARN: it becomes the `AWS_ROLE_ARN` GitHub Environment variable.

## 5. Verify

```bash
aws ssm send-command --instance-ids <EC2_INSTANCE_ID> \
  --document-name AWS-RunShellScript \
  --parameters '{"commands":["docker --version"]}' \
  --region eu-west-3
```

It should succeed and, via `aws ssm get-command-invocation`, show a Docker version in its output.
