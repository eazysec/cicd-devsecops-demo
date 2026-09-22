#!/usr/bin/env sh
# Restore an environment to its previous known-good artifact digest. Never rebuilds anything —
# resolves the previous successful GitHub Deployment for the environment
# (scripts/resolve_deployment_digest.sh), then delegates to deploy.sh with that digest.
#
# Contract: specs/001-cicd-devsecops-demo/contracts/deploy-script.md#scriptsrollbacksh-environment
#
# Usage: rollback.sh <environment> [current-deployment-id]
#   environment            staging | production
#   current-deployment-id  optional: the in-progress/failed deployment id to exclude when
#                           resolving "previous" (omit for a manual, operator-triggered rollback
#                           that is not reacting to a specific failed deployment)
#
# Required environment variables: everything resolve_deployment_digest.sh and deploy.sh each
# require (GITHUB_REPOSITORY, GITHUB_TOKEN, AWS_REGION, EC2_INSTANCE_ID, APP_URL, GHCR_IMAGE).
set -eu

environment="${1:?usage: rollback.sh <environment> [current-deployment-id]}"
current_deployment_id="${2:-}"

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

echo "rollback: resolving previous known-good digest for $environment"
digest="$("$script_dir/resolve_deployment_digest.sh" "$environment" "$current_deployment_id")"
echo "rollback: resolved digest: $digest"

"$script_dir/deploy.sh" "$environment" "$digest"

echo "rollback: OK - $environment restored to $digest"
