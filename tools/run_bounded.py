"""Run one finite command with a log, PID and process-group deadline."""

import argparse
import os
import signal
import subprocess
import time
from pathlib import Path


def signal_owned_group(pgid, signum):
    # Darwin can return EPERM while launchd reaps the last orphaned zombie.
    # Confirm that the group is gone or signal it; a lasting denial is a failure.
    deadline = time.monotonic() + 1
    while True:
        try:
            os.killpg(pgid, signum)
            return True
        except ProcessLookupError:
            return False
        except PermissionError:
            if time.monotonic() >= deadline:
                raise
            time.sleep(0.01)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timeout", type=float, required=True)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command or args.timeout <= 0:
        parser.error("A command and positive timeout are required")
    args.log.parent.mkdir(parents=True, exist_ok=True)
    with args.log.open("w") as log:
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        pid_file = args.log.with_suffix(args.log.suffix + ".pid")
        pid_file.write_text(str(process.pid) + "\n")

        def stop_group(*_):
            if not signal_owned_group(process.pid, signal.SIGTERM):
                return
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                pass
            signal_owned_group(process.pid, signal.SIGKILL)

        def interrupted(signum, _frame):
            stop_group()
            raise SystemExit(128 + signum)

        signal.signal(signal.SIGTERM, interrupted)
        signal.signal(signal.SIGINT, interrupted)
        try:
            status = process.wait(timeout=args.timeout)
        except subprocess.TimeoutExpired:
            stop_group()
            status = 124
        finally:
            # A successful leader can leave descendants behind. This command's
            # process group is owned, so stop any leftovers on every exit path.
            try:
                stop_group()
                process.wait(timeout=5)
            finally:
                pid_file.unlink(missing_ok=True)
    print(f"exit={status}; log={args.log}")
    if status:
        print(args.log.read_text(errors="replace")[-12000:])
    return status


if __name__ == "__main__":
    raise SystemExit(main())
