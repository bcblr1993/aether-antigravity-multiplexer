import contextlib
import io
import json
import pathlib
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'Resources'))
import upgrade_all


class UpgradeSafetyTests(unittest.TestCase):
    def instance(self, root, version='2.23.1'):
        return dict(index=2, name='Antigravity Second', app=root / 'Second.app',
                    bundle='local.antigravity.second', version=version,
                    profile=root / '.gemini-1', user_data=root / 'window', key=b'abcdef-standalone-oauth-token')

    def test_force_never_builds_newer_replica(self):
        with tempfile.TemporaryDirectory() as directory:
            item = self.instance(pathlib.Path(directory), '99.0.0')
            with patch.object(upgrade_all, 'source_info', return_value='2.23.1'), \
                 patch.object(upgrade_all, 'discover', return_value=[item]), \
                 patch.object(upgrade_all, 'build') as build, contextlib.redirect_stdout(io.StringIO()):
                upgrade_all.upgrade_all(pathlib.Path('source'), force=True)
            build.assert_not_called()

    def test_corrupt_manifest_rejected_before_build_or_stop(self):
        for text in ('{broken', '[]'):
            with self.subTest(text=text), tempfile.TemporaryDirectory() as directory:
                root = pathlib.Path(directory)
                (root / 'instance-2.json').write_text(text)
                item = self.instance(root, '2.23.0')
                with patch.object(upgrade_all, 'source_info', return_value='2.23.1'), \
                     patch.object(upgrade_all, 'discover', return_value=[item]), \
                     patch.object(upgrade_all, 'APP_SUPPORT', root), \
                     patch.object(upgrade_all, 'build') as build, \
                     patch.object(upgrade_all, 'stop_apps') as stop, contextlib.redirect_stdout(io.StringIO()):
                    with self.assertRaises((ValueError, RuntimeError)):
                        upgrade_all.upgrade_all(root / 'source')
                build.assert_not_called()
                stop.assert_not_called()

    def test_skip_backup_clears_stale_reference_and_atomically_replaces_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            item = self.instance(root, '2.23.0')
            item['app'].mkdir()
            (item['app'] / 'old-marker').write_text('old')
            manifest = root / 'instance-2.json'
            manifest.write_text(json.dumps({'upgrade_backup': 'old-batch', 'custom': 'keep'}))

            def build(source, target, instance, version, signing_dir):
                target.mkdir()
                (target / 'new-marker').write_text('new')
                return 'antigravity-second'

            with patch.object(upgrade_all, 'source_info', return_value='2.23.1'), \
                 patch.object(upgrade_all, 'discover', return_value=[item]), \
                 patch.object(upgrade_all, 'APP_SUPPORT', root), \
                 patch.object(upgrade_all, 'build', side_effect=build), \
                 patch.object(upgrade_all, 'stop_apps'), \
                 patch.object(upgrade_all, 'get_running_instances', return_value=[]), \
                 patch.object(upgrade_all, 'run'), contextlib.redirect_stdout(io.StringIO()):
                upgrade_all.upgrade_all(root / 'source', skip_backup=True)
            record = json.loads(manifest.read_text())
            self.assertNotIn('upgrade_backup', record)
            self.assertEqual(record['custom'], 'keep')
            self.assertEqual(record['version'], '2.23.1')
            self.assertTrue((item['app'] / 'new-marker').is_file())
