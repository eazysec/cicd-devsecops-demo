"""HTTP routes: GET / and GET /health.

Contract: specs/001-cicd-devsecops-demo/contracts/app-endpoints.md

DEMO BRANCH — DO NOT MERGE. /greet below is a deliberate SSTI vulnerability
(CWE-94) for the CodeQL-vs-Bandit conference demo — see
docs/codeql-demo-vulns.md for the full recipe and the safe demo procedure
(workflow_dispatch against this branch, never a PR, delete after use).
"""

from __future__ import annotations

from flask import Blueprint, current_app, jsonify, render_template, render_template_string, request

bp = Blueprint("routes", __name__)


@bp.get("/")
def index():
    meta = current_app.config["VERSION_METADATA"]
    return render_template(
        "index.html",
        app_version=meta.app_version,
        environment=meta.environment,
        git_sha=meta.git_sha,
        build_time=meta.build_time,
        artifact_digest=meta.artifact_digest,
    )


@bp.get("/health")
def health():
    meta = current_app.config["VERSION_METADATA"]
    return jsonify(meta.to_health_dict())


def _build_greeting_template(name: str) -> str:
    return f"<p>Welcome back, {name}!</p>"


@bp.get("/greet")
def greet():
    name = request.args.get("name", "guest")
    return render_template_string(_build_greeting_template(name))
