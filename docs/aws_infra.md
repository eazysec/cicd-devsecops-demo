# AWS infrastructure

Configurations performed on the AWS side, versioned here for traceability.

> Never paste secrets (access keys, tokens, passwords) in this file.
> Account and instance IDs are replaced by `<ACCOUNT_ID>`, `<STAGING_INSTANCE_ID>` and
> `<PRODUCTION_INSTANCE_ID>` placeholders.

## IAM identity provider `token.actions.githubusercontent.com`

- Provider type: OpenID Connect
- Audience: `sts.amazonaws.com`
- ARN: `arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com`

## IAM role `cicd-demo-github-oidc-staging`

### Trust relationships

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": [
                        "repo:eazysec/cicd-devsecops-demo:environment:staging",
                        "repo:eazysec@*/cicd-devsecops-demo@*:environment:staging"
                    ]
                }
            }
        }
    ]
}
```

### Permissions policy `cicd-demo-ssm-deploy-staging`

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ssm:SendCommand"
            ],
            "Resource": [
                "arn:aws:ec2:eu-west-3:<ACCOUNT_ID>:instance/<STAGING_INSTANCE_ID>",
                "arn:aws:ssm:eu-west-3::document/AWS-RunShellScript"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetCommandInvocation"
            ],
            "Resource": "*"
        }
    ]
}
```

## IAM role `cicd-demo-github-oidc-production`

### Trust relationships

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": [
                        "repo:eazysec/cicd-devsecops-demo:environment:production",
                        "repo:eazysec@*/cicd-devsecops-demo@*:environment:production"
                    ]
                }
            }
        }
    ]
}
```

### Permissions policy `cicd-demo-ssm-deploy-production`

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ssm:SendCommand"
            ],
            "Resource": [
                "arn:aws:ec2:eu-west-3:<ACCOUNT_ID>:instance/<PRODUCTION_INSTANCE_ID>",
                "arn:aws:ssm:eu-west-3::document/AWS-RunShellScript"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetCommandInvocation"
            ],
            "Resource": "*"
        }
    ]
}
```

## IAM role `cicd-demo-ec2-ssm-role`

### Trust relationships

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
```

### Permissions policies

- `AmazonSSMManagedInstanceCore` (AWS managed: `arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore`)

## EC2 instances (staging and production)

### User data (cloud-init)

```bash
#!/bin/bash
dnf install -y docker
systemctl enable --now docker
```
