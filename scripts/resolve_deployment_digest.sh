#!/usr/bin/env sh
# Fetch recent GitHub Deployments for an environment and print the previous known-good digest.
# Pure lookup — makes no infrastructure changes. Used by both scripts/rollback.sh (which then
# deploys the result) and .github/workflows/rollback.yml's resolve job (which then delegates to
# deploy.yml, so all actual promotion logic stays in one place).
#
# Usage: resolve_deployment_digest.sh <environment> [current-deployment-id]
#
# Required environment variables: GITHUB_REPOSITORY (owner/repo), GITHUB_TOKEN.
set -eu

environment="${1:?usage: resolve_deployment_digest.sh <environment> [current-deployment-id]}"
current_deployment_id="${2:-}"

: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY must be set (owner/repo)}"
: "${GITHUB_TOKEN:?GITHUB_TOKEN must be set}"

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

records_json="$(curl -fsS \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${GITHUB_REPOSITORY}/deployments?environment=${environment}&per_page=20" \
    | python3 -c '
import json, sys
deployments = json.load(sys.stdin)
records = [
    {
        "id": d["id"],
        "created_at": d["created_at"],
        "payload": d.get("payload", {}),
        "status": None,
        "statuses_url": d["statuses_url"],
    }
    for d in deployments
]
print(json.dumps(records))
')"

# The Deployments list endpoint does not include status directly; each deployment's latest
# status lives at its own statuses_url sub-resource.
records_json="$(printf '%s' "$records_json" | python3 -c '
import json, sys, os, urllib.request

records = json.load(sys.stdin)
token = os.environ["GITHUB_TOKEN"]

def latest_status(url):
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
    })
    with urllib.request.urlopen(req, timeout=10) as resp:
        statuses = json.load(resp)
    return statuses[0]["state"] if statuses else "unknown"

for r in records:
    r["status"] = latest_status(r["statuses_url"])
    del r["statuses_url"]

print(json.dumps(records))
')"

exclude_arg=""
[ -n "$current_deployment_id" ] && exclude_arg="--exclude-id $current_deployment_id"

# shellcheck disable=SC2086
printf '%s' "$records_json" | python3 "$script_dir/resolve_previous_digest.py" --records-file - $exclude_arg
