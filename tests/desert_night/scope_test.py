"""Confere que a Os modelos oficiais e os sistemas fora do escopo permanecem idênticos à base pedida."""
from pathlib import Path
import subprocess
import argparse
parser=argparse.ArgumentParser()
parser.add_argument('--base',default='967a408922cdf2c681433a32cf98613fdd0d5e28',help='Commit-base da revisão; padrão histórico preservado')
parser.add_argument("--story-continuity",action="store_true",help="Autoriza somente serviço e migração de continuidade desta tarefa")
args=parser.parse_args()
root=Path(__file__).resolve().parents[2]
protected=['data/desert/phase_10.json','scripts/desert/phase_01.gd','scripts/desert/side_player.gd','scripts/desert/cactus_enemy.gd','scripts/menu','scripts/lobby','scripts/skins','scripts/audio','scripts/services','supabase','project.godot','assets/characters']
changed=subprocess.check_output(['git','diff','--name-only',args.base,'--',*protected],cwd=root,text=True).splitlines()
if args.story_continuity:
 allowed={"scripts/services/story_progress_service.gd","supabase/game/migrations/20261107150000_story_run_resume.sql"}
 changed=[path for path in changed if path not in allowed]
assert not changed,'Arquivos fora do escopo alterados: '+str(changed)
print('PASS modelos oficiais, lobby, Personagens, música do menu e demais sistemas protegidos preservados; continuidade da campanha autorizada' if args.story_continuity else 'PASS modelos oficiais, sistemas compartilhados, lobby, Personagens, áudio, serviços e Supabase preservados')
