import os
import plistlib
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import upload_posthog_symbols as upload


class SymbolUploadTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.contents = self.root / 'Tessera.app/Contents'
        self.contents.mkdir(parents=True)
        (self.root / 'Tessera.app.dSYM').mkdir()
        self.info = {'CFBundleShortVersionString': '0.2.0', 'CFBundleVersion': '12', 'CFBundleIdentifier': 'com.abdwy.Tessera'}
        self.env = {'POSTHOG_CLI_API_KEY': 'owned-private-sentinel', 'POSTHOG_CLI_PROJECT_ID': '340688', 'POSTHOG_CLI_HOST': 'https://eu.posthog.com'}

    def invoke(self):
        with (self.contents / 'Info.plist').open('wb') as target:
            plistlib.dump(self.info, target)
        with patch.object(sys, 'argv', ['upload', '--products', str(self.root), '--cli', '/owned/posthog-cli']), patch.dict(os.environ, self.env, clear=True):
            upload.main()

    def test_matching_symbols_upload_without_source_or_key_in_arguments(self):
        with patch.object(upload, 'symbol_uuids', return_value={'owned-uuid'}), patch.object(upload.subprocess, 'run') as run:
            self.invoke()
        args = run.call_args.args[0]
        self.assertNotIn('--include-source', args)
        self.assertNotIn('owned-private-sentinel', args)
        self.assertEqual(args[-1], '12')
        self.assertEqual(run.call_args.kwargs['timeout'], 180)

    def test_mismatched_symbols_do_not_upload(self):
        with patch.object(upload, 'symbol_uuids', side_effect=[{'app'}, {'other'}]), patch.object(upload.subprocess, 'run') as run:
            with self.assertRaisesRegex(ValueError, 'do not match'):
                self.invoke()
        run.assert_not_called()

    def test_missing_symbols_do_not_upload(self):
        (self.root / 'Tessera.app.dSYM').rmdir()
        with patch.object(upload.subprocess, 'run') as run:
            with self.assertRaisesRegex(ValueError, 'do not match'):
                self.invoke()
        run.assert_not_called()

    def test_wrong_project_does_not_upload(self):
        self.env['POSTHOG_CLI_PROJECT_ID'] = 'another-project'
        with patch.object(upload, 'symbol_uuids', return_value={'owned-uuid'}), patch.object(upload.subprocess, 'run') as run:
            with self.assertRaisesRegex(ValueError, 'Dedicated Tessera'):
                self.invoke()
        run.assert_not_called()

    def test_major_release_does_not_upload(self):
        self.info['CFBundleShortVersionString'] = '1.0.0'
        with patch.object(upload.subprocess, 'run') as run:
            with self.assertRaisesRegex(ValueError, '0.x.x'):
                self.invoke()
        run.assert_not_called()

    def test_other_bundle_does_not_upload(self):
        self.info['CFBundleIdentifier'] = 'other.app'
        with patch.object(upload.subprocess, 'run') as run:
            with self.assertRaisesRegex(ValueError, 'different app'):
                self.invoke()
        run.assert_not_called()
