"""Validate a release's dSYM identity, then upload without source files."""

import argparse
import os
import plistlib
import re
import subprocess
from pathlib import Path

from validate_release import validate


def symbol_uuids(path: Path) -> set[str]:
    result = subprocess.run(["dwarfdump", "--uuid", str(path)], check=True, capture_output=True, text=True, timeout=30)
    ids = set(re.findall(r"UUID: ([0-9A-Fa-f-]{36})", result.stdout))
    if not ids:
        raise ValueError("No debug UUIDs found")
    return ids


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--products", type=Path, required=True)
    parser.add_argument("--cli", type=Path, required=True)
    args = parser.parse_args()
    app = args.products / "Tessera.app"
    symbols = args.products / "Tessera.app.dSYM"
    with (app / "Contents/Info.plist").open("rb") as source:
        info = plistlib.load(source)
    version, build = info["CFBundleShortVersionString"], info["CFBundleVersion"]
    validate(version, build)
    if info["CFBundleIdentifier"] != "com.abdwy.Tessera":
        raise ValueError("Refusing symbols for a different app")
    if not symbols.is_dir() or symbol_uuids(app / "Contents/MacOS/Tessera") != symbol_uuids(symbols):
        raise ValueError("Release binary and dSYM UUIDs do not match")
    if not os.environ.get("POSTHOG_CLI_API_KEY") or os.environ.get("POSTHOG_CLI_PROJECT_ID") != "340688" or os.environ.get("POSTHOG_CLI_HOST") != "https://eu.posthog.com":
        raise ValueError("Dedicated Tessera PostHog access is required")
    subprocess.run([str(args.cli.resolve()), "dsym", "upload", "--directory", str(symbols.resolve()),
                    "--main-dsym", symbols.name, "--release-name", info["CFBundleIdentifier"],
                    "--release-version", version, "--build", build], check=True, timeout=180)
    print(f"Uploaded matching Tessera {version} build {build} symbols, without source files")


if __name__ == "__main__":
    main()
