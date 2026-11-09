#!/usr/bin/env bash
# Build private artifacts by default. Publication requires explicit --publish.
set -euo pipefail
cd -- "$(dirname -- "$0")"
release_log_dir="$(python3 -c 'import os,tempfile; os.umask(0o077); print(tempfile.mkdtemp(prefix="tessera-release-wrapper-", dir="/tmp"))')"
exec python3 tools/run_bounded.py --timeout 2400 --log "$release_log_dir/release.log" -- \
  python3 -m ci.release "$@"
