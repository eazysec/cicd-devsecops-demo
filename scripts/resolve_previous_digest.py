#!/usr/bin/env python3
"""Pure function: resolve the previous known-good artifact digest for an environment.

Deliberately network-free (see contracts/deploy-script.md#scriptsrollbacksh-environment) so it
is unit-testable without a live GitHub API call. scripts/rollback.sh fetches the deployment
records (via `gh api`) and pipes them, as JSON, into this script.

Input shape (one record per successful/failed/in-progress GitHub Deployment, newest first or in
any order — this module sorts by created_at itself):
    [
      {"id": 123, "created_at": "2026-09-22T10:00:00Z", "status": "success",
       "payload": {"digest": "sha256:...", "version": "1.0.1"}},
      ...
    ]

See data-model.md#deploymentrecord for the record shape this expects.
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass


class NoKnownGoodDeploymentError(RuntimeError):
    """Raised when no prior successful deployment exists for the environment."""


@dataclass(frozen=True)
class ResolvedDeployment:
    digest: str
    version: str | None
    created_at: str


def resolve_previous_digest(
    records: list[dict], *, exclude_id: int | None = None
) -> ResolvedDeployment:
    """Return the most recent successful deployment, excluding `exclude_id` (the current one).

    Raises NoKnownGoodDeploymentError if no successful record remains — callers must not guess.
    """
    candidates = [
        r
        for r in records
        if r.get("status") == "success"
        and r.get("id") != exclude_id
        and r.get("payload", {}).get("digest")
    ]
    if not candidates:
        raise NoKnownGoodDeploymentError(
            "no prior successful deployment found for this environment"
        )

    latest = max(candidates, key=lambda r: r["created_at"])
    payload = latest["payload"]
    return ResolvedDeployment(
        digest=payload["digest"],
        version=payload.get("version"),
        created_at=latest["created_at"],
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--records-file",
        default="-",
        help="Path to a JSON file of deployment records, or '-' for stdin (default)",
    )
    parser.add_argument(
        "--exclude-id",
        type=int,
        default=None,
        help="Deployment id to exclude (typically the current, in-progress deployment)",
    )
    args = parser.parse_args(argv)

    if args.records_file == "-":
        text = sys.stdin.read()
    else:
        with open(args.records_file, encoding="utf-8") as f:
            text = f.read()
    records = json.loads(text)

    try:
        resolved = resolve_previous_digest(records, exclude_id=args.exclude_id)
    except NoKnownGoodDeploymentError as exc:
        print(f"resolve_previous_digest: FAIL - {exc}", file=sys.stderr)
        return 1

    print(resolved.digest)
    print(f"resolved_version={resolved.version}", file=sys.stderr)
    print(f"resolved_created_at={resolved.created_at}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
