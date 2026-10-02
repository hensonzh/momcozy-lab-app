#!/usr/bin/env python3
"""Validate public B CI identity and emit Flutter-only compile defines.

The output is a disposable, unsigned build input, not a release declaration.
"""

import argparse
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "config/release-lanes/north-america-staging.ci.json"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    subprocess.run(
        ["node", "scripts/check-north-america-staging-target.mjs", "--config", str(TARGET)],
        cwd=ROOT,
        check=True,
    )
    target = json.loads(TARGET.read_text())
    defines = {
        "MOMCOZY_ENV": target["runtimeEnvironment"],
        "MOMCOZY_API_BASE_URL": target["productApiBaseUrl"],
        "MOMCOZY_AGENT_API_BASE_URL": target["agentApiBaseUrl"],
        "MOMCOZY_INTERNAL_INVITE_LOGIN": "false",
    }
    args.output.write_text(json.dumps(defines, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
