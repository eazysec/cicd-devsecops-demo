# AWS Setup (manual — run once, before the first real deploy)

This agent has no AWS credentials and cannot run these steps for you. Everything below is
**NOT VERIFIED** until you run it. See [ADR 0001](./adr/0001-deployment-platform.md) for why
this shape was chosen (EC2 + SSM, OIDC, no SSH).

Repeat the EC2 + IAM role steps once for `staging` and once for `production` (two instances, two
roles) — never share an instance or role between environments.

## 1. Launch the EC2 instances

For **each** environment:

1. Launch a `t3.micro` instance, Amazon Linux 2023 AMI (x86_64 — matches the `linux/amd64` image
   built by CI, see research.md D7), in a VPC with outbound internet access (to reach GHCR and
   the SSM endpoints) and inbound **only** on port 80 from the internet (no port 22 — SSM Run
   Command replaces SSH entirely).
2. Attach an **instance profile** with the AWS-managed policy `AmazonSSMManagedInstanceCore` (lets
   SSM Agent register the instance; Amazon Linux 2023 ships with SSM Agent pre-installed and
   running).
3. In the instance's user-data, install and start Docker:
   ```bash
   #!/bin/bash
   dnf install -y docker
   systemctl enable --now docker
   ```
4. Allocate and associate an Elastic IP (or otherwise ensure the instance has a stable public
   DNS name) so `APP_URL` never changes across redeploys — bookmark this before the talk.
5. Record the instance id (`i-...`) — this becomes the `EC2_INSTANCE_ID` GitHub Environment
   variable (see `docs/github-environments-setup.md`).

## 2. Create the GitHub OIDC identity provider (once, not per-environment)

In IAM → Identity providers → Add provider:
- Provider type: OpenID Connect
- Provider URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`

(Skip this step if the AWS account already has this provider from another project — it is
account-wide, not per-repository.)

## 3. Create one IAM role per environment

For **each** environment, create an IAM role with:

**Trust policy** (restrict to this repository and this environment specifically — least
privilege, per constitution Principle II/FR-040):

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

**Gotcha, found the hard way**: GitHub's OIDC `sub` claim does not always use the plain
`repo:OWNER/REPO:environment:ENV` form. It can instead embed the organization's and
repository's immutable numeric IDs as `repo:OWNER@OWNER_ID/REPO@REPO_ID:environment:ENV` (this
keeps the trust relationship valid across an org/repo rename). A trust policy written with only
the plain-name pattern silently rejects every assume-role attempt with `Not authorized to
perform sts:AssumeRoleWithWebIdentity` — decode the actual token to see which form your account
is issuing (add a temporary debug step to the workflow: `curl -sS -H "Authorization: bearer
$ACTIONS_ID_TOKEN_REQUEST_TOKEN" "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=sts.amazonaws.com" |
jq -r '.value' | cut -d. -f2 | base64 -d | jq .`) rather than guessing. The two-pattern
`StringLike` list above accepts either form, so it keeps working regardless of which one GitHub
issues for your account.

**Permissions policy** (scoped to this environment's instance only):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["ssm:SendCommand"],
      "Resource": [
        "arn:aws:ec2:<REGION>:<ACCOUNT_ID>:instance/<THIS_ENVIRONMENT_INSTANCE_ID>",
        "arn:aws:ssm:<REGION>::document/AWS-RunShellScript"
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

(`ssm:GetCommandInvocation` does not support resource-level restriction to a specific command —
this is an accepted, minor, read-only exception to strict least privilege, documented here rather
than silently widened elsewhere.)

Record the role's ARN — this becomes the `AWS_ROLE_ARN` GitHub Environment variable.

## 4. Verify

```bash
aws ssm send-command --instance-ids <EC2_INSTANCE_ID> \
  --document-name AWS-RunShellScript \
  --parameters '{"commands":["docker --version"]}' \
  --region <REGION>
```
should succeed and, via `aws ssm get-command-invocation`, show a Docker version in its output.

**Status: NOT VERIFIED** — requires an AWS account with billing/permissions this agent does not
have. Run the steps above and re-run `scripts/deploy.sh` against a test digest to confirm.
