"""Build private release artifacts; publish only with --publish and fresh CI proof."""

import argparse
import base64
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import plistlib
import re
import shutil
import signal
import stat
import sys
import tarfile
import tempfile
import time
import xml.etree.ElementTree as ET

from .common import REPOSITORY, build_environment, policy_hash, run, write_json
from .verify_release import check, check_reports
from tools.validate_release import validate

CERTIFICATE = "da4569aa63dee7587d670dc4c685f128faacf4e5"
BUNDLE = "com.abdwy.Tessera"
SPARKLE = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
CLI_VERSION = "0.19.0"


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def release_identity(info):
    version, build = info["CFBundleShortVersionString"], info["CFBundleVersion"]
    validate(version, build, "v" + version)
    if int(build) <= 11:
        raise ValueError("Build must supersede withdrawn build 11")
    key = base64.b64decode(info["SUPublicEDKey"], validate=True)
    if len(key) != 32 or not info.get("PostHogProjectToken", "").startswith("phc_"):
        raise ValueError("Missing source public configuration")
    return version, build


def validate_requirement(text):
    lines = re.findall(r'^designated => (.+)$', text, re.MULTILINE)
    match = re.fullmatch(r'identifier "' + re.escape(BUNDLE) + r'" and certificate root = H"([a-fA-F0-9]{40})"', lines[0]) if len(lines) == 1 else None
    if match is None or match[1].lower() != CERTIFICATE:
        raise ValueError("Designated requirement differs from stable 0.1.9 certificate and identifier")
    return lines[0]


def validate_smoke(text):
    matches = re.findall(r'scan finished: root=(\d+) error=none cancelled=false files=9 dirs 4/4 '
                         r'elapsed=([0-9.]+)s rate=\d+ dirs/s coverage=complete gaps=0(?:\s|$)', text)
    if len(matches) != 1 or text.count("scan finished:") != 1:
        raise ValueError("Signed app did not complete the nine-file pipeline with full coverage")
    elapsed = float(matches[0][1])
    if not math.isfinite(elapsed) or not 0 < elapsed <= 120 or int(matches[0][0]) <= 0:
        raise ValueError("Smoke timing or root size is invalid")
    if "cleanup: safe=" not in text or "cleanup: no report" in text or "collector: 0 items," not in text:
        raise ValueError("Signed app did not publish cleanup classification")
    return {"files": 9, "directories": 4, "coverage": "complete", "gaps": 0,
            "elapsedSeconds": elapsed, "exit": 0, "cleanupPublished": True}


def appcast_metadata(path, dmg, version, build, public_key):
    # DTDs and external entities have no place in this generated public feed.
    raw = Path(path).read_bytes()
    if b"<!DOCTYPE" in raw or b"<!ENTITY" in raw:
        raise ValueError("Appcast contains a DTD or entity")
    root = ET.fromstring(raw)
    items = root.findall("./channel/item")
    enclosures = list(root.iter("enclosure"))
    if root.tag != "rss" or len(items) != 1 or len(enclosures) != 1:
        raise ValueError("Appcast must contain exactly one item and enclosure")
    item, enclosure = items[0], enclosures[0]
    if item.find("enclosure") is not enclosure:
        raise ValueError("Appcast enclosure is misplaced")
    for name, expected in (("version", build), ("shortVersionString", version)):
        values = [node.text for node in item.findall(SPARKLE + name)]
        if not values:
            values = [enclosure.get(SPARKLE + name)]
        if values != [expected] or enclosure.get(SPARKLE + name, expected) != expected:
            raise ValueError("Appcast " + name + " does not match source")
    url = f"https://github.com/{REPOSITORY}/releases/download/v{version}/Tessera-{version}.dmg"
    if enclosure.get("url") != url or enclosure.get("length") != str(dmg.stat().st_size):
        raise ValueError("Appcast URL or byte length does not match archive")
    signature = enclosure.get(SPARKLE + "edSignature", "")
    if len(base64.b64decode(signature, validate=True)) != 64 or len(base64.b64decode(public_key, validate=True)) != 32:
        raise ValueError("Invalid Ed25519 signature or public key")
    return {"url": url, "length": dmg.stat().st_size, "signature": signature, "publicKey": public_key}


