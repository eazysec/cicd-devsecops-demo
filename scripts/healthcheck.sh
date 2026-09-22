#!/usr/bin/env sh
# Bounded-retry health check against a running instance of the demo app.
#
# Contract: specs/001-cicd-devsecops-demo/contracts/deploy-script.md#scriptshealthchecksh-url-environment-expected-digest
#
# Usage: healthcheck.sh <url> <environment> [expected-digest]
#   url            e.g. https://staging.demo.example/health (the full /health URL)
#   environment    staging | production | local — must match the "environment" field returned
#   expected-digest  optional; logged for operator visibility (the deployment record, not this
#                    endpoint, is the source of truth for digest confirmation — see data-model.md)
#
# Never hangs indefinitely: bounded attempts, bounded per-attempt timeout.
set -eu

ATTEMPTS="${HEALTHCHECK_ATTEMPTS:-10}"
SLEEP_SECONDS="${HEALTHCHECK_SLEEP_SECONDS:-3}"
CURL_TIMEOUT="${HEALTHCHECK_CURL_TIMEOUT:-5}"

url="${1:?usage: healthcheck.sh <url> <environment> [expected-digest]}"
environment="${2:?usage: healthcheck.sh <url> <environment> [expected-digest]}"
expected_digest="${3:-}"

i=1
while [ "$i" -le "$ATTEMPTS" ]; do
    body="$(curl -fsS --max-time "$CURL_TIMEOUT" "$url" 2>/dev/null || true)"

    if [ -n "$body" ]; then
        status="$(printf '%s' "$body" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status",""))' 2>/dev/null || true)"
        actual_env="$(printf '%s' "$body" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("environment",""))' 2>/dev/null || true)"

        if [ "$status" = "healthy" ] && [ "$actual_env" = "$environment" ]; then
            echo "healthcheck: OK ($url) attempt $i/$ATTEMPTS, environment=$actual_env"
            if [ -n "$expected_digest" ]; then
                echo "healthcheck: expected digest $expected_digest (confirm via the GitHub Deployment record, not this endpoint)"
            fi
            exit 0
        fi

        if [ "$status" = "healthy" ] && [ "$actual_env" != "$environment" ]; then
            echo "healthcheck: FAIL - reachable but environment mismatch (expected '$environment', got '$actual_env')" >&2
            exit 1
        fi
    fi

    echo "healthcheck: attempt $i/$ATTEMPTS not healthy yet, retrying in ${SLEEP_SECONDS}s..." >&2
    i=$((i + 1))
    [ "$i" -le "$ATTEMPTS" ] && sleep "$SLEEP_SECONDS"
done

echo "healthcheck: FAIL - $url did not become healthy after $ATTEMPTS attempts (~$((ATTEMPTS * SLEEP_SECONDS))s)" >&2
exit 1
