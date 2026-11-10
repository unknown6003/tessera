#!/usr/bin/env bash
# Build private artifacts by default. Publication requires explicit --publish.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
cd -- "$(dirname -- "$0")"
release_log_dir="$(python3 -B -c 'import os,tempfile; os.umask(0o077); print(tempfile.mkdtemp(prefix="tessera-release-wrapper-", dir="/tmp"))')"
exec python3 -B tools/run_bounded.py --timeout 2400 --log "$release_log_dir/release.log" -- \
  python3 -B -m ci.release "$@"
