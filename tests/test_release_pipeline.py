import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class ReleasePipelineTests(unittest.TestCase):
    def test_valid_old_ticket_cannot_bypass_build_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            (root / 'scripts').mkdir()
            (root / 'bin').mkdir()
            shutil.copy2(ROOT / 'scripts/package-release.sh', root / 'scripts/package-release.sh')
            shutil.copy2(ROOT / 'Info.plist', root / 'Info.plist')
            for path, content in [
                (root / 'build.sh', '#!/bin/zsh\ntouch build-attempted\nexit 73\n'),
                (root / 'bin/python3', '#!/bin/zsh\nexit 0\n'),
                (root / 'bin/xcrun', '#!/bin/zsh\nexit 0\n'),
            ]:
                path.write_text(content)
                path.chmod(0o755)
            env = dict(os.environ, SIGN_IDENTITY='test', NOTARY_PROFILE='test',
                       PATH=str(root / 'bin') + ':' + os.environ['PATH'])
            result = subprocess.run(['zsh', str(root / 'scripts/package-release.sh')],
                                    env=env, capture_output=True, text=True)
            self.assertTrue((root / 'build-attempted').exists(), result.stdout + result.stderr)
            self.assertEqual(result.returncode, 73, result.stdout + result.stderr)
            self.assertFalse((root / 'dist/appcast.xml').exists())
