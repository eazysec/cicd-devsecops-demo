#!/usr/bin/env sh
# Prints a random-looking, never-real, never-reused fake AWS-style credential pair for the
# Conference Runbook's Scenario C (secret-scanning demo — spec.md US3).
#
# Deliberately generated fresh each run, NEVER hardcoded anywhere in this repository: a fixed
# literal value sitting in a tracked file (even documentation) is exactly what GitHub's own
# push-protection secret scanning is designed to catch — it did, on this repo's very first
# push, blocking the push of quickstart.md/recap.md themselves. Generating it on demand avoids
# ever having a "real-looking" static string at rest in git history.
#
# Usage: scripts/generate-demo-secret.sh >> app/scratch_do_not_commit.py
set -eu

random_from_charset() {
    charset="$1"
    length="$2"
    LC_ALL=C tr -dc "$charset" < /dev/urandom | head -c "$length"
}

access_key_id="AKIA$(random_from_charset 'A-Z0-9' 16)"
secret_access_key="$(random_from_charset 'A-Za-z0-9+/' 40)"

cat <<EOF
aws_access_key_id = "${access_key_id}"
aws_secret_access_key = "${secret_access_key}"
EOF
