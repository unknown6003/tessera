"""Install the reviewed recipe as a user-owned timer, without a paid service."""

import argparse
import fcntl
import os
from pathlib import Path
import plistlib
import shutil
import sys

from .common import LANES, policy_hash, run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--lane", choices=LANES, required=True)
    parser.add_argument("--key", type=Path, required=True)
    args = parser.parse_args()
    source = Path(__file__).resolve().parent.parent
    state = args.state.resolve()
    if any(character in str(state) for character in ("\n", "\r")):
        raise ValueError("CI state path must not contain a line break")
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    lock = (state / "runner.lock").open("w")
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    key = args.key.read_bytes()
    if len(key) != 32:
        raise ValueError("CI signing key must be 32 bytes")
    if (state / "attestation.key").exists() and (state / "attestation.key").read_bytes() != key:
        raise ValueError("Refusing an unrequested CI signing-key rotation")
    descriptor = os.open(state / "attestation.key", os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, "wb") as target:
        os.fchmod(target.fileno(), 0o600)
        target.write(key)
    code = state / "recipes" / policy_hash(source)
    if not code.exists():
        (code / "ci").mkdir(parents=True)
        (code / "tools").mkdir()
        for path in (source / "ci").glob("*.py"):
            shutil.copy2(path, code / "ci" / path.name)
        for name in ("run_bounded.py", "analyze_scan_performance.py", "validate_release.py"):
            shutil.copy2(source / "tools" / name, code / "tools" / name)
    command = [sys.executable, str(code / "tools/run_bounded.py"), "--timeout", "3900",
               "--log", str(state / "supervisor.log"), "--", sys.executable, "-m", "ci.runner",
               "--state", str(state), "--lane", args.lane]
    label = "com.abdwy.tessera-ci." + args.lane
    path_env = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + str(Path.home() / ".local/bin")
    if sys.platform == "darwin":
        path = Path.home() / "Library/LaunchAgents" / (label + ".plist")
        path.parent.mkdir(parents=True, exist_ok=True)
        definition = {"Label": label, "ProgramArguments": command, "WorkingDirectory": str(code),
                      "EnvironmentVariables": {"PATH": path_env, "HOME": str(Path.home())},
                      "RunAtLoad": True, "StartInterval": 300, "ProcessType": "Background",
                      "Nice": 10, "LowPriorityIO": True,
                      "StandardOutPath": str(state / "timer.log"), "StandardErrorPath": str(state / "timer-error.log")}
        if path.exists():
            run(["launchctl", "bootout", f"gui/{os.getuid()}/{label}"], cwd=state,
                log=state / "unload.log", timeout=15)
        path.write_bytes(plistlib.dumps(definition))
        run(["launchctl", "bootstrap", f"gui/{os.getuid()}", str(path)], cwd=state,
            log=state / "install.log", timeout=15)
        run(["launchctl", "print", f"gui/{os.getuid()}/{label}"], cwd=state,
            log=state / "health.log", timeout=15)
    else:
        folder = Path.home() / ".config/systemd/user"
        folder.mkdir(parents=True, exist_ok=True)
        name = "tessera-ci-" + args.lane
        # systemd escaping, rather than shell quoting. No command passes a shell.
        quote = lambda text: '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("%", "%%") + '"'
        (folder / (name + ".service")).write_text(
            "[Unit]\nDescription=Tessera external CI\n[Service]\nType=oneshot\n"
            + "WorkingDirectory=" + str(code).replace("%", "%%") + "\nExecStart=" + " ".join(quote(item) for item in command)
            + "\nTimeoutStartSec=3930\nKillMode=control-group\nNice=10\nUMask=0077\n"
            + 'Environment="PATH=' + path_env + '"\n')
        (folder / (name + ".timer")).write_text(
            "[Unit]\nDescription=Tessera CI every five minutes\n[Timer]\nOnBootSec=1min\n"
            + "OnUnitInactiveSec=5min\nUnit=" + name + ".service\n[Install]\nWantedBy=timers.target\n")
        run(["systemctl", "--user", "daemon-reload"], cwd=state, log=state / "reload.log", timeout=15)
        run(["systemctl", "--user", "enable", "--now", name + ".timer"], cwd=state, log=state / "install.log", timeout=15)
        run(["systemctl", "--user", "is-active", name + ".timer"], cwd=state, log=state / "health.log", timeout=15)
    print("Installed " + label + " with reviewed policy " + policy_hash(source))


if __name__ == "__main__":
    main()
