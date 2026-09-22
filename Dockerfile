# syntax=docker/dockerfile:1
FROM --platform=linux/amd64 python:3.13-slim AS base

# Build-time metadata (Principle I: these are baked in because they describe the artifact
# itself; ENVIRONMENT and ARTIFACT_DIGEST are deliberately NOT here — see
# specs/001-cicd-devsecops-demo/data-model.md#versionmetadata — they are supplied as
# container run-time -e vars so the same image is promoted unchanged across environments).
ARG APP_VERSION=0.0.0-dev
ARG GIT_SHA=unknown
ARG BUILD_TIME=unknown
ENV APP_VERSION=${APP_VERSION} \
    GIT_SHA=${GIT_SHA} \
    BUILD_TIME=${BUILD_TIME} \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Install dependencies first for better layer caching.
COPY pyproject.toml ./
RUN pip install --no-cache-dir .

COPY app ./app

# Run as non-root (FR-029).
RUN useradd --create-home --shell /usr/sbin/nologin appuser
USER appuser

EXPOSE 8080
ENV PORT=8080

HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c 'import os, urllib.request; urllib.request.urlopen("http://127.0.0.1:" + os.environ.get("PORT", "8080") + "/health", timeout=2)' || exit 1

CMD ["sh", "-c", "gunicorn --bind 0.0.0.0:${PORT} --workers 2 --access-logfile - app.main:app"]
