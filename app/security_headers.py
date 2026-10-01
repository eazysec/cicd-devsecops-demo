"""Security response headers — demo fix for the DAST (ZAP) Conference Runbook scenario.

Prepared on a dedicated branch (see README Conference Runbook), deliberately NOT merged until
the live demo. Before this fix, a real ZAP baseline scan against the actual deployed staging
instance (release 1.2.0, before this branch existed) found 7 genuine WARN-NEW findings —
nothing staged/faked, see docs/retex-webinar.md and research.md D9:

  - Missing Anti-clickjacking Header [10020]                -> fixed here (X-Frame-Options)
  - X-Content-Type-Options Header Missing [10021]            -> fixed here
  - Content Security Policy (CSP) Header Not Set [10038]     -> fixed here
  - Permissions Policy Header Not Set [10063]                -> fixed here
  - Cross-Origin-Embedder-Policy Header Missing [90004]      -> fixed here
  - Storable and Cacheable Content [10049]                   -> deliberately NOT fixed, see below
  - Modern Web Application [10109]                           -> not a vulnerability, see below

Two findings are deliberately left as-is, not silently missed:

  - **Storable and Cacheable Content [10049]**: this app is a read-only, public status page with
    no sensitive data — there is nothing a cached response could leak. Fixing every ZAP finding
    mechanically, regardless of whether it applies to this app's actual threat model, is exactly
    the kind of security theatre this project argues against elsewhere (see
    docs/retex-webinar.md). Reviewed and accepted, not overlooked.
  - **Modern Web Application [10109]**: an informational fingerprinting note (ZAP detected
    JS-framework-like patterns), not a vulnerability — there is nothing to "fix."

Also out of scope, for a different reason: the `Server` header ZAP flags separately is set by
gunicorn below the WSGI application layer and isn't reliably overridable from a Flask
`after_request` hook.
"""

from __future__ import annotations

from flask import Flask, Response

# 'unsafe-inline' is required because app/templates/index.html has an inline <style> and an
# inline <script> (the client-side /health poll) — externalizing both to satisfy a stricter CSP
# without 'unsafe-inline' is a reasonable follow-up, out of scope for this fix.
_CSP = "default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'"

# This app uses none of these browser features — deny all of them explicitly rather than leave
# the header absent.
_PERMISSIONS_POLICY = "geolocation=(), microphone=(), camera=()"


def register_security_headers(app: Flask) -> None:
    @app.after_request
    def _add_security_headers(response: Response) -> Response:
        response.headers["Content-Security-Policy"] = _CSP
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "no-referrer"
        response.headers["Permissions-Policy"] = _PERMISSIONS_POLICY
        response.headers["Cross-Origin-Embedder-Policy"] = "require-corp"
        return response
