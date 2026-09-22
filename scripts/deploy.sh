#!/usr/bin/env sh
# Promote an immutable image digest to one environment. No build, no push, no mutation of any
# environment other than the one named — this is the ONE place that "docker run"s the app.
#
# Contract: specs/001-cicd-devsecops-demo/contracts/deploy-script.md
#
# Usage: deploy.sh <environment> <digest>
#   environment   staging | production
#   digest        full sha256:... digest (never a mutable tag)
#
# Required environment variables (from the calling GitHub Environment):
#   AWS_REGION, EC2_INSTANCE_ID, APP_URL, GHCR_IMAGE (e.g. ghcr.io/eazysec/cicd-devsecops-demo)
set -eu

SSM_TIMEOUT_SECONDS="${DEPLOY_SSM_TIMEOUT_SECONDS:-120}"
SSM_POLL_INTERVAL="${DEPLOY_SSM_POLL_INTERVAL:-5}"

environment="${1:?usage: deploy.sh <environment> <digest>}"
digest="${2:?usage: deploy.sh <environment> <digest>}"

: "${AWS_REGION:?AWS_REGION must be set}"
: "${EC2_INSTANCE_ID:?EC2_INSTANCE_ID must be set}"
: "${APP_URL:?APP_URL must be set}"
: "${GHCR_IMAGE:?GHCR_IMAGE must be set}"

case "$environment" in
    staging | production) : ;;
    *)
        echo "deploy: FAIL - environment must be 'staging' or 'production', got '$environment'" >&2
        exit 1
        ;;
esac

image_ref="${GHCR_IMAGE}@${digest}"
script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

echo "deploy: sending SSM command to $EC2_INSTANCE_ID to run $image_ref (environment=$environment)"

remote_script=$(cat <<EOF
set -e
docker pull ${image_ref}
docker rm -f app 2>/dev/null || true
docker run -d --name app -p 80:8080 --restart unless-stopped \
  -e ENVIRONMENT=${environment} \
  -e ARTIFACT_DIGEST=${digest} \
  ${image_ref}
EOF
)

command_id="$(aws ssm send-command \
    --instance-ids "$EC2_INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "{\"commands\":[$(printf '%s' "$remote_script" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')]}" \
    --region "$AWS_REGION" \
    --query "Command.CommandId" \
    --output text)"

echo "deploy: SSM command $command_id sent, polling for completion (timeout ${SSM_TIMEOUT_SECONDS}s)"

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
            echo "deploy: FAIL - SSM command ended with status '$status'" >&2
            aws ssm get-command-invocation --command-id "$command_id" --instance-id "$EC2_INSTANCE_ID" \
                --region "$AWS_REGION" --query "StandardErrorContent" --output text >&2 || true
            exit 1
            ;;
    esac

    sleep "$SSM_POLL_INTERVAL"
    elapsed=$((elapsed + SSM_POLL_INTERVAL))
done

if [ "$status" != "Success" ]; then
    echo "deploy: FAIL - SSM command did not reach a terminal state within ${SSM_TIMEOUT_SECONDS}s (last status: $status)" >&2
    exit 1
fi

echo "deploy: SSM command succeeded; verifying externally via health check"
"$script_dir/healthcheck.sh" "${APP_URL%/}/health" "$environment" "$digest"

echo "deploy: OK - $environment is now serving $image_ref"
