#!/usr/bin/env sh
# Read the full image reference (ghcr.io/...@sha256:...) of the container ACTUALLY running on an
# environment's EC2 instance right now, via SSM — independent of what the GitHub Deployments API
# believes was deployed. Read-only: never pulls, never restarts anything.
#
# Contract: specs/001-cicd-devsecops-demo/contracts/deploy-script.md#scriptsread_deployed_digestsh-environment
#
# Usage: read_deployed_digest.sh <environment>
#   environment   staging | production
#
# Required environment variables: AWS_REGION, EC2_INSTANCE_ID.
#
# Used by image-rescan.yml's drift-check job to compare this against the digest recorded in the
# GitHub Deployments API (scripts/resolve_deployment_digest.sh) — a mismatch means the instance
# was changed outside deploy.yml, or a deployment record doesn't reflect reality.
set -eu

SSM_TIMEOUT_SECONDS="${DEPLOY_SSM_TIMEOUT_SECONDS:-60}"
SSM_POLL_INTERVAL="${DEPLOY_SSM_POLL_INTERVAL:-5}"

environment="${1:?usage: read_deployed_digest.sh <environment>}"

: "${AWS_REGION:?AWS_REGION must be set}"
: "${EC2_INSTANCE_ID:?EC2_INSTANCE_ID must be set}"

case "$environment" in
    staging | production) : ;;
    *)
        echo "read_deployed_digest: FAIL - environment must be 'staging' or 'production', got '$environment'" >&2
        exit 1
        ;;
esac

echo "read_deployed_digest: sending SSM command to $EC2_INSTANCE_ID to inspect the running container (environment=$environment)" >&2

# .Config.Image is exactly the reference deploy.sh passed to `docker run` (the full
# ghcr.io/...@sha256:... string) — more direct and unambiguous than fishing through the image's
# RepoDigests, which is a property of the image, not the container, and can list more than one
# entry.
remote_script='docker inspect app --format="{{.Config.Image}}"'

command_id="$(aws ssm send-command \
    --instance-ids "$EC2_INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "{\"commands\":[$(printf '%s' "$remote_script" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')]}" \
    --region "$AWS_REGION" \
    --query "Command.CommandId" \
    --output text)"

echo "read_deployed_digest: SSM command $command_id sent, polling for completion (timeout ${SSM_TIMEOUT_SECONDS}s)" >&2

elapsed=0
status="Pending"
while [ "$elapsed" -lt "$SSM_TIMEOUT_SECONDS" ]; do
    status="$(aws ssm get-command-invocation \
        --command-id "$command_id" \
        --instance-id "$EC2_INSTANCE_ID" \
        --region "$AWS_REGION" \
        --query "Status" \
        --output text 2>/dev/null || echo "Pending")"

    case "$status" in
        Success) break ;;
        Failed | Cancelled | TimedOut)
            echo "read_deployed_digest: FAIL - SSM command ended with status '$status'" >&2
            aws ssm get-command-invocation --command-id "$command_id" --instance-id "$EC2_INSTANCE_ID" \
                --region "$AWS_REGION" --query "StandardErrorContent" --output text >&2 || true
            exit 1
            ;;
    esac

    sleep "$SSM_POLL_INTERVAL"
    elapsed=$((elapsed + SSM_POLL_INTERVAL))
done

if [ "$status" != "Success" ]; then
    echo "read_deployed_digest: FAIL - SSM command did not reach a terminal state within ${SSM_TIMEOUT_SECONDS}s (last status: $status)" >&2
    exit 1
fi

output="$(aws ssm get-command-invocation \
    --command-id "$command_id" \
    --instance-id "$EC2_INSTANCE_ID" \
    --region "$AWS_REGION" \
    --query "StandardOutputContent" \
    --output text)"

image_ref="$(printf '%s' "$output" | tr -d '[:space:]')"

if [ -z "$image_ref" ]; then
    echo "read_deployed_digest: FAIL - empty output from SSM command (is a container named 'app' running?)" >&2
    exit 1
fi

printf '%s\n' "$image_ref"