def validate_tag(ref, tag, revision):
    if ref is None:
        return
    if ref.get("object", {}).get("type") != "tag" or tag is None:
        raise ValueError("Existing release tag is not annotated")
    if tag.get("object", {}).get("type") != "commit" or tag["object"].get("sha") != revision:
        raise ValueError("Existing tag does not pin the exact source commit")


def tree_hash(root):
    digest = hashlib.sha256()
    for path in sorted(root.rglob("*")):
        name = str(path.relative_to(root)).encode()
        if path.is_symlink():
            payload = b"link\0" + os.readlink(path).encode()
        elif path.is_file():
            payload = b"file\0" + str(path.stat().st_mode & 0o777).encode() + b"\0" + sha256(path).encode()
        else:
            payload = b"directory"
        digest.update(name + b"\0" + payload + b"\0")
    return digest.hexdigest()


def verify_archive(source, manifest):
    """Compare the exact archive inventory with Git's raw recursive tree."""
    entries, directories = {}, set()
    records = manifest.split(b"\0")
    if records[-1] != b"":
        raise ValueError("Git tree manifest is not NUL terminated")
    for record in records[:-1]:
        metadata, name = record.split(b"\t", 1)
        mode, kind, blob = metadata.split(b" ")
        parts = name.split(b"/")
        if (not name or any(part in (b"", b".", b"..") or part.lower() == b".git" for part in parts)
                or name in entries or not re.fullmatch(b"[a-f0-9]{40}", blob)):
            raise ValueError("Unsafe or duplicate path in Git tree manifest")
        if kind != b"blob" or mode not in (b"100644", b"100755", b"120000"):
            raise ValueError("Archive contains a submodule or unsupported Git mode")
        entries[name] = (mode, blob)
        directories.update(b"/".join(parts[:index]) for index in range(1, len(parts)))
    if directories.intersection(entries):
        raise ValueError("Git tree contains a file/directory collision")
    seen = set()
    pending = [(source, b"")]
    while pending:
        folder, prefix = pending.pop()
        with os.scandir(folder) as children:
            for child in children:
                name = prefix + os.fsencode(child.name)
                metadata = child.stat(follow_symlinks=False)
                if stat.S_ISDIR(metadata.st_mode):
                    if name not in directories:
                        raise ValueError("Archive contains an extra directory")
                    seen.add(name)
                    pending.append((Path(child.path), name + b"/"))
                    continue
                if name not in entries:
                    raise ValueError("Archive contains an extra file or symlink")
                mode, expected_blob = entries[name]
                if mode == b"120000":
                    if not stat.S_ISLNK(metadata.st_mode):
                        raise ValueError("Archive symlink type differs from Git")
                    payload = os.fsencode(os.readlink(child.path))
                    # A tracked link may stay inside the archive, never escape it.
                    target = Path(child.path).parent / os.fsdecode(payload)
                    if os.path.isabs(payload) or not target.resolve().is_relative_to(source.resolve()):
                        raise ValueError("Archive symlink escapes the source tree")
                    actual_blob = hashlib.sha1(b"blob " + str(len(payload)).encode() + b"\0" + payload).hexdigest()
                else:
                    executable = metadata.st_mode & 0o111
                    if not stat.S_ISREG(metadata.st_mode) or executable != (0o111 if mode == b"100755" else 0):
                        raise ValueError("Archive file type or executable mode differs from Git")
                    digest = hashlib.sha1(b"blob " + str(metadata.st_size).encode() + b"\0")
                    descriptor = os.open(child.path, os.O_RDONLY | os.O_NOFOLLOW)
                    with os.fdopen(descriptor, "rb") as stream:
                        opened = os.fstat(stream.fileno())
                        if (opened.st_ino, opened.st_dev, opened.st_size) != (metadata.st_ino, metadata.st_dev, metadata.st_size):
                            raise ValueError("Archive file changed during verification")
                        for block in iter(lambda: stream.read(1024 * 1024), b""):
                            digest.update(block)
                    actual_blob = digest.hexdigest()
                if actual_blob.encode() != expected_blob:
                    raise ValueError("Archive Git blob hash differs from pinned commit")
                seen.add(name)
    if seen != set(entries) | directories:
        raise ValueError("Archive is missing a tracked file or directory")
    return {"manifestSHA256": hashlib.sha256(manifest).hexdigest(), "files": len(entries),
            "directories": len(directories), "symlinks": sum(mode == b"120000" for mode, _ in entries.values()),
            "executables": sum(mode == b"100755" for mode, _ in entries.values()), "blobHash": "git-sha1"}


