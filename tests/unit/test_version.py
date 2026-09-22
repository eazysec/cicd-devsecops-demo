from __future__ import annotations

import pytest

from app.version import (
    DEFAULT_BUILD_TIME,
    DEFAULT_ENVIRONMENT,
    DEFAULT_GIT_SHA,
    DEFAULT_VERSION,
    InvalidVersionMetadata,
    load_from_env,
)


def test_defaults_when_env_empty():
    meta = load_from_env({})
    assert meta.app_version == DEFAULT_VERSION
    assert meta.git_sha == DEFAULT_GIT_SHA
    assert meta.build_time == DEFAULT_BUILD_TIME
    assert meta.environment == DEFAULT_ENVIRONMENT
    assert meta.artifact_digest is None


def test_valid_full_env():
    meta = load_from_env(
        {
            "APP_VERSION": "1.2.3",
            "GIT_SHA": "abc1234",
            "BUILD_TIME": "2026-09-22T14:03:11Z",
            "ENVIRONMENT": "production",
            "ARTIFACT_DIGEST": "sha256:deadbeef",
        }
    )
    assert meta.app_version == "1.2.3"
    assert meta.git_sha == "abc1234"
    assert meta.build_time == "2026-09-22T14:03:11Z"
    assert meta.environment == "production"
    assert meta.artifact_digest == "sha256:deadbeef"


@pytest.mark.parametrize(
    "good_version",
    ["1.2.3", "0.0.0-dev", "0.0.0-local", "1.0.0-rc.1", "1.2.3+build.5", "2.0.0-rc.1+build.5"],
)
def test_valid_semver_with_prerelease_and_build_metadata_accepted(good_version):
    # Regression test: local/dev defaults ("0.0.0-dev", "0.0.0-local") use a pre-release
    # suffix and MUST validate — this bug crashed every local/demo container at startup
    # (gunicorn worker boot failure) before the regex was widened to full SemVer 2.0.0.
    meta = load_from_env({"APP_VERSION": good_version})
    assert meta.app_version == good_version


@pytest.mark.parametrize(
    "bad_version",
    ["1.2", "1.2.3.4", "v1.2.3", "1.2.x", "latest"],
)
def test_invalid_semver_rejected(bad_version):
    with pytest.raises(InvalidVersionMetadata):
        load_from_env({"APP_VERSION": bad_version})


@pytest.mark.parametrize("bad_env", ["prod", "PRODUCTION", "dev", ""])
def test_invalid_environment_rejected(bad_env):
    if bad_env == "":
        # Empty string falls back to the default rather than being rejected.
        meta = load_from_env({"ENVIRONMENT": bad_env})
        assert meta.environment == DEFAULT_ENVIRONMENT
    else:
        with pytest.raises(InvalidVersionMetadata):
            load_from_env({"ENVIRONMENT": bad_env})


def test_to_health_dict_shape():
    meta = load_from_env(
        {"APP_VERSION": "2.0.0", "GIT_SHA": "deadbee", "ENVIRONMENT": "staging"}
    )
    assert meta.to_health_dict() == {
        "status": "healthy",
        "application": "cicd-devsecops-demo",
        "version": "2.0.0",
        "environment": "staging",
        "commit": "deadbee",
    }
