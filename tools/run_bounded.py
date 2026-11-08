"""Run one finite command with a log, PID and process-group deadline."""

import argparse
import os
import signal
import subprocess
from pathlib import Path


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
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                return
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                pass
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass

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
            pid_file.unlink(missing_ok=True)
    print(f"exit={status}; log={args.log}")
    if status:
        print(args.log.read_text(errors="replace")[-12000:])
    return status


if __name__ == "__main__":
    raise SystemExit(main())
