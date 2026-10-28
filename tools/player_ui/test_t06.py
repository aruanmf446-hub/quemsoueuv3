"""Regressões estáticas T06; não substituem execução GDScript no motor."""
from pathlib import Path
import subprocess
import unittest
from tools.player_ui.check import ROOT, check

BASE='529ab72'
ALLOWED={'scripts/ui/navigation_manager.gd','scripts/ui/player_screen.gd','scripts/ui/screens/settings_screen.gd','scripts/ui/screens/public_profile_screen.gd','scripts/skins/thumbnail_cache.gd','scripts/services/device_preferences.gd','tools/player_ui/check.py'}

class T06Tests(unittest.TestCase):
    def test_reference_and_rpc_contract_suite(self):
        # Gate original protege nove arquivos da T03; a captura ganha guarda de ciclo de vida na T06.
        from tools.player_ui import check as module
        previous=set(module.ALLOWED_CHANGES)
        try:
            module.ALLOWED_CHANGES.add('scripts/skins/thumbnail_cache.gd')
            self.assertEqual(check()['routes'],8)
        finally:
            module.ALLOWED_CHANGES.clear();module.ALLOWED_CHANGES.update(previous)

    def test_previous_deliveries_and_backend_unchanged(self):
        tree=subprocess.check_output(['git','ls-tree','-rz',BASE],cwd=ROOT).split(b'\0')
        import hashlib
        for row in filter(None,tree):
            header,name=row.split(b'\t',1);name=name.decode()
            if name in ALLOWED:continue
            data=(ROOT/name).read_bytes()
            self.assertEqual(hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest(),header.split()[2].decode(),name)

    def test_failed_preferences_save_does_not_apply(self):
        source=(ROOT/'scripts/services/device_preferences.gd').read_text()
        failure=source.index('if last_error != OK:')
        self.assertLess(failure,source.index('\tapply()',failure))
        self.assertIn('values[key] = previous\n\t\treturn false',source)
        self.assertIn('config.load(SAVE_PATH)',source)

    def test_hidden_profile_discards_response(self):
        source=(ROOT/'scripts/ui/screens/public_profile_screen.gd').read_text()
        self.assertIn('if epoch != _epoch or not is_visible_in_tree():',source)

    def test_capture_guards_after_frame_await(self):
        source=(ROOT/'scripts/skins/thumbnail_cache.gd').read_text()
        guard=source.index('if not is_instance_valid(stage)')
        self.assertGreater(guard,source.index('await RenderingServer.frame_post_draw'))
        self.assertLess(guard,source.index('viewport.get_texture().get_image()'))

if __name__=='__main__':unittest.main()
