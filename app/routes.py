"""HTTP routes: GET / and GET /health.

Contract: specs/001-cicd-devsecops-demo/contracts/app-endpoints.md
"""

from __future__ import annotations

from flask import Blueprint, current_app, jsonify, render_template

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
