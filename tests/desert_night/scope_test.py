"""Confere que a fase10 e os sistemas fora do escopo permanecem idênticos à base pedida."""
from pathlib import Path
import subprocess
root=Path(__file__).resolve().parents[2]
protected=['scenes/desert/phase_10.tscn','data/desert/phase_10.json','scripts/desert/phase_01.gd','scripts/desert/side_player.gd','scripts/desert/cactus_enemy.gd','scripts/menu','scripts/lobby','scripts/skins','scripts/audio','scripts/services','supabase','project.godot']
changed=subprocess.check_output(['git','diff','--name-only','1ed2f12','--',*protected],cwd=root,text=True).splitlines()
assert not changed,'Arquivos fora do escopo alterados: '+str(changed)
print('PASS fase10, sistemas compartilhados, lobby, Personagens, áudio, serviços e Supabase preservados')
