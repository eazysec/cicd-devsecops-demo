from __future__ import annotations

from app import create_app


def test_security_headers_present_on_index(monkeypatch):
    app = create_app()
    app.testing = True
    res = app.test_client().get("/")

    assert "'self'" in res.headers["Content-Security-Policy"]
    assert res.headers["X-Content-Type-Options"] == "nosniff"
    assert res.headers["X-Frame-Options"] == "DENY"
    assert res.headers["Referrer-Policy"] == "no-referrer"
    assert "geolocation=()" in res.headers["Permissions-Policy"]
    assert res.headers["Cross-Origin-Embedder-Policy"] == "require-corp"


def test_security_headers_present_on_health(monkeypatch):
    app = create_app()
    app.testing = True
    res = app.test_client().get("/health")

    assert res.headers["X-Content-Type-Options"] == "nosniff"
    assert res.headers["X-Frame-Options"] == "DENY"
    assert res.headers["Permissions-Policy"]
    assert res.headers["Cross-Origin-Embedder-Policy"] == "require-corp"
