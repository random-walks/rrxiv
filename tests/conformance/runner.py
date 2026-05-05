#!/usr/bin/env python3
"""rrvix conformance test runner.

Drives an arbitrary parser implementation (any command that takes a
.tex file and writes a CIR JSON) through the fixtures in
``tests/conformance/fixtures/``. Compares each result to the
fixture's ``expected.cir.json``, ignoring environment-specific fields.

Usage:

    python tests/conformance/runner.py --impl 'uv run rrvix parse'
    python tests/conformance/runner.py --impl '/path/to/parse-rrvix' --verbose

Exit codes: 0 on full pass, 1 on any failure.
"""

from __future__ import annotations

import argparse
import json
import os
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
FIXTURES_DIR = Path(__file__).resolve().parent / "fixtures"

# Fields that vary per environment / per ingestion. Always excluded from
# the semantic diff.
DEFAULT_IGNORE_FIELDS: set[str] = {
    "submitted_at",
    "source.uri",
}


def _normalise(value: Any) -> Any:
    """Make dicts/lists hashable-ish for stable comparison."""
    if isinstance(value, dict):
        return {k: _normalise(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_normalise(v) for v in value]
    return value


def _flatten(prefix: str, value: Any, into: dict[str, Any]) -> None:
    if isinstance(value, dict):
        for k, v in value.items():
            _flatten(f"{prefix}.{k}" if prefix else k, v, into)
    elif isinstance(value, list):
        # Lists treated as ordered; index in path
        for i, v in enumerate(value):
            _flatten(f"{prefix}[{i}]", v, into)
    else:
        into[prefix] = value


def _diff(expected: dict[str, Any], actual: dict[str, Any], ignore: set[str]) -> list[str]:
    """Return list of diff lines, empty if equal modulo ignore set."""
    e_flat: dict[str, Any] = {}
    a_flat: dict[str, Any] = {}
    _flatten("", _normalise(expected), e_flat)
    _flatten("", _normalise(actual), a_flat)

    def _is_ignored(path: str) -> bool:
        # Strip array indices for comparison: foo[3].bar -> foo.bar
        stripped = "".join(
            c for c in path if not (c.isdigit() or c in "[]")
        ).replace("..", ".").strip(".")
        return any(stripped == ig or stripped.startswith(ig + ".") for ig in ignore)

    diffs: list[str] = []
    keys = sorted(set(e_flat.keys()) | set(a_flat.keys()))
    for k in keys:
        if _is_ignored(k):
            continue
        e = e_flat.get(k, "<missing>")
        a = a_flat.get(k, "<missing>")
        if e != a:
            diffs.append(f"  {k}\n    expected: {e!r}\n    actual:   {a!r}")
    return diffs


def _run_one(
    impl_cmd: str,
    fixture_dir: Path,
    verbose: bool = False,
) -> tuple[bool, str]:
    """Run the parser on a fixture; return (ok, message)."""
    expected_path = fixture_dir / "expected.cir.json"
    if not expected_path.is_file():
        return False, f"no expected.cir.json in {fixture_dir}"

    # Find a single .tex source in the fixture
    tex_candidates = sorted(fixture_dir.glob("*.tex"))
    if not tex_candidates:
        return False, f"no .tex source in {fixture_dir}"
    if len(tex_candidates) > 1:
        return False, f"multiple .tex sources in {fixture_dir} — pick one canonical"
    tex_path = tex_candidates[0]

    # Run the implementation
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".cir.json", delete=False
    ) as tmp:
        out_path = Path(tmp.name)
    try:
        cmd = shlex.split(impl_cmd) + [str(tex_path), "--output", str(out_path)]
        env = os.environ.copy()
        result = subprocess.run(
            cmd,
            cwd=str(REPO_ROOT.parent / "rrvix-python")
            if (REPO_ROOT.parent / "rrvix-python").is_dir()
            else None,
            capture_output=True,
            text=True,
            timeout=60,
            env=env,
        )
        if result.returncode != 0:
            return False, (
                f"impl exited {result.returncode}\n"
                f"  stderr: {result.stderr.strip()}"
            )

        actual = json.loads(out_path.read_text(encoding="utf-8"))
    finally:
        out_path.unlink(missing_ok=True)

    expected = json.loads(expected_path.read_text(encoding="utf-8"))
    fixture_ignore = set(expected.pop("_ignore_fields", []))
    diff_lines = _diff(expected, actual, DEFAULT_IGNORE_FIELDS | fixture_ignore)

    if not diff_lines:
        return True, "ok"

    msg_lines = [f"diff in {fixture_dir.name}:"]
    msg_lines.extend(diff_lines if verbose else diff_lines[:10])
    if not verbose and len(diff_lines) > 10:
        msg_lines.append(f"  ... ({len(diff_lines) - 10} more; pass --verbose to see all)")
    return False, "\n".join(msg_lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--impl",
        required=True,
        help="Command line for the parser under test, e.g. 'uv run rrvix parse'.",
    )
    parser.add_argument("--verbose", "-v", action="store_true")
    args = parser.parse_args()

    fixtures = sorted(p for p in FIXTURES_DIR.iterdir() if p.is_dir())
    if not fixtures:
        print(f"No fixtures in {FIXTURES_DIR}", file=sys.stderr)
        return 1

    failures: list[tuple[str, str]] = []
    for fixture in fixtures:
        ok, msg = _run_one(args.impl, fixture, verbose=args.verbose)
        status = "PASS" if ok else "FAIL"
        print(f"  {status}  {fixture.name}")
        if not ok:
            print(msg)
            failures.append((fixture.name, msg))

    print("")
    print(f"{len(fixtures) - len(failures)}/{len(fixtures)} fixtures passed.")
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
