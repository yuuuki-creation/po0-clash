#!/usr/bin/env python3
"""Writes crates/core/licenses.tsv: every crate po0-ffi ships, with its license, for the apps' About pages.

Run it after Cargo.lock changes; `--check` fails when the file is out of date, which CI runs.
"""

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "crates" / "core" / "licenses.tsv"


def shipped(meta):
    packages = {package["id"]: package for package in meta["packages"]}
    nodes = {node["id"]: node for node in meta["resolve"]["nodes"]}
    members = set(meta["workspace_members"])
    stack = [id for id in members if packages[id]["name"] == "po0-ffi"]
    seen = set()
    while stack:
        for dep in nodes[stack.pop()]["deps"]:
            normal = any(kind["kind"] is None for kind in dep["dep_kinds"])
            if normal and dep["pkg"] not in seen:
                seen.add(dep["pkg"])
                stack.append(dep["pkg"])
    return sorted(
        {
            (
                packages[id]["name"],
                packages[id]["version"],
                packages[id].get("license") or "",
                packages[id].get("repository") or "",
            )
            for id in seen - members
        }
    )


def main():
    meta = json.loads(
        subprocess.check_output(["cargo", "metadata", "--format-version", "1", "--locked"], cwd=ROOT)
    )
    text = "".join("\t".join(row) + "\n" for row in shipped(meta))
    if "--check" in sys.argv[1:]:
        if not OUT.exists() or OUT.read_text() != text:
            sys.exit("crates/core/licenses.tsv is out of date: run tool/native_licenses.py")
        return
    OUT.write_text(text)


if __name__ == "__main__":
    main()
