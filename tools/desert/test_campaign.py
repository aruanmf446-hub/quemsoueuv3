"""Estrutura e contratos; não executa Godot nem prova jogabilidade."""
import hashlib,json,re,subprocess,unittest
from pathlib import Path
from gdtoolkit.parser import parser
ROOT=Path(__file__).resolve().parents[2]
class CampaignTests(unittest.TestCase):
 def test_ten_scenes_configs_and_order(self):
  rules=json.loads((ROOT/'data/progression/rules.v2.json').read_text())
  for phase in rules['phases']:
   n=phase['order'];data=json.loads((ROOT/f'data/desert/phase_{n:02d}.json').read_text())
   self.assertEqual(data['id'],phase['id']);self.assertEqual(data['boss_id'],phase['boss_id'])
   self.assertEqual([c['id'] for c in data['checkpoints']],phase['checkpoint_ids'])
   self.assertTrue((ROOT/f'scenes/desert/phase_{n:02d}.tscn').is_file())
   if n<10:self.assertTrue((ROOT/data['next_scene'].removeprefix('res://')).is_file())
   else:self.assertEqual(data['next_scene'],'');self.assertIn('malagueta',[e['type'] for e in data['enemies']])
   if n>1:self.assertFalse(data['legacy_placeholder_visuals'])
 def test_actual_models_exist(self):
  catalog=json.loads((ROOT/'data/desert_enemies.json').read_text())
  for entry in catalog['enemies'].values():
   for path in [entry['model'],*entry['animations'].values()]:self.assertTrue((ROOT/path.removeprefix('res://')).is_file(),path)
 def test_gdscript_syntax(self):
  parser._cache_dirpath='/tmp/qse-gdtoolkit-cache'
  for path in (ROOT/'scripts/desert').glob('*.gd'):parser.parse(path.read_text())
 def test_t06_and_backend_unchanged(self):
  allowed={'data/desert/phase_01.json','data/desert_enemies.json'}
  for row in filter(None,subprocess.check_output(['git','ls-tree','-rz','16d7823'],cwd=ROOT).split(b'\0')):
   meta,path=row.split(b'\t',1);path=path.decode()
   if path.startswith('scripts/desert/') or path in allowed:continue
   data=(ROOT/path).read_bytes();self.assertEqual(hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest(),meta.split()[2].decode(),path)
 def test_input_cleanup_and_input_registration(self):
  self.assertIn('InputMap.action_has_event',(ROOT/'scripts/desert/phase_01.gd').read_text())
  self.assertIn('func _exit_tree()', (ROOT/'scripts/desert/touch_controls.gd').read_text())
if __name__=='__main__':unittest.main()
