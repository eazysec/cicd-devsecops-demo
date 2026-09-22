"""Entrypoint: `flask --app app.main run` (dev) or `gunicorn app.main:app` (container).

Honors the PORT environment variable (spec.md FR-003); defaults to 8080 for local runs
matching the container's default HEALTHCHECK/EXPOSE port.
"""

from __future__ import annotations

import os

from app import create_app

app = create_app()

if __name__ == "__main__":
    # Dev-only entrypoint; needs external access for local/container testing. Production runs
    # via gunicorn, not this path.
    port = int(os.environ.get("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)  # nosec B104
