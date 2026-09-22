from __future__ import annotations

import re

import pytest

from app import create_app


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setenv("APP_VERSION", "1.0.1")
    monkeypatch.setenv("GIT_SHA", "a1b2c3d")
    monkeypatch.setenv("BUILD_TIME", "2026-09-22T14:03:11Z")
    monkeypatch.setenv("ENVIRONMENT", "staging")
    app = create_app()
    app.testing = True
    return app.test_client()


def test_index_returns_200_html_with_expected_fields(client):
    res = client.get("/")
    assert res.status_code == 200
    assert res.content_type.startswith("text/html")
    body = res.get_data(as_text=True)
    assert "cicd-devsecops-demo" in body
    assert "1.0.1" in body
    assert "a1b2c3d" in body
    assert "staging" in body


def test_health_returns_200_json_matching_contract(client):
    res = client.get("/health")
    assert res.status_code == 200
    assert res.content_type.startswith("application/json")
    data = res.get_json()

    assert data["status"] == "healthy"
    assert data["application"] == "cicd-devsecops-demo"
    assert re.match(r"^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$", data["version"])
    assert data["environment"] in ("staging", "production", "local")
    assert data["commit"]


def test_health_defaults_work_with_no_env(monkeypatch):
    for var in ("APP_VERSION", "GIT_SHA", "BUILD_TIME", "ENVIRONMENT", "ARTIFACT_DIGEST"):
        monkeypatch.delenv(var, raising=False)
    app = create_app()
    app.testing = True
    res = app.test_client().get("/health")
    assert res.status_code == 200
    data = res.get_json()
    assert data["environment"] == "local"
