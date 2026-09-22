#!/usr/bin/env sh
# Black-box smoke tests against a running instance.
#
# Contract: specs/001-cicd-devsecops-demo/contracts/deploy-script.md#scriptssmoke-testsh-url
#
# Usage: smoke-test.sh <base-url>   (e.g. https://staging.demo.example, no trailing slash)
set -eu

base_url="${1:?usage: smoke-test.sh <base-url>}"
CURL_TIMEOUT="${SMOKE_TEST_CURL_TIMEOUT:-5}"

fail() {
    echo "smoke-test: FAIL - $1" >&2
    exit 1
}

# 1. GET / returns 200 and mentions the project name.
index_body="$(curl -fsS --max-time "$CURL_TIMEOUT" "$base_url/" 2>/dev/null)" || fail "GET / did not return 200"
case "$index_body" in
    *cicd-devsecops-demo*) : ;;
    *) fail "GET / body does not mention the project name" ;;
esac

# 2. GET /health returns 200 with valid, schema-matching JSON.
health_body="$(curl -fsS --max-time "$CURL_TIMEOUT" "$base_url/health" 2>/dev/null)" || fail "GET /health did not return 200"

python3 - "$health_body" <<'PY' || exit 1
import json
import re
import sys

body = sys.argv[1]
try:
    data = json.loads(body)
except json.JSONDecodeError:
    print("smoke-test: FAIL - /health body is not valid JSON", file=sys.stderr)
    raise SystemExit(1)

required = {
    "status": lambda v: v == "healthy",
    "application": lambda v: v == "cicd-devsecops-demo",
    "version": lambda v: bool(re.match(r"^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$", v)),
    "environment": lambda v: v in ("staging", "production", "local"),
    "commit": lambda v: bool(v),
}

for field, check in required.items():
    if field not in data:
        print(f"smoke-test: FAIL - /health missing field '{field}'", file=sys.stderr)
        raise SystemExit(1)
    if not check(data[field]):
        print(f"smoke-test: FAIL - /health field '{field}' failed validation: {data[field]!r}", file=sys.stderr)
        raise SystemExit(1)

print("smoke-test: OK - /health schema valid")
PY

echo "smoke-test: OK - all checks passed for $base_url"
