"""Package failure controls. These mocks do not prove signing or a real upload."""

import base64
import hashlib
import json
import os
from pathlib import Path
import plistlib
import tempfile
import tarfile
import unittest
from unittest.mock import patch

from ci.release import (BUNDLE, CERTIFICATE, Release, appcast_metadata, release_identity,
                        validate_requirement, validate_smoke, validate_tag, verify_archive, tree_hash)


class ReleasePackageTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.dmg = self.root / "Tessera-0.2.0.dmg"
        self.dmg.write_bytes(b"owned archive bytes")
        self.key = base64.b64encode(bytes(range(32))).decode()
        self.signature = base64.b64encode(bytes(range(64))).decode()
        self.xml = f'''<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item>
        <sparkle:version>12</sparkle:version><sparkle:shortVersionString>0.2.0</sparkle:shortVersionString>
        <enclosure url="https://github.com/unknown6003/tessera/releases/download/v0.2.0/Tessera-0.2.0.dmg"
        length="{self.dmg.stat().st_size}" sparkle:edSignature="{self.signature}"/></item></channel></rss>'''
        self.feed = self.root / "appcast.xml"
        self.feed.write_text(self.xml)
        self.smoke = ('scan finished: root=12288 error=none cancelled=false files=9 dirs 4/4 '
                      'elapsed=2.34s rate=1 dirs/s coverage=complete gaps=0\n'
                      'cleanup: safe=0 B in 0 groups, 0 review groups\ncollector: 0 items, 0 B\n')

    def metadata(self):
        return appcast_metadata(self.feed, self.dmg, "0.2.0", "12", self.key)

    def test_feed_ties_archive_identity_and_bytes(self):
        self.assertEqual(self.metadata()["length"], 19)
        for old, new in (("/v0.2.0/", "/v0.1.9/"), ("Tessera-0.2.0.dmg", "Tessera.dmg"),
                         ('length="19"', 'length="20"'), (">12<", ">11<"), (">0.2.0<", ">1.0.0<"),
                         (self.signature, "invalid"), ("</channel>", self.xml[self.xml.index("<item>"):self.xml.index("</item>")+7] + "</channel>")):
            with self.subTest(new=new):
                self.feed.write_text(self.xml.replace(old, new))
                with self.assertRaises(ValueError):
                    self.metadata()
        self.feed.write_text(self.xml)
        self.dmg.write_bytes(b"truncated")
        with self.assertRaises(ValueError):
            self.metadata()

    def test_missing_enclosure_and_dtd_are_rejected(self):
        for text in ('<rss><channel><item/></channel></rss>', '<!DOCTYPE rss []>' + self.xml):
            self.feed.write_text(text)
            with self.assertRaises(ValueError):
                self.metadata()

    def test_crypto_verification_failure_is_fatal(self):
        # Well-formed signature bytes alone never count as proof.
        updates = self.root / "updates"
        updates.mkdir()
        self.dmg.rename(updates / self.dmg.name)
        self.feed.rename(updates / "appcast.xml")
        release = Release(Path.cwd(), self.root, b"x" * 32)
        with patch.object(release, "command", side_effect=RuntimeError("ed25519: exit 1")):
            with self.assertRaises(RuntimeError):
                release.signature(updates, "0.2.0", "12", {"SUPublicEDKey": self.key})
        with patch.object(release, "command") as command:
            result = release.signature(updates, "0.2.0", "12", {"SUPublicEDKey": self.key})
            self.assertIn(self.key, command.call_args.args[1])
            self.assertTrue(result["verified"])
        with self.assertRaises(ValueError):
            release.signature(updates, "0.2.0", "12", {"SUPublicEDKey": base64.b64encode(b"bad").decode()})

    def test_release_series_and_withdrawn_build_are_not_bypassed(self):
        info = {"CFBundleShortVersionString": "0.2.0", "CFBundleVersion": "12", "SUPublicEDKey": self.key,
                "PostHogProjectToken": "phc_public"}
        self.assertEqual(release_identity(info), ("0.2.0", "12"))
        for key, value in (("CFBundleShortVersionString", "1.0.0"), ("CFBundleVersion", "11"),
                           ("CFBundleVersion", "0012"), ("SUPublicEDKey", ""), ("PostHogProjectToken", "")):
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                release_identity(info | {key: value})

    def test_only_stable_designated_requirement_is_accepted(self):
        dr = f'designated => identifier "{BUNDLE}" and certificate root = H"{CERTIFICATE}"\n'
        validate_requirement(dr)
        for bad in (dr.replace(CERTIFICATE, "a" * 40), dr.replace("root", "leaf"),
                    dr.replace(BUNDLE, "com.abdwy.other"), dr + dr,
                    'designated => cdhash H"' + "a" * 40 + '"\n', dr.rstrip() + " or true\n"):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                validate_requirement(bad)

    def test_zero_exit_without_full_pipeline_never_qualifies(self):
        self.assertEqual(validate_smoke(self.smoke)["files"], 9)
        for old, new in (("files=9", "files=8"), ("4/4", "3/4"), ("error=none", "error=denied"),
                         ("cancelled=false", "cancelled=true"), ("coverage=complete", "coverage=partial"),
                         ("gaps=0", "gaps=1"), ("elapsed=2.34", "elapsed=nan"), ("elapsed=2.34", "elapsed=121"),
                         ("cleanup: safe=", "cleanup: no report"), ("collector: 0 items", "collector: 1 items")):
            with self.subTest(new=new), self.assertRaises(ValueError):
                validate_smoke(self.smoke.replace(old, new))
        for text in ("", "exit=0", self.smoke + self.smoke):
            with self.assertRaises(ValueError):
                validate_smoke(text)

    def test_wrong_existing_tag_never_gets_replaced(self):
        ref = {"object": {"type": "tag", "sha": "b" * 40}}
        tag = {"object": {"type": "commit", "sha": "a" * 40}}
        validate_tag(ref, tag, "a" * 40)
        for other in ("b" * 40, "a" * 12):
            with self.assertRaises(ValueError):
                validate_tag(ref, tag, other)
        with self.assertRaises(ValueError):
            validate_tag({"object": {"type": "commit", "sha": "a" * 40}}, None, "a" * 40)

    def test_gate_failure_precedes_build_and_remote_publisher(self):
        from ci import release
        with patch.object(release.platform, "system", return_value="Darwin"), \
             patch.object(release.Path, "read_bytes", return_value=b"x" * 32), \
             patch.object(release.Release, "gate", side_effect=ValueError("CI missing")), \
             patch.object(release.Release, "remote_state") as remote, \
             patch.object(release.Release, "build") as build, \
             patch.object(release.Release, "publish") as publish, \
             patch.object(release.tempfile, "mkdtemp", side_effect=[str(self.root), str(self.root / "logs/run-test")]), \
             patch("sys.argv", ["release", "--posthog-cli", "/owned/cli", "--publish"]):
            with self.assertRaisesRegex(ValueError, "CI missing"):
                release.main()
        remote.assert_not_called()
        build.assert_not_called()
        publish.assert_not_called()

    def test_existing_public_release_and_wrong_draft_commit_stop(self):
        release = Release(Path.cwd(), self.root, b"x" * 32)
        for draft, commit in ((False, "a" * 40), (True, "b" * 40)):
            existing = {"draft": draft, "tag_name": "v0.2.0", "target_commitish": commit}
            with patch.object(release, "api", side_effect=[None, [existing]]) as api:
                with self.assertRaises(ValueError):
                    release.remote_state("0.2.0", "12", "a" * 40)
                self.assertFalse(any(call.kwargs.get("method") for call in api.call_args_list))

    def test_a_draft_is_found_through_the_release_list(self):
        release = Release(Path.cwd(), self.root, b"x" * 32)
        draft = {"id": 7, "draft": True, "tag_name": "v0.2.0", "target_commitish": "a" * 40, "assets": []}
        other = {"id": 8, "draft": False, "tag_name": "v0.1.9", "target_commitish": "c" * 40, "assets": []}
        with patch.object(release, "api", side_effect=[None, [other, draft], None]) as api:
            self.assertEqual(release.remote_state("0.2.0", "12", "a" * 40), (None, draft))
        self.assertNotIn("/releases/tags/", " ".join(str(c.args[0]) for c in api.call_args_list))

    def test_two_releases_with_one_tag_stop_for_review(self):
        release = Release(Path.cwd(), self.root, b"x" * 32)
        draft = {"id": 7, "draft": True, "tag_name": "v0.2.0", "target_commitish": "a" * 40, "assets": []}
        with patch.object(release, "api", side_effect=[None, [draft, draft | {"id": 9}]]):
            with self.assertRaisesRegex(ValueError, "More than one release"):
                release.remote_state("0.2.0", "12", "a" * 40)

    def test_missing_or_wrong_symbol_cli_stops_before_vault(self):
        release = Release(Path.cwd(), self.root, b"x" * 32)
        with patch.object(release, "command") as command:
            with self.assertRaises(ValueError):
                release.symbols(self.root, self.root / "missing-cli")
        command.assert_not_called()

    def test_resume_keeps_prior_run_evidence(self):
        first = Release(Path.cwd(), self.root, b"x" * 32)
        (first.logs / "prior.log").write_text("prior")
        second = Release(Path.cwd(), self.root, b"x" * 32)
        self.assertNotEqual(first.logs, second.logs)
        self.assertEqual((first.logs / "prior.log").read_text(), "prior")

    def test_smoke_aborts_on_production_pref_change_without_restoring(self):
        release = Release(Path.cwd(), self.root, b"x" * 32)
        with patch.object(release, "preferences", side_effect=[{"domain": "before"}, {"domain": "after"}]), \
             patch.object(release, "command", return_value=self.smoke):
            with self.assertRaisesRegex(ValueError, "Production preferences changed"):
                release.smoke(self.root / "Tessera.app")
        self.assertTrue((self.root / "production-preferences-after.json").exists())
        self.assertEqual(len(list((self.root / "smoke-fixture").rglob("*.dat"))), 9)

    def test_smoke_nonzero_exit_is_not_scan_success(self):
        release = Release(Path.cwd(), self.root, b"x" * 32)
        with patch.object(release, "preferences", return_value={"domain": "unchanged"}), \
             patch.object(release, "command", side_effect=RuntimeError("signed-smoke: exit 124")):
            with self.assertRaises(RuntimeError):
                release.smoke(self.root / "Tessera.app")
        self.assertFalse((self.root / "signed-smoke.log").exists())

    def draft(self, names):
        return {"id": 14, "draft": True, "tag_name": "v0.2.0", "target_commitish": "a" * 40,
                "assets": [{"id": index + 1, "name": name, "size": 1} for index, name in enumerate(names)]}

    def publication_proof(self):
        return {"revision": "a" * 40, "version": "0.2.0", "build": "12", "assets":
                {name: "bad" for name in ("Tessera.dmg", "Tessera-0.2.0.dmg", "appcast.xml", "SHA256SUMS")}}

    def test_partial_draft_requires_review_and_never_deletes_assets(self):
        release = Release(Path.cwd(), self.root, b"x" * 32)
        proof = self.publication_proof()
        with patch.object(release, "gate"), patch.object(release, "verify_artifacts"), \
             patch.object(release, "remote_state", return_value=({"tag": "exists"}, self.draft(["Tessera.dmg"]))), \
             patch.object(release, "api") as api, patch.object(release, "command") as command:
            with self.assertRaisesRegex(ValueError, "partial or unexpected"):
                release.publish(proof, {})
        api.assert_not_called()
        command.assert_not_called()

    def test_remote_size_failure_cannot_make_draft_public(self):
        release = Release(Path.cwd(), self.root, b"x" * 32)
        proof = self.publication_proof()
        updates = self.root / "updates"
        updates.mkdir()
        for name in proof["assets"]:
            (updates / name).write_bytes(b"different length")
        draft = self.draft(proof["assets"])
        with patch.object(release, "gate"), patch.object(release, "verify_artifacts"), \
             patch.object(release, "remote_state", return_value=({"tag": "exists"}, draft)), \
             patch.object(release, "api", return_value=draft) as api:
            with self.assertRaisesRegex(ValueError, "Remote asset size differs"):
                release.publish(proof, {})
        self.assertFalse(any(c.kwargs.get("method") for c in api.call_args_list))

    def test_latest_build_and_version_must_advance(self):
        release = Release(Path.cwd(), self.root, b"x" * 32)
        for version, build in (("0.1.9", "12"), ("0.2.0", "10")):
            old = plistlib.dumps({"CFBundleShortVersionString": version, "CFBundleVersion": build})
            with patch.object(release, "api", side_effect=[None, [], {"tag_name": "v" + version},
                              {"content": base64.b64encode(old).decode()}]):
                with self.assertRaises(ValueError):
                    release.remote_state("0.2.0", "12", "a" * 40)

    def test_remote_byte_failure_cannot_make_draft_public(self):
        release = Release(Path.cwd(), self.root, b"x" * 32)
        proof = self.publication_proof()
        updates = self.root / "updates"
        updates.mkdir()
        for name in proof["assets"]:
            (updates / name).write_bytes(b"x")
            proof["assets"][name] = hashlib.sha256(b"x").hexdigest()
        draft = self.draft(proof["assets"])

        def wrong_bytes(*args, **kwargs):
            release.index += 1
            (release.logs / f"{release.index:03}-remote-bytes.log").write_bytes(b"wrong")

        with patch.object(release, "gate"), patch.object(release, "verify_artifacts"), \
             patch.object(release, "remote_state", return_value=({"tag": "exists"}, draft)), \
             patch.object(release, "api", return_value=draft) as api, \
             patch.object(release, "command", side_effect=wrong_bytes):
            with self.assertRaisesRegex(ValueError, "Remote asset bytes differ"):
                release.publish(proof, {})
        self.assertFalse(any(c.kwargs.get("method") for c in api.call_args_list))

    def test_ci_must_still_pass_after_remote_downloads(self):
        release = Release(Path.cwd(), self.root, b"x" * 32)
        proof = self.publication_proof()
        updates = self.root / "updates"
        updates.mkdir()
        for name in proof["assets"]:
            (updates / name).write_bytes(b"x")
            proof["assets"][name] = hashlib.sha256(b"x").hexdigest()
        draft = self.draft(proof["assets"])

        def valid_bytes(*args, **kwargs):
            release.index += 1
            (release.logs / f"{release.index:03}-remote-bytes.log").write_bytes(b"x")

        with patch.object(release, "gate", side_effect=["a" * 40, ValueError("CI stale")]), \
             patch.object(release, "verify_artifacts"), \
             patch.object(release, "remote_state", return_value=({"tag": "exists"}, draft)), \
             patch.object(release, "api", return_value=draft) as api, \
             patch.object(release, "command", side_effect=valid_bytes):
            with self.assertRaisesRegex(ValueError, "CI stale"):
                release.publish(proof, {})
        self.assertFalse(any(c.kwargs.get("method") for c in api.call_args_list))


    def publish_with_final_digests(self, digest):
        release = Release(Path.cwd(), self.root, b"x" * 32)
        proof = self.publication_proof()
        updates = self.root / "updates"
        updates.mkdir()
        for name in proof["assets"]:
            (updates / name).write_bytes(b"x")
            proof["assets"][name] = hashlib.sha256(b"x").hexdigest()
        draft = self.draft(proof["assets"])
        final = self.draft(proof["assets"])
        for asset in final["assets"]:
            asset["digest"] = digest

        def valid_bytes(*args, **kwargs):
            release.index += 1
            (release.logs / f"{release.index:03}-remote-bytes.log").write_bytes(b"x")

        with patch.object(release, "gate", return_value="a" * 40), patch.object(release, "verify_artifacts"), \
             patch.object(release, "remote_state", side_effect=[({"tag": "exists"}, draft), ({"tag": "exists"}, final)]), \
             patch.object(release, "api", return_value=draft) as api, \
             patch.object(release, "command", side_effect=valid_bytes):
            release.publish(proof, {})
        return api

    def test_a_digest_filled_in_after_upload_still_publishes(self):
        api = self.publish_with_final_digests("sha256:" + hashlib.sha256(b"x").hexdigest())
        self.assertEqual([c.kwargs.get("method") for c in api.call_args_list if c.kwargs.get("method")], ["PATCH"])

    def test_a_wrong_remote_digest_cannot_make_draft_public(self):
        with self.assertRaisesRegex(ValueError, "Remote asset digest differs"):
            self.publish_with_final_digests("sha256:" + "0" * 64)

