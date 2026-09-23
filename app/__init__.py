"""Flask application factory for cicd-devsecops-demo."""

from __future__ import annotations

from flask import Flask

from app.routes import bp
from app.security_headers import register_security_headers
from app.version import load_from_env


def create_app() -> Flask:
    app = Flask(__name__)
    app.config["VERSION_METADATA"] = load_from_env()
    app.register_blueprint(bp)
    register_security_headers(app)
    return app
