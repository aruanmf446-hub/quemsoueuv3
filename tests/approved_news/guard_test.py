import runpy,unittest
from pathlib import Path
check=runpy.run_path(str(Path(__file__).resolve().parents[2]/'tools/governance/check_approved.py'))['evaluate']
class ScopeGuard(unittest.TestCase):
 def setUp(self):self.p={'areas':{'amizades':['friends/*'],'skins':['skins/*']},'blobs':{'friends/a':'a','skins/b':'b'}};self.current=dict(self.p['blobs'])
 def test_unchanged(self):self.assertEqual(check(self.p,self.current),[])
 def test_change(self):self.current['friends/a']='new';self.assertEqual(check(self.p,self.current),['friends/a'])
 def test_delete(self):del self.current['skins/b'];self.assertEqual(check(self.p,self.current),['skins/b'])
 def test_add(self):self.current['skins/new']='n';self.assertEqual(check(self.p,self.current),['skins/new'])
 def test_pending_area(self):self.current['story/phase']='n';self.assertEqual(check(self.p,self.current),[])
 def test_control_tamper(self):self.assertEqual(check(self.p,self.current,['AGENTS.md']),['AGENTS.md'])
 def test_specific_confirmation(self):self.current['friends/a']='n';self.assertEqual(check(self.p,self.current,authorization={'sha':'abc','areas':['amizades'],'reason':'Dono confirmou X'},sha='abc'),[])
 def test_other_area_not_unlocked(self):self.current['skins/b']='n';self.assertEqual(check(self.p,self.current,authorization={'sha':'abc','areas':['amizades'],'reason':'sim'},sha='abc'),['skins/b'])
 def test_wrong_commit(self):self.current['friends/a']='n';self.assertEqual(check(self.p,self.current,authorization={'sha':'old','areas':['amizades'],'reason':'sim'},sha='new'),['friends/a'])
 def test_missing_confirmation(self):self.current['friends/a']='n';self.assertEqual(check(self.p,self.current,authorization={'sha':'abc','areas':['amizades'],'reason':''},sha='abc'),['friends/a'])
if __name__=='__main__':unittest.main()