class ArchiveReleaseTests(unittest.TestCase):
    """Real Git objects and an archive, with no project checkout or worktree."""

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="tessera-archive-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source, self.output, self.bare = [self.root / name for name in ("source", "output", "objects.git")]
        self.source.mkdir()
        self.output.mkdir()
        self.release = Release(self.source, self.output, b"x" * 32)
        self.release.command("init-objects", ["git", "init", "--bare", self.bare], 10)
        imported = bytearray()
        files = [("ordinary.txt", b"owned contents\x00binary\n", "100644"),
                 ("release.sh", b"#!/bin/sh\nexit 0\n", "100755"),
                 ("link", b"ordinary.txt", "120000"),
                 ("nested/tab\tand\nnewline", b"raw Git filename", "100644")]
        for number, (_, payload, _) in enumerate(files, 1):
            imported.extend(f"blob\nmark :{number}\ndata {len(payload)}\n".encode() + payload + b"\n")
        imported.extend(b"commit refs/heads/fixture\nmark :10\ncommitter Synthetic <test@example.invalid> 1 +0000\ndata 7\nfixture\n")
        for number, (name, _, mode) in enumerate(files, 1):
            imported.extend(f"M {mode} :{number} {json.dumps(name)}\n".encode())
        imported.extend(b"\ncommit refs/heads/other\ncommitter Synthetic <test@example.invalid> 2 +0000\ndata 6\nsecond\nfrom :10\nM 100644 inline ordinary.txt\ndata 7\nchanged\n\ndone\n")
        self.release.command("import-objects", ["git", "--git-dir", self.bare, "fast-import", "--quiet"], 10, data=bytes(imported))
        self.revision = self.release.command("fixture-revision", ["git", "--git-dir", self.bare, "rev-parse", "refs/heads/fixture"], 10).strip()
        self.other = self.release.command("other-revision", ["git", "--git-dir", self.bare, "rev-parse", "refs/heads/other"], 10).strip()
        archive = self.root / "source.tar"
        self.release.command("fixture-archive", ["git", "--git-dir", self.bare, "archive", "--output", archive, self.revision], 10)
        with tarfile.open(archive) as stream:
            stream.extractall(self.source, filter="data")
        self.release.git_dir, self.release.revision = self.bare, self.revision

    def test_exact_archive_accepts_git_blobs_modes_and_raw_names_without_repo_writes(self):
        before = tree_hash(self.bare)
        proof = self.release.archive_pin()
        self.assertEqual(proof["revision"], self.revision)
        self.assertEqual((proof["files"], proof["directories"], proof["symlinks"], proof["executables"]), (4, 1, 1, 1))
        self.assertEqual(proof["blobHash"], "git-sha1")
        self.assertEqual(tree_hash(self.bare), before)
        self.assertNotIn(str(self.root), json.dumps(proof))
        self.assertFalse((self.source / ".git").exists())
        self.assertFalse((self.bare / "index").exists())

    def test_changed_blob_is_rejected(self):
        (self.source / "ordinary.txt").write_bytes(b"same filename, different content")
        with self.assertRaisesRegex(ValueError, "blob hash differs"):
            self.release.archive_pin()

    def test_missing_blob_is_rejected(self):
        (self.source / "ordinary.txt").unlink()
        with self.assertRaisesRegex(ValueError, "missing"):
            self.release.archive_pin()

    def test_extra_files_including_bytecode_have_no_exemption(self):
        for name in ("untracked.txt", ".DS_Store", "ignored.pyc"):
            path = self.source / name
            path.write_bytes(b"extra")
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, "extra file"):
                self.release.archive_pin()
            path.unlink()
        (self.source / "__pycache__").mkdir()
        with self.assertRaisesRegex(ValueError, "extra directory"):
            self.release.archive_pin()

    def test_executable_mode_change_is_rejected(self):
        (self.source / "release.sh").chmod(0o644)
        with self.assertRaisesRegex(ValueError, "executable mode"):
            self.release.archive_pin()

    def test_file_replaced_with_symlink_is_rejected(self):
        path = self.source / "ordinary.txt"
        path.unlink()
        path.symlink_to("release.sh")
        with self.assertRaisesRegex(ValueError, "file type"):
            self.release.archive_pin()

    def test_tracked_symlink_changed_or_replaced_with_file_is_rejected(self):
        path = self.source / "link"
        path.unlink()
        path.symlink_to("release.sh")
        with self.assertRaisesRegex(ValueError, "blob hash"):
            self.release.archive_pin()
        path.unlink()
        path.write_bytes(b"ordinary.txt")
        with self.assertRaisesRegex(ValueError, "symlink type"):
            self.release.archive_pin()

    def test_different_full_commit_is_rejected(self):
        self.release.revision = self.other
        with self.assertRaisesRegex(ValueError, "blob hash"):
            self.release.archive_pin()

    def test_non_commit_object_or_missing_object_is_rejected(self):
        blob = self.release.command("blob-object", ["git", "--git-dir", self.bare, "rev-parse", self.revision + ":ordinary.txt"], 10).strip()
        self.release.revision = blob
        with self.assertRaisesRegex(ValueError, "commit object"):
            self.release.archive_pin()
        self.release.revision = "0" * 40
        with self.assertRaises(RuntimeError):
            self.release.archive_pin()

    def test_partial_or_named_revision_is_rejected_before_commands(self):
        for revision in (self.revision[:12], "HEAD", self.revision + "^{commit}", "../fixture", "A" * 40):
            self.release.revision = revision
            with self.subTest(revision=revision), patch.object(self.release, "command") as command:
                with self.assertRaisesRegex(ValueError, "full lowercase"):
                    self.release.archive_pin()
                command.assert_not_called()

    def test_every_gate_repins_archive_before_shared_report_check(self):
        from ci import release
        with patch.object(release, "policy_hash", return_value="fixture-policy"), \
             patch.object(release, "check_reports", return_value=self.revision) as reports, \
             patch.object(release, "check") as worktree:
            self.assertEqual(self.release.gate(), self.revision)
            reports.assert_called_once()
            self.assertEqual(reports.call_args.args[:3], (self.revision, "fixture-policy", b"x" * 32))
            worktree.assert_not_called()
        proof = json.loads((self.output / "source-archive-proof.json").read_text())
        self.assertEqual(proof, self.release.source_proof)
        (self.source / "ordinary.txt").write_bytes(b"changed after first gate")
        with patch.object(release, "check_reports") as reports:
            with self.assertRaises(ValueError):
                self.release.gate(self.revision)
            reports.assert_not_called()

    def test_unsafe_manifest_paths_submodules_and_escaping_links_are_rejected(self):
        for name in (b"../escape", b"/absolute", b"nested/../../escape", b"nested//file", b".git/config"):
            manifest = b"100644 blob " + b"a" * 40 + b"\t" + name + b"\0"
            with self.subTest(name=name), self.assertRaises(ValueError):
                verify_archive(self.source, manifest)
        with self.assertRaisesRegex(ValueError, "submodule"):
            verify_archive(self.source, b"160000 commit " + self.revision.encode() + b"\tsubmodule\0")
        path = self.source / "link"
        path.unlink()
        path.symlink_to("../../escape")
        target = b"../../escape"
        blob = hashlib.sha1(b"blob " + str(len(target)).encode() + b"\0" + target).hexdigest().encode()
        # Verify the link's escape check even with a matching Git blob identity.
        for other in self.source.iterdir():
            if other.is_file() and not other.is_symlink():
                other.unlink()
        import shutil
        shutil.rmtree(self.source / "nested")
        with self.assertRaisesRegex(ValueError, "escapes"):
            verify_archive(self.source, b"120000 blob " + blob + b"\tlink\0")

    def test_git_replacement_cannot_substitute_a_different_commit_tree(self):
        self.release.command("fixture-replace", ["git", "--git-dir", self.bare, "replace", self.revision, self.other], 10)
        self.assertEqual(self.release.archive_pin()["revision"], self.revision)

    def test_build_reads_bare_archive_without_a_git_worktree(self):
        original = self.release.command

        def stop_before_native(name, command, *args, **kwargs):
            if name == "xcodegen":
                raise RuntimeError("native build intentionally not run")
            if name == "source-archive":
                self.assertEqual(command[:4], ["git", "--no-replace-objects", "--git-dir", self.bare])
            return original(name, command, *args, **kwargs)

        info = {"CFBundleShortVersionString": "0.2.0", "CFBundleVersion": "12",
                "SUPublicEDKey": base64.b64encode(bytes(range(32))).decode(), "PostHogProjectToken": "phc_public"}
        with patch.object(self.release, "command", side_effect=stop_before_native):
            with self.assertRaisesRegex(RuntimeError, "intentionally not run"):
                self.release.build(self.revision, info, None, Path("/unused-cli"))
        self.assertEqual(tree_hash(self.output / "source"), tree_hash(self.source))
        self.assertFalse((self.output / "source/.git").exists())

    def test_archive_cli_flags_are_required_together(self):
        from ci import release
        for flags in (("--git-dir", str(self.bare)), ("--revision", self.revision),
                      ("--git-dir", str(self.bare), "--revision", "HEAD")):
            with self.subTest(flags=flags), patch("sys.argv", ["release", *flags]):
                with self.assertRaises(SystemExit) as error:
                    release.main()
                self.assertEqual(error.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
