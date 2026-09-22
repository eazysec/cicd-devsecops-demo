#!/usr/bin/env sh
# Emergency Demo Plan: reproduces the pre-deploy pipeline entirely locally, with zero
# dependency on GitHub, the container registry, or the deployment platform being reachable.
#
# lint -> tests -> secret scan -> docker build -> (trivy, if installed) -> docker run ->
# healthcheck -> smoke test
#
# Stops at, and clearly names, the first failing stage. Optional tools that are simply not
# installed are reported as SKIPPED, never as a failure.
set -eu

cd "$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

IMAGE_NAME="cicd-devsecops-demo:local"
CONTAINER_NAME="cicd-devsecops-demo-local"
PORT="${DEMO_LOCAL_PORT:-8080}"

pass() { printf '✅ %s\n' "$1"; }
skip() { printf '⏭️  %s (skipped: %s)\n' "$1" "$2"; }
fail() {
    printf '❌ %s\n' "$1" >&2
    echo "" >&2
    # Dump the container's logs BEFORE cleanup removes it — otherwise the evidence needed to
    # diagnose the failure is gone by the time this script exits (found the hard way: a health
    # check failure left no way to inspect why without manually re-running docker outside the
    # script).
    if docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
        echo "---- docker logs $CONTAINER_NAME (captured before cleanup) ----" >&2
        docker logs "$CONTAINER_NAME" >&2 2>&1 || true
        echo "---- end docker logs ----" >&2
        echo "" >&2
    fi
    echo "Emergency Demo Plan stopped at: $1" >&2
    cleanup
    exit 1
}
cleanup() { docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true; }
# Only clean up on failure (fail(), above) or an interrupted run (Ctrl+C) — NOT on a normal
# successful exit. A blanket `trap cleanup EXIT` was removing the container immediately after
# printing "App is running at ...", so the app was already gone by the time anyone opened a
# browser. On success the container is deliberately left running for interactive use.
trap cleanup INT TERM

echo "== 1/8 Lint (Ruff) =="
if command -v ruff >/dev/null 2>&1; then
    ruff_cmd="ruff"
else
    ruff_cmd="python3 -m ruff"
fi
if $ruff_cmd check .; then pass "Lint"; else fail "Lint"; fi

echo "== 2/8 Unit + integration tests (pytest) =="
if python3 -m pytest --cov=app --cov-report=term-missing; then pass "Tests"; else fail "Tests"; fi

echo "== 3/8 Secret scan (Gitleaks) =="
if command -v gitleaks >/dev/null 2>&1; then
    if gitleaks detect --no-banner --source . --redact; then pass "Secret scan"; else fail "Secret scan"; fi
else
    skip "Secret scan" "gitleaks not installed — see README Emergency Demo Plan for install command"
fi

echo "== 4/8 Docker build =="
if ! command -v docker >/dev/null 2>&1; then
    fail "Docker build (docker is not installed — this stage cannot be skipped, later stages need a running container)"
fi
git_sha="$(git rev-parse --short HEAD 2>/dev/null || echo local)"
build_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if docker build \
    --build-arg APP_VERSION="0.0.0-local" \
    --build-arg GIT_SHA="$git_sha" \
    --build-arg BUILD_TIME="$build_time" \
    -t "$IMAGE_NAME" .; then
    pass "Docker build"
else
    fail "Docker build"
fi

echo "== 5/8 Trivy image scan =="
if command -v trivy >/dev/null 2>&1; then
    if trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 \
        --trivyignores .trivyignore "$IMAGE_NAME"; then
        pass "Trivy scan"
    else
        fail "Trivy scan"
    fi
else
    skip "Trivy scan" "trivy not installed — see README Emergency Demo Plan for install command"
fi

echo "== 6/8 Docker run =="
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
if docker run -d --name "$CONTAINER_NAME" -p "${PORT}:8080" \
    -e ENVIRONMENT=local -e APP_VERSION=0.0.0-local \
    "$IMAGE_NAME" >/dev/null; then
    pass "Docker run"
else
    fail "Docker run"
fi

echo "== 7/8 Health check =="
if "$script_dir/healthcheck.sh" "http://127.0.0.1:${PORT}/health" local; then
    pass "Health check"
else
    fail "Health check"
fi

echo "== 8/8 Smoke test =="
if "$script_dir/smoke-test.sh" "http://127.0.0.1:${PORT}"; then
    pass "Smoke test"
else
    fail "Smoke test"
fi

echo ""
echo "Emergency Demo Plan: ALL STAGES PASSED."
echo "App is running at http://127.0.0.1:${PORT} — open it in a browser now."
echo "Stop it when you're done: docker rm -f ${CONTAINER_NAME}"
