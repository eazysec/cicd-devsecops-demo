from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from scripts.classify_change import APPLICATION, DOCS_ONLY, PIPELINE_INFRA, classify


def test_docs_only_single_file():
    result = classify(["README.md"])
    assert result.change_type == DOCS_ONLY


def test_docs_only_nested_docs_dir():
    result = classify(["README.md", "docs/adr/0001-deployment-platform.md"])
    assert result.change_type == DOCS_ONLY


def test_mixed_docs_and_code_is_application():
    result = classify(["README.md", "app/routes.py"])
    assert result.change_type == APPLICATION


def test_application_code_only():
    result = classify(["app/routes.py", "tests/unit/test_version.py"])
    assert result.change_type == APPLICATION


def test_workflow_change_is_pipeline_infra():
    result = classify([".github/workflows/release.yml"])
    assert result.change_type == PIPELINE_INFRA


def test_dockerfile_change_is_pipeline_infra():
    result = classify(["Dockerfile"])
    assert result.change_type == PIPELINE_INFRA


def test_scripts_change_is_pipeline_infra():
    result = classify(["scripts/deploy.sh"])
    assert result.change_type == PIPELINE_INFRA


def test_empty_changed_files_defaults_to_application():
    result = classify([])
    assert result.change_type == APPLICATION
    assert result.reasons
