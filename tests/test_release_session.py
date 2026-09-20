import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'tools'))
import release_session as session


class ReleaseSessionTests(unittest.TestCase):
    def fixture(self, root):
        staged, installed = root/'stage', root/'installed'
        staged.mkdir(); installed.mkdir()
        (staged/'main.lua').write_text('new code')
        (staged/'enabled.txt').write_text('')
        (installed/'main.lua').write_text('old code')
        (installed/'enabled.txt').write_text('existing enablement marker')
        (installed/'config.ini').write_text('personal settings')
        manifest = {'module':'Example','version':'1.0.0','files':{
            p.name:session.digest(p) for p in staged.iterdir()}}
        (staged/'manifest.json').write_text(json.dumps(manifest))
        return staged, installed, manifest

    def prior_manifest(self, installed, version='0.9.0', extra=None):
        files = {p.relative_to(installed).as_posix():session.digest(p)
                 for p in installed.rglob('*') if p.is_file() and p.name != 'manifest.json'}
        files.update(extra or {})
        value = {'module':'Example','version':version,'files':files}
        (installed/'manifest.json').write_text(json.dumps(value))
        return value

    def test_deployment_preserves_settings_enablement_and_backup(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            staged, installed, manifest = self.fixture(root)
            backup = session.deploy(manifest, staged, installed, root/'records', lambda:None)
            self.assertEqual((installed/'main.lua').read_text(), 'new code')
            self.assertEqual((installed/'config.ini').read_text(), 'personal settings')
            self.assertEqual((installed/'enabled.txt').read_text(), 'existing enablement marker')
            self.assertEqual((backup/'before/main.lua').read_text(), 'old code')
            self.assertEqual(json.loads((installed/'manifest.json').read_text()), manifest)
            self.assertIn('"status": "deployed"', (backup/'result.json').read_text())

    def test_deployment_never_creates_enablement_marker(self):
        for fresh in (False, True):
            with self.subTest(fresh=fresh), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                staged, installed, manifest = self.fixture(root)
                (installed/'enabled.txt').unlink()
                if fresh:
                    installed = root/'fresh-install'
                session.deploy(manifest, staged, installed, root/'records', lambda:None)
                self.assertEqual((installed/'main.lua').read_text(), 'new code')
                self.assertFalse((installed/'enabled.txt').exists())
                result = session.compare(manifest, staged, installed)
                self.assertFalse(result['needs_attention'])

    def test_running_game_and_tampered_stage_never_deploy(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            staged, installed, manifest = self.fixture(root)
            with self.assertRaises(RuntimeError):
                session.deploy(manifest, staged, installed, root/'records', lambda:{'pid':1})
            (staged/'main.lua').write_text('unexpected')
            with self.assertRaises(ValueError):
                session.deploy(manifest, staged, installed, root/'records', lambda:None)
            self.assertEqual((installed/'main.lua').read_text(), 'old code')
            self.assertFalse((root/'records').exists())

    def test_removes_only_unchanged_obsolete_managed_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            staged, installed, manifest = self.fixture(root)
            (installed/'obsolete.lua').write_text('old managed code')
            self.prior_manifest(installed)
            (installed/'notes.txt').write_text('user file')
            session.deploy(manifest, staged, installed, root/'records', lambda:None)
            self.assertFalse((installed/'obsolete.lua').exists())
            self.assertEqual((installed/'notes.txt').read_text(), 'user file')
            self.assertEqual(json.loads((installed/'manifest.json').read_text()), manifest)

    def test_modified_obsolete_file_blocks_deployment(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            staged, installed, manifest = self.fixture(root)
            (installed/'obsolete.lua').write_text('managed original')
            self.prior_manifest(installed)
            (installed/'obsolete.lua').write_text('local modification')
            with self.assertRaisesRegex(RuntimeError, 'modified locally'):
                session.deploy(manifest, staged, installed, root/'records', lambda:None)
            self.assertEqual((installed/'main.lua').read_text(), 'old code')
            self.assertFalse((root/'records').exists())

    def test_prior_manifest_cannot_delete_protected_or_unmanaged_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            staged, installed, manifest = self.fixture(root)
            marker = installed/'__folder_managed_by_vortex';marker.write_text('vortex')
            self.prior_manifest(installed)
            session.deploy(manifest, staged, installed, root/'records', lambda:None)
            self.assertEqual((installed/'config.ini').read_text(), 'personal settings')
            self.assertEqual((installed/'enabled.txt').read_text(), 'existing enablement marker')
            self.assertEqual(marker.read_text(), 'vortex')

    def test_invalid_prior_manifest_path_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            staged, installed, manifest = self.fixture(root)
            prior = {'module':'Example','version':'0.9.0','files':{'../escape.lua':'0'*64}}
            (installed/'manifest.json').write_text(json.dumps(prior))
            with self.assertRaises(ValueError):
                session.deploy(manifest, staged, installed, root/'records', lambda:None)
            self.assertEqual((installed/'main.lua').read_text(), 'old code')

    def test_failure_installing_manifest_rolls_back_payload_and_obsolete_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            staged, installed, manifest = self.fixture(root)
            obsolete = installed/'obsolete.lua';obsolete.write_text('managed original')
            prior = self.prior_manifest(installed)
            original_copy = session.shutil.copy2
            def injected_copy(source, target, *args, **kwargs):
                if Path(source) == staged/'manifest.json' and Path(target) == installed/'manifest.json':
                    raise OSError('injected manifest install failure')
                return original_copy(source, target, *args, **kwargs)
            with mock.patch.object(session.shutil, 'copy2', side_effect=injected_copy):
                with self.assertRaisesRegex(OSError, 'injected manifest'):
                    session.deploy(manifest, staged, installed, root/'records', lambda:None)
            self.assertEqual((installed/'main.lua').read_text(), 'old code')
            self.assertEqual(obsolete.read_text(), 'managed original')
            self.assertEqual(json.loads((installed/'manifest.json').read_text()), prior)
            result = json.loads(next((root/'records').glob('*/result.json')).read_text())
            self.assertEqual(result['status'], 'incomplete')
            self.assertEqual(result['rollback'], 'complete')

    def test_mid_deployment_start_records_incomplete_and_stops(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            staged, installed, manifest = self.fixture(root)
            calls = iter([None, {'pid':1}])
            with self.assertRaises(RuntimeError):
                session.deploy(manifest, staged, installed, root/'records', lambda:next(calls))
            self.assertEqual((installed/'main.lua').read_text(), 'old code')
            record = next((root/'records').glob('*/result.json'))
            self.assertIn('"status": "incomplete"', record.read_text())

    def test_ignore_is_explicit_and_does_not_survive_next_launch(self):
        calls = []
        def runner(command, **kwargs):
            calls.append((command, kwargs))
        result = {'needs_attention':True}
        with self.assertRaises(RuntimeError):
            session.launch(result, ['game.exe'], session_provider=lambda:None, runner=runner)
        session.launch(result, ['game.exe','-arg'], True, lambda:None, runner)
        self.assertEqual(calls, [(['game.exe','-arg'], {'shell':False})])
        with self.assertRaises(RuntimeError):
            session.launch(result, ['game.exe'], session_provider=lambda:None, runner=runner)
        with self.assertRaises(RuntimeError):
            session.launch(result, ['game.exe'], True, lambda:{'pid':1}, runner)


if __name__ == '__main__':
    unittest.main()
