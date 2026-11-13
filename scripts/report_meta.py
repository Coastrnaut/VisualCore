#!/usr/bin/env python3
"""Shared report helpers of the UA-F11 compliance checks (specs/197-ua-f11-compliance, data-model §7).

  meta(app, configuration)   {schema, revision, clean, configuration, executable_sha256} for a check report
  write_report(path, data)   writes JSON whole or not at all (temporary file in the same directory, then rename)
  read_versioned(path)       reads a JSON object with "schema": 1; refuses a missing, non-integer or newer schema,
                             unparsable JSON and a missing file, naming the path (FR-U11-081)

Gate evidence comes only from release-check runs, which build the app in the same run; the digest of the scanned
main executable ties every report to that build (clarification 5).
"""
from __future__ import annotations

import hashlib
import json
import os
import plistlib
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCHEMA = 1


class ReportError(Exception):
    """An input or report that cannot be used; the message names the path."""


def _git(*args: str) -> str:
    out = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=False)
    return out.stdout.strip() if out.returncode == 0 else ""


def executable(app: Path) -> Path:
    """The main executable of an app bundle (CFBundleExecutable, else the bundle's name without .app)."""
    name = app.name.removesuffix(".app")
    info = app / "Info.plist"
    if info.is_file():
        try:
            name = plistlib.loads(info.read_bytes()).get("CFBundleExecutable", name)
        except Exception as error:  # noqa: BLE001 - any parse failure is an unusable input
            raise ReportError(f"{info}: unreadable property list ({error})") from error
    path = app / name
    if not path.is_file():
        raise ReportError(f"{app}: no main executable {name}")
    return path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def meta(app: Path | None, configuration: str | None) -> dict:
    """Metadata recorded in every UA-F11 check report."""
    return {"schema": SCHEMA, "revision": _git("rev-parse", "HEAD"),
            "clean": _git("status", "--porcelain") == "", "configuration": configuration,
            "executable_sha256": sha256(executable(app)) if app is not None else None}


def write_report(path: Path, data: dict) -> None:
    """Write `data` as JSON atomically: an interruption leaves no file and no partial file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as handle:
            json.dump(data, handle, indent=2, sort_keys=True)
            handle.write("\n")
        os.replace(temp, path)
    except BaseException:
        Path(temp).unlink(missing_ok=True)
        raise


def read_versioned(path: Path, schema: int = SCHEMA) -> dict:
    """Read a JSON object whose "schema" is exactly `schema`."""
    try:
        data = json.loads(Path(path).read_text())
    except FileNotFoundError as error:
        raise ReportError(f"{path}: missing") from error
    except (OSError, ValueError) as error:
        raise ReportError(f"{path}: not readable JSON ({error})") from error
    if not isinstance(data, dict):
        raise ReportError(f"{path}: expected a JSON object")
    version = data.get("schema")
    if not isinstance(version, int) or isinstance(version, bool):
        raise ReportError(f"{path}: missing or non-integer schema")
    if version != schema:
        raise ReportError(f"{path}: schema {version} is not supported (expected {schema})")
    return data
