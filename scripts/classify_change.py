#!/usr/bin/env python3
"""Policy engine: classify a set of changed file paths into a pipeline change type.

Implements the ChangeClassification rules from
specs/001-cicd-devsecops-demo/data-model.md#changeclassification. Used both as a CLI (invoked
by .github/actions/classify-change) and importable for unit testing
(tests/unit/test_classify_change.py).

Rules (constitution Principle III, spec.md FR-015/FR-016):
  - Any changed path outside the doc-like allow-list -> "application" (never downgraded by a
    mix of doc + code changes).
  - Any changed path under .github/workflows/, Dockerfile, or scripts/ -> "pipeline_infra".
  - Everything changed matches the doc-like allow-list -> "docs_only".
  - No changed files at all -> "application" (safe default: never under-scope on missing info).
"""

from __future__ import annotations

import argparse
import fnmatch
import sys
from dataclasses import dataclass, field

DOC_LIKE_PATTERNS = ("*.md", "docs/*")
PIPELINE_INFRA_PATTERNS = (".github/workflows/*", "Dockerfile", "scripts/*")

DOCS_ONLY = "docs_only"
APPLICATION = "application"
PIPELINE_INFRA = "pipeline_infra"


@dataclass(frozen=True)
class ChangeClassification:
    change_type: str
    reasons: list[str] = field(default_factory=list)


def _matches_any(path: str, patterns: tuple[str, ...]) -> bool:
    return any(fnmatch.fnmatch(path, pattern) for pattern in patterns)


def classify(changed_files: list[str]) -> ChangeClassification:
    if not changed_files:
        return ChangeClassification(
            change_type=APPLICATION,
            reasons=["no changed files reported; defaulting to the full gate set"],
        )

    infra_hits = [f for f in changed_files if _matches_any(f, PIPELINE_INFRA_PATTERNS)]
    non_doc_hits = [f for f in changed_files if not _matches_any(f, DOC_LIKE_PATTERNS)]

    if infra_hits:
        return ChangeClassification(
            change_type=PIPELINE_INFRA,
            reasons=[f"pipeline/infra path changed: {f}" for f in infra_hits],
        )

    if not non_doc_hits:
        return ChangeClassification(
            change_type=DOCS_ONLY,
            reasons=["only documentation-like paths changed: " + ", ".join(changed_files)],
        )

    return ChangeClassification(
        change_type=APPLICATION,
        reasons=[f"non-documentation path changed: {f}" for f in non_doc_hits],
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--changed-files",
        nargs="*",
        default=None,
        help="Space-separated list of changed file paths (e.g. from `git diff --name-only`)",
    )
    parser.add_argument(
        "--changed-files-file",
        default=None,
        help=(
            "Path to a file with one changed path per line (avoids shell word-splitting "
            "issues with spaces in filenames; '-' reads from stdin)"
        ),
    )
    args = parser.parse_args(argv)

    if args.changed_files_file is not None:
        text = (
            sys.stdin.read()
            if args.changed_files_file == "-"
            else open(args.changed_files_file, encoding="utf-8").read()  # noqa: SIM115
        )
        changed_files = [line for line in text.splitlines() if line.strip()]
    else:
        changed_files = args.changed_files or []

    result = classify(changed_files)
    print(result.change_type)
    for reason in result.reasons:
        print(f"reason: {reason}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
