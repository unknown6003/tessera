"""Check the release series before any build or publication step."""

import argparse
import plistlib
import re
from pathlib import Path


def validate(version: str, build: str, tag: str | None = None) -> None:
    if not re.fullmatch(r"0\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", version):
        raise ValueError("Tessera releases must stay in 0.x.x. Ammar must explicitly authorize a major milestone and its policy change.")
    if not re.fullmatch(r"[1-9][0-9]*", build):
        raise ValueError("CFBundleVersion must be a positive integer")
    if tag is not None and tag != f"v{version}":
        raise ValueError(f"Tag {tag} does not match Info.plist version {version}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plist", type=Path, default=Path("Tessera/Info.plist"))
    parser.add_argument("--tag")
    args = parser.parse_args()
    with args.plist.open("rb") as source:
        info = plistlib.load(source)
    try:
        validate(info["CFBundleShortVersionString"], info["CFBundleVersion"], args.tag)
    except ValueError as error:
        parser.exit(1, f"{error}\n")
