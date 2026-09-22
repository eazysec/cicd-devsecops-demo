"""Build/deploy metadata for the running instance.

See specs/001-cicd-devsecops-demo/data-model.md#versionmetadata for the field contract this
module implements. APP_VERSION / GIT_SHA / BUILD_TIME are baked into the image at build time;
ENVIRONMENT and ARTIFACT_DIGEST are supplied as container run-time variables so the same image
can be promoted across environments without a rebuild (constitution Principle I).
"""

from __future__ import annotations

import os
import re
from dataclasses import dataclass

# Full SemVer 2.0.0 core + optional pre-release/build metadata (semver.org), not just a bare
# MAJOR.MINOR.PATCH — release versions from Release Please are always bare (e.g. "1.0.1"), but
# local/dev defaults deliberately use a pre-release suffix ("0.0.0-dev", "0.0.0-local") to make
# a non-released build visually obvious on the status page, and that suffix must validate too.
_SEMVER_RE = re.compile(
    r"^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$"
)
_VALID_ENVIRONMENTS = ("staging", "production", "local")

DEFAULT_VERSION = "0.0.0-dev"
DEFAULT_GIT_SHA = "unknown"
DEFAULT_BUILD_TIME = "unknown"
DEFAULT_ENVIRONMENT = "local"


class InvalidVersionMetadata(ValueError):
    """Raised when an env-var-supplied metadata value fails validation."""


@dataclass(frozen=True)
class VersionMetadata:
    app_version: str
    git_sha: str
    build_time: str
    environment: str
    artifact_digest: str | None

    def to_health_dict(self) -> dict[str, str]:
        return {
            "status": "healthy",
            "application": "cicd-devsecops-demo",
            "version": self.app_version,
            "environment": self.environment,
            "commit": self.git_sha,
        }


def _validated_version(raw: str | None) -> str:
    if raw is None or raw == "":
        return DEFAULT_VERSION
    if not _SEMVER_RE.match(raw):
        raise InvalidVersionMetadata(
            f"APP_VERSION={raw!r} does not match SemVer MAJOR.MINOR.PATCH"
        )
    return raw


def _validated_environment(raw: str | None) -> str:
    if raw is None or raw == "":
        return DEFAULT_ENVIRONMENT
    if raw not in _VALID_ENVIRONMENTS:
        raise InvalidVersionMetadata(
            f"ENVIRONMENT={raw!r} must be one of {_VALID_ENVIRONMENTS}"
        )
    return raw


def load_from_env(env: dict[str, str] | None = None) -> VersionMetadata:
    """Build VersionMetadata from environment variables (defaults to os.environ)."""
    source = env if env is not None else os.environ
    return VersionMetadata(
        app_version=_validated_version(source.get("APP_VERSION")),
        git_sha=source.get("GIT_SHA") or DEFAULT_GIT_SHA,
        build_time=source.get("BUILD_TIME") or DEFAULT_BUILD_TIME,
        environment=_validated_environment(source.get("ENVIRONMENT")),
        artifact_digest=source.get("ARTIFACT_DIGEST") or None,
    )
