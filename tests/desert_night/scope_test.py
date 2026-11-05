"""Confere que a Os modelos oficiais e os sistemas fora do escopo permanecem idênticos à base pedida."""
from pathlib import Path
import subprocess
import argparse
parser=argparse.ArgumentParser()
parser.add_argument('--base',default='967a408922cdf2c681433a32cf98613fdd0d5e28',help='Commit-base da revisão; padrão histórico preservado')
args=parser.parse_args()
root=Path(__file__).resolve().parents[2]
protected=['data/desert/phase_10.json','scripts/desert/phase_01.gd','scripts/desert/side_player.gd','scripts/desert/cactus_enemy.gd','scripts/menu','scripts/lobby','scripts/skins','scripts/audio','scripts/services','supabase','project.godot','assets/characters']
changed=subprocess.check_output(['git','diff','--name-only',args.base,'--',*protected],cwd=root,text=True).splitlines()
assert not changed,'Arquivos fora do escopo alterados: '+str(changed)
print('PASS modelos oficiais, sistemas compartilhados, lobby, Personagens, áudio, serviços e Supabase preservados')
