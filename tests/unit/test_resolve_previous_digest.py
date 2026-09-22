from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from scripts.resolve_previous_digest import NoKnownGoodDeploymentError, resolve_previous_digest


def _record(id_, created_at, status="success", digest="sha256:aaa", version="1.0.0"):
    return {
        "id": id_,
        "created_at": created_at,
        "status": status,
        "payload": {"digest": digest, "version": version},
    }


def test_returns_most_recent_successful_deployment():
    records = [
        _record(1, "2026-09-20T10:00:00Z", digest="sha256:aaa", version="1.0.0"),
        _record(2, "2026-09-21T10:00:00Z", digest="sha256:bbb", version="1.0.1"),
        _record(3, "2026-09-22T10:00:00Z", digest="sha256:ccc", version="1.0.2"),
    ]
    resolved = resolve_previous_digest(records, exclude_id=3)
    assert resolved.digest == "sha256:bbb"
    assert resolved.version == "1.0.1"


def test_ignores_failed_and_in_progress_records():
    records = [
        _record(1, "2026-09-20T10:00:00Z", status="success", digest="sha256:aaa"),
        _record(2, "2026-09-21T10:00:00Z", status="failure", digest="sha256:bbb"),
        _record(3, "2026-09-22T10:00:00Z", status="in_progress", digest="sha256:ccc"),
    ]
    resolved = resolve_previous_digest(records, exclude_id=None)
    assert resolved.digest == "sha256:aaa"


def test_raises_when_no_prior_successful_deployment():
    records = [_record(1, "2026-09-22T10:00:00Z", status="success", digest="sha256:aaa")]
    with pytest.raises(NoKnownGoodDeploymentError):
        resolve_previous_digest(records, exclude_id=1)


def test_raises_on_empty_records():
    with pytest.raises(NoKnownGoodDeploymentError):
        resolve_previous_digest([], exclude_id=None)


def test_sorts_by_created_at_not_list_order():
    records = [
        _record(1, "2026-09-22T10:00:00Z", digest="sha256:newest"),
        _record(2, "2026-09-19T10:00:00Z", digest="sha256:oldest"),
        _record(3, "2026-09-20T10:00:00Z", digest="sha256:middle"),
    ]
    # exclude the newest (simulating "current"); order in the list is deliberately scrambled.
    resolved = resolve_previous_digest(records, exclude_id=1)
    assert resolved.digest == "sha256:middle"
