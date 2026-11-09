"""Package failure controls. These mocks do not prove signing or a real upload."""

import base64
import hashlib
import json
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch

from ci.release import (BUNDLE, CERTIFICATE, Release, appcast_metadata, release_identity,
                        validate_requirement, validate_smoke, validate_tag)


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
            with patch.object(release, "api", side_effect=[None, existing]) as api:
                with self.assertRaises(ValueError):
                    release.remote_state("0.2.0", "12", "a" * 40)
                self.assertFalse(any(call.kwargs.get("method") for call in api.call_args_list))

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
            with patch.object(release, "api", side_effect=[None, None, {"tag_name": "v" + version},
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


if __name__ == "__main__":
    unittest.main()