class Release:
    def __init__(self, source, output, key, *, git_dir=None, revision=None):
        self.source, self.output, self.key = source, output, key
        if (git_dir is None) != (revision is None):
            raise ValueError("--git-dir and --revision must be supplied together")
        self.git_dir, self.revision = git_dir, revision
        self.source_proof = None
        self.env = build_environment("release")
        self.env["PYTHONDONTWRITEBYTECODE"] = "1"
        self.index = 0
        (self.output / "logs").mkdir(exist_ok=True)
        self.logs = Path(tempfile.mkdtemp(prefix="run-", dir=self.output / "logs"))

    def command(self, name, command, timeout=60, *, cwd=None, env=None, data=None):
        self.index += 1
        return run([str(arg) for arg in command], cwd=cwd or self.source,
                   log=self.logs / f"{self.index:03}-{name}.log", timeout=timeout,
                   env=self.env if env is None else env, data=data)

    def api(self, endpoint, *, method=None, body=None, missing=False):
        command = ["gh", "api", endpoint]
        if method:
            command += ["--method", method]
        if body is not None:
            command += ["--input", "-"]
        try:
            result = self.command("github", command, 60, env=dict(os.environ),
                                  data=json.dumps(body).encode() if body is not None else None)
        except RuntimeError:
            log = self.logs / f"{self.index:03}-github.log"
            if missing and "HTTP 404" in log.read_text():
                return None
            raise
        return json.loads(result)

    def archive_pin(self):
        if not re.fullmatch(r"[a-f0-9]{40}", self.revision):
            raise ValueError("Archive mode requires a full lowercase 40-character commit SHA")
        if (not self.git_dir.is_dir() or self.git_dir.stat().st_uid != os.getuid()):
            raise ValueError("Archive object source must be an owned bare repository")
        git = ["git", "--no-replace-objects", "--git-dir", self.git_dir]
        if self.command("bare-repository", [*git, "rev-parse", "--is-bare-repository"], 10).strip() != "true":
            raise ValueError("Archive object source is not a bare repository")
        if self.command("commit-type", [*git, "cat-file", "-t", self.revision], 10).strip() != "commit":
            raise ValueError("Archive revision must name a commit object")
        resolved = self.command("commit-resolve", [*git, "rev-parse", "--verify", self.revision + "^{commit}"], 10).strip()
        if resolved != self.revision:
            raise ValueError("Archive revision does not resolve to the exact pinned commit")
        self.command("archive-tree", [*git, "ls-tree", "-rz", "--full-tree", self.revision], 30)
        manifest = (self.logs / f"{self.index:03}-archive-tree.log").read_bytes()
        return {"mode": "archive", "revision": self.revision, **verify_archive(self.source, manifest)}

    def gate(self, expected=None):
        logs = self.logs / f"gate-{self.index}"
        logs.mkdir(parents=True)
        if self.git_dir is None:
            revision = check(self.source, self.key, logs)
            self.source_proof = {"mode": "worktree", "revision": revision}
        else:
            self.source_proof = self.archive_pin()
            write_json(self.output / "source-archive-proof.json", self.source_proof)
            revision = check_reports(self.revision, policy_hash(self.source), self.key, logs, self.source)
        if expected is not None and revision != expected:
            raise ValueError("Source commit changed during release")
        self.index += 1
        return revision

    def remote_state(self, version, build, revision):
        base = f"repos/{REPOSITORY}"
        ref = self.api(base + f"/git/ref/tags/v{version}", missing=True)
        tag = self.api(base + "/git/tags/" + ref["object"]["sha"]) if ref and ref["object"]["type"] == "tag" else None
        validate_tag(ref, tag, revision)
        if ref and (ref.get("ref") != "refs/tags/v" + version or tag.get("tag") != "v" + version):
            raise ValueError("Annotated tag name differs from the release version")
        existing = self.api(base + f"/releases/tags/v{version}", missing=True)
        if existing and (not existing["draft"] or existing["tag_name"] != "v" + version
                         or existing.get("target_commitish") != revision):
            raise ValueError("Release exists and is public or does not pin this exact draft commit")
        latest = self.api(base + "/releases/latest", missing=True)
        if latest:
            remote = self.api(base + "/contents/Tessera/Info.plist?ref=" + latest["tag_name"])
            info = plistlib.loads(base64.b64decode(remote["content"]))
            if int(build) <= int(info["CFBundleVersion"]):
                raise ValueError("Build does not advance the latest published build")
            old = info["CFBundleShortVersionString"]
            if old.startswith("0.") and tuple(map(int, version.split("."))) <= tuple(map(int, old.split("."))):
                raise ValueError("Version does not advance the latest stable version")
        return ref, existing

    def verify_app(self, app, source_info):
        with (app / "Contents/Info.plist").open("rb") as stream:
            built = plistlib.load(stream)
        for name in ("CFBundleShortVersionString", "CFBundleVersion", "SUPublicEDKey", "PostHogProjectToken", "PostHogHost", "SUFeedURL"):
            if built.get(name) != source_info[name]:
                raise ValueError("Processed app configuration differs: " + name)
        if built["CFBundleIdentifier"] != BUNDLE:
            raise ValueError("Wrong release bundle identifier")
        self.command("signature-strict", ["codesign", "--verify", "--deep", "--strict", "--verbose=2", app])
        details = self.command("signature-details", ["codesign", "-dvv", app])
        if re.search(r'^Identifier=' + re.escape(BUNDLE) + r'$', details, re.MULTILINE) is None or "runtime" in details:
            raise ValueError("App identifier or hardened runtime differs from stable signing policy")
        requirement = validate_requirement(self.command("requirement", ["codesign", "-d", "-r-", app]))
        framework = app / "Contents/Frameworks/Sparkle.framework"
        nested = self.command("sparkle-identifier", ["codesign", "-dvv", framework])
        if "Identifier=org.sparkle-project.Sparkle\n" not in nested or "runtime" in nested:
            raise ValueError("Sparkle lost its own signing identifier or gained hardened runtime")
        resources = app / "Contents/Resources"
        for path in resources.rglob("*"):
            if not path.is_file():
                continue
            if path.suffix.lower() in {".p12", ".pfx", ".key", ".pem", ".env"}:
                raise ValueError("Private-key-like resource in release bundle")
            # Scan in chunks so a large asset cannot exhaust release memory.
            with path.open("rb") as stream:
                tail = b""
                for block in iter(lambda: stream.read(1024 * 1024), b""):
                    data = tail + block
                    if re.search(rb'-----BEGIN [A-Z ]*PRIVATE KEY-----|SPARKLE_PRIVATE_KEY|POSTHOG_API_KEY', data):
                        raise ValueError("Private credential resource in release bundle")
                    tail = data[-128:]
        return requirement

    def preferences(self):
        # Read the live production CFPreferences domain, plus its on-disk forms.
        text = self.command("production-preferences", ["defaults", "read", BUNDLE]) if self.preference_exists() else "absent"
        root = Path.home() / "Library/Preferences"
        paths = [root / (BUNDLE + ".plist")]
        paths += sorted((root / "ByHost").glob(BUNDLE + ".*.plist"))
        return {"domain": hashlib.sha256(text.encode()).hexdigest(),
                "files": {str(p.relative_to(root)): sha256(p) if p.exists() else None for p in paths}}

    def preference_exists(self):
        domains = self.command("preference-domains", ["defaults", "domains"])
        return BUNDLE in [name.strip() for name in domains.split(",")]

    def smoke(self, app):
        fixture = self.output / "smoke-fixture"
        home = self.output / "smoke-home"
        fixture.mkdir()
        home.mkdir()
        for directory in range(3):
            folder = fixture / str(directory)
            folder.mkdir()
            for number in range(3):
                (folder / f"file-{number}.dat").write_bytes(b"tessera-owned-release-smoke\n" * (number + 1))
        before = tree_hash(fixture)
        preferences = self.preferences()
        write_json(self.output / "production-preferences-before.json", preferences)
        try:
            text = self.command("signed-smoke", [app / "Contents/MacOS/Tessera"], 120,
                                env=self.env | {"HOME": str(home), "CFFIXED_USER_HOME": str(home),
                                                "SO_CI": "1", "SO_AUTOSCAN": str(fixture),
                                                "SO_AUTOQUIT": "1", "SO_PRIVATE_SUMMARY": "1"})
        finally:
            after = self.preferences()
            write_json(self.output / "production-preferences-after.json", after)
            if after != preferences:
                raise ValueError("Production preferences changed during smoke; stop for review, do not restore")
            if before != tree_hash(fixture):
                raise ValueError("Smoke changed its fixture")
        result = validate_smoke(text)
        (self.output / "signed-smoke.log").write_text(text)
        return result | {"fixtureSHA256": before, "fixtureUnchanged": True,
                         "productionPreferencesUnchanged": True,
                         "homeIsolation": "HOME+CFFIXED_USER_HOME; isolation not independently proved"}

    def signature(self, updates, version, build, info):
        dmg = updates / f"Tessera-{version}.dmg"
        metadata = appcast_metadata(updates / "appcast.xml", dmg, version, build, info["SUPublicEDKey"])
        self.command("ed25519", ["xcrun", "swift", self.source / "tools/verify_update.swift", dmg,
                                 metadata["publicKey"], metadata["signature"]], 120)
        return metadata | {"verified": True, "verifier": "CryptoKit.Curve25519.Signing"}

    def symbols(self, products, cli):
        package = cli.parent.parent / "@posthog/cli/package.json"
        if not cli.is_file() or not package.is_file() or json.loads(package.read_text())["version"] != CLI_VERSION:
            raise ValueError("--posthog-cli must point to an installed @posthog/cli@0.19.0 node_modules/.bin/posthog-cli")
        self.command("posthog-version", [cli, "--version"], 30)
        uuids = []
        for name in (products / "Tessera.app/Contents/MacOS/Tessera", products / "Tessera.app.dSYM"):
            text = self.command("symbol-uuids", ["dwarfdump", "--uuid", name], 30)
            ids = sorted(re.findall(r'UUID: ([0-9A-Fa-f-]{36})', text))
            if not ids:
                raise ValueError("Missing native symbol UUID")
            uuids.append(ids)
        if uuids[0] != uuids[1]:
            raise ValueError("Binary and dSYM UUIDs differ")
        vault = Path.home() / ".local/bin/agent-access"
        self.command("posthog-symbols", [vault, "run", "--timeout", "210", "posthog-tessera", "--",
                     sys.executable, "-B", "-c", "import os,runpy,sys; "
                     "sink=os.open(os.devnull,os.O_WRONLY); os.dup2(sink,1); os.dup2(sink,2); "
                     "sys.path.insert(0,os.path.dirname(sys.argv[1])); sys.argv=sys.argv[1:]; "
                     "runpy.run_path(sys.argv[0],run_name='__main__')",
                     self.source / "tools/upload_posthog_symbols.py", "--products", products, "--cli", cli], 240)
        return {"uploaded": True, "output": "suppressed to keep vault credentials out of logs", "cliVersion": CLI_VERSION, "project": "340688",
                "endpoint": "https://eu.posthog.com", "uuids": uuids[0]}

    def build(self, revision, info, cache, cli):
        version, build = release_identity(info)
        snapshot = self.output / "source"
        snapshot.mkdir()
        archive = self.output / "source.tar"
        git = ["git", "--no-replace-objects", "--git-dir", self.git_dir] if self.git_dir is not None else ["git"]
        self.command("source-archive", [*git, "archive", "--format=tar", "--output", archive, revision])
        with tarfile.open(archive) as stream:
            stream.extractall(snapshot, filter="data")
        self.command("xcodegen", ["xcodegen", "generate"], 120, cwd=snapshot)
        derived = self.output / "DerivedData"
        packages = cache or (self.output / "SourcePackages")
        if packages.is_relative_to(self.source):
            raise ValueError("SPM cache must be outside the source checkout")
        args = ["-project", snapshot / "Tessera.xcodeproj", "-scheme", "Tessera", "-derivedDataPath", derived,
                "-clonedSourcePackagesDirPath", packages]
        self.command("resolve", ["xcodebuild", "-resolvePackageDependencies", *args], 300, cwd=snapshot)
        self.command("release-build", ["xcodebuild", "build", *args, "-configuration", "Release", "-destination", "platform=macOS",
                     "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO", "ENABLE_HARDENED_RUNTIME=NO"], 900, cwd=snapshot)
        products = derived / "Build/Products/Release"
        app = products / "Tessera.app"
        self.command("stable-sign", ["codesign", "--force", "--deep", "--sign", CERTIFICATE, "--entitlements",
                                    snapshot / "Tessera/Tessera.entitlements", app], 120)
        requirement = self.verify_app(app, info)
        smoke = self.smoke(app)
        symbols = self.symbols(products, cli)
        updates, stage = self.output / "updates", self.output / "dmg-stage"
        updates.mkdir()
        stage.mkdir()
        self.command("dmg-copy", ["ditto", app, stage / "Tessera.app"], 120)
        (stage / "Applications").symlink_to("/Applications")
        dmg = updates / f"Tessera-{version}.dmg"
        self.command("dmg-create", ["hdiutil", "create", "-volname", "Tessera", "-srcfolder", stage, "-format", "UDZO", dmg], 180)
        self.command("dmg-verify", ["hdiutil", "verify", dmg], 120)
        candidates = set()
        for artifacts in (packages / "artifacts", derived / "SourcePackages/artifacts"):
            if artifacts.is_dir():
                candidates.update(p.resolve() for p in artifacts.glob("**/Sparkle/bin/generate_appcast") if p.is_file())
        if len(candidates) != 1:
            raise ValueError("Expected one generate_appcast in the resolved SPM artifact cache")
        generator_home = self.output / "generator-home"
        (generator_home / "Library/Caches").mkdir(parents=True)
        # The real HOME keeps the login keychain in the search list for the ed25519 key.
        generator_env = self.env | {"CFFIXED_USER_HOME": str(generator_home)}
        cache_path = self.command("generator-cache", ["xcrun", "swift", "-e",
            'import Foundation; print(FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].path)'],
            120, env=generator_env).strip()
        if not Path(cache_path).resolve().is_relative_to(generator_home.resolve()):
            raise ValueError("Sparkle Foundation cache did not resolve inside its private output home")
        self.command("appcast", [candidates.pop(), "--account", "ed25519", "--maximum-deltas", "0", "--download-url-prefix",
                     f"https://github.com/{REPOSITORY}/releases/download/v{version}/", updates], 180,
                     env=generator_env)
        signature = self.signature(updates, version, build, info)
        shutil.copyfile(dmg, updates / "Tessera.dmg")
        names = ["Tessera.dmg", f"Tessera-{version}.dmg", "appcast.xml"]
        hashes = {name: sha256(updates / name) for name in names}
        (updates / "SHA256SUMS").write_text("".join(f"{value}  {name}\n" for name, value in hashes.items()))
        hashes["SHA256SUMS"] = sha256(updates / "SHA256SUMS")
        reports = {}
        for lane in ("native", "web"):
            report = json.loads(next(self.logs.glob(f"gate-*/{lane}.log")).read_text())
            envelope = json.loads(base64.b64decode(report["content"]))
            reports[lane] = {"envelopeSHA256": hashlib.sha256(json.dumps(envelope, sort_keys=True).encode()).hexdigest(),
                             "finishedAt": envelope["report"]["finishedAt"], "result": "success"}
        proof = {"schema": 1, "revision": revision, "version": version, "build": build, "tag": "v" + version,
                 "source": self.source_proof,
                 "recipe": policy_hash(self.source), "certificateSHA1": CERTIFICATE, "requirement": requirement,
                 "appTreeSHA256": tree_hash(app), "dmgStageTreeSHA256": tree_hash(stage),
                 "symbols": symbols, "smoke": smoke, "sparkle": signature, "assets": hashes, "ci": reports,
                 "createdAt": time.time(), "notarized": False,
                 "smokeLogSHA256": sha256(self.output / "signed-smoke.log")}
        write_json(self.output / "release-proof.json", proof)
        self.gate(revision)
        return proof

    def verify_artifacts(self, proof, info):
        version, build = release_identity(info)
        if (proof["version"], proof["build"], proof["certificateSHA1"], proof["recipe"]) != (version, build, CERTIFICATE, policy_hash(self.source)):
            raise ValueError("Artifact proof differs from source release policy")
        if proof.get("source") != self.source_proof:
            raise ValueError("Artifact source proof differs from the current source mode or archive")
        updates = self.output / "updates"
        expected = {"Tessera.dmg", f"Tessera-{version}.dmg", "appcast.xml", "SHA256SUMS"}
        if set(proof["assets"]) != expected or {p.name for p in updates.iterdir() if p.is_file()} != expected:
            raise ValueError("Release asset inventory differs")
        extras = [p for p in updates.iterdir() if p.name not in expected]
        if any(p.is_symlink() or p.name != "old_updates" or not p.is_dir() or any(p.iterdir()) for p in extras):
            raise ValueError("Unexpected appcast output outside public asset inventory")
        for name, digest in proof["assets"].items():
            if (updates / name).is_symlink() or sha256(updates / name) != digest:
                raise ValueError("Release artifact bytes changed: " + name)
        if proof["assets"]["Tessera.dmg"] != proof["assets"][f"Tessera-{version}.dmg"]:
            raise ValueError("Download aliases differ")
        checksums = "".join(f"{proof['assets'][name]}  {name}\n" for name in ("Tessera.dmg", f"Tessera-{version}.dmg", "appcast.xml"))
        if (updates / "SHA256SUMS").read_text() != checksums:
            raise ValueError("SHA256SUMS does not match archive and appcast")
        app = self.output / "DerivedData/Build/Products/Release/Tessera.app"
        if tree_hash(app) != proof["appTreeSHA256"] or tree_hash(self.output / "dmg-stage") != proof["dmgStageTreeSHA256"]:
            raise ValueError("Signed app or image staging changed")
        self.verify_app(app, info)
        self.command("dmg-reverify", ["hdiutil", "verify", updates / f"Tessera-{version}.dmg"], 120)
        if self.signature(updates, version, build, info) != proof["sparkle"]:
            raise ValueError("Sparkle signature proof differs")
        if proof["symbols"].get("uploaded") is not True or proof["symbols"].get("cliVersion") != CLI_VERSION:
            raise ValueError("No successful pinned native symbol upload proof")
        if proof["smoke"].get("productionPreferencesUnchanged") is not True or proof["smoke"].get("fixtureUnchanged") is not True:
            raise ValueError("No successful isolated smoke proof")
        if sha256(self.output / "signed-smoke.log") != proof["smokeLogSHA256"]:
            raise ValueError("Smoke evidence changed")
        validate_smoke((self.output / "signed-smoke.log").read_text())

    def publish(self, proof, info):
        revision, version, build = proof["revision"], proof["version"], proof["build"]
        self.gate(revision)
        self.verify_artifacts(proof, info)
        ref, existing = self.remote_state(version, build, revision)
        base = f"repos/{REPOSITORY}"
        if ref is None:
            tag = self.api(base + "/git/tags", method="POST", body={"tag": "v" + version,
                           "message": f"Tessera {version}, build {build}", "object": revision, "type": "commit"})
            self.api(base + "/git/refs", method="POST", body={"ref": "refs/tags/v" + version, "sha": tag["sha"]})
        if existing is None:
            existing = self.api(base + "/releases", method="POST", body={"tag_name": "v" + version,
                "target_commitish": revision, "name": "Tessera " + version, "draft": True, "prerelease": False,
                "body": "Stable-certificate build. This release is not notarized. See RELEASING.md for installation limits."})
        # An interrupted partial upload needs manual review. Never overwrite or delete assets.
        if existing["assets"] and {asset["name"] for asset in existing["assets"]} != set(proof["assets"]):
            raise ValueError("Existing draft has a partial or unexpected asset set; parent review required")
        if not existing["assets"]:
            self.command("draft-upload", ["gh", "release", "upload", "v" + version, "--repo", REPOSITORY,
                         *[self.output / "updates" / name for name in proof["assets"]]], 300, env=dict(os.environ))
        existing = self.api(base + "/releases/" + str(existing["id"]))
        names = [asset["name"] for asset in existing["assets"]]
        if len(names) != 4 or set(names) != set(proof["assets"]) or not existing["draft"]:
            raise ValueError("Draft asset set or release state changed")
        downloads = Path(tempfile.mkdtemp(prefix="remote-verification-", dir=self.output))
        for asset in existing["assets"]:
            name = asset["name"]
            if asset["size"] != (self.output / "updates" / name).stat().st_size:
                raise ValueError("Remote asset size differs")
            self.command("remote-bytes", ["gh", "api", "-H", "Accept: application/octet-stream", base + "/releases/assets/" + str(asset["id"])], 180, env=dict(os.environ))
            shutil.copyfile(self.logs / f"{self.index:03}-remote-bytes.log", downloads / name)
            if sha256(downloads / name) != proof["assets"][name]:
                raise ValueError("Remote asset bytes differ")
        self.gate(revision)
        _, final_draft = self.remote_state(version, build, revision)
        asset_identity = lambda assets: sorted((a["id"], a["name"], a["size"], a.get("digest")) for a in assets)
        if (final_draft is None or final_draft["id"] != existing["id"]
                or asset_identity(final_draft["assets"]) != asset_identity(existing["assets"])):
            raise ValueError("Draft assets changed after byte verification")
        # Recheck local bytes after network work before the public transition.
        for name, digest in proof["assets"].items():
            if sha256(self.output / "updates" / name) != digest:
                raise ValueError("Local assets changed during upload")
        self.api(base + "/releases/" + str(existing["id"]), method="PATCH", body={"draft": False, "make_latest": "true"})
        write_json(self.output / "publication.json", {"revision": revision, "tag": "v" + version, "assetsVerified": True})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--publish", action="store_true")
    parser.add_argument("--git-dir", type=Path, help="Owned bare object repository for exact archive mode")
    parser.add_argument("--revision", help="Full lowercase 40-character commit SHA for archive mode")
    parser.add_argument("--artifacts", type=Path, help="Reuse a complete private output for explicit publication")
    parser.add_argument("--posthog-cli", type=Path)
    parser.add_argument("--spm-cache", type=Path)
    parser.add_argument("--key", type=Path, default=Path(os.environ.get("TESSERA_CI_KEY_FILE", str(Path.home() / ".local/share/tessera-ci/attestation.key"))))
    args = parser.parse_args()
    if (args.git_dir is None) != (args.revision is None):
        parser.error("--git-dir and --revision must be supplied together")
    if args.revision is not None and not re.fullmatch(r"[a-f0-9]{40}", args.revision):
        parser.error("--revision must be a full lowercase 40-character commit SHA")
    if platform.system() != "Darwin":
        parser.error("Release build and publication require the existing macOS toolchain")
    if args.artifacts and not args.publish:
        parser.error("--artifacts requires explicit --publish")
    if not args.artifacts and not args.posthog_cli:
        parser.error("A pinned --posthog-cli is required for the mandatory real symbol upload")
    source = Path(__file__).resolve().parent.parent
    os.umask(0o077)
    output = (args.artifacts or Path(tempfile.mkdtemp(prefix="tessera-release-", dir="/tmp"))).resolve()
    if output.is_relative_to(source) or output.is_symlink() or output.stat().st_uid != os.getuid() or output.stat().st_mode & 0o077:
        parser.error("Output must be an owned private directory outside the checkout")
    print("Private release output: " + str(output), flush=True)
    job = Release(source, output, args.key.read_bytes(),
                  git_dir=args.git_dir.resolve() if args.git_dir else None, revision=args.revision)
    # External qualification is the first gate, before signing, symbols or builds.
    revision = job.gate()
    with (source / "Tessera/Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    version, build = release_identity(info)
    job.remote_state(version, build, revision)
    if args.artifacts:
        proof = json.loads((output / "release-proof.json").read_text())
        if proof["revision"] != revision:
            raise ValueError("Artifacts belong to another source commit")
    else:
        proof = job.build(revision, info, args.spm_cache.resolve() if args.spm_cache else None, args.posthog_cli.absolute())
    if args.publish:
        job.publish(proof, info)
        print("Published v" + version + " after remote byte verification")
    else:
        print("Artifacts built. No GitHub release or tag was created. Review release-proof.json before --publish --artifacts.")


if __name__ == "__main__":
    def interrupted(signum, _frame):
        # Unwind ci.common.run so its owned external process group is stopped.
        raise SystemExit(128 + signum)

    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    try:
        main()
    except (ValueError, RuntimeError, OSError, KeyError) as error:
        # Command errors name their private log, without copying raw tool output.
        print("Release stopped: " + str(error), file=sys.stderr)
        raise SystemExit(1)
