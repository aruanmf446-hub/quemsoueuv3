# Figurantes do cenário

Sprites completos renderizados no Godot a partir dos modelos já presentes no jogo:
Lana, Rodrigo, Michelly e soldado Cacto. Não há personagens inventados, modelos novos
ou download de pessoas. O Cacto possui quatro quadros do próprio clipe `andar.fbx`.

Reprodução com display OpenGL:
`Godot --path . --script res://tools/godot/bake_city_extras.gd`

O jogo usa esses sprites sem skeleton, física, dano ou sombras. Eles são removidos
com o trecho, têm cor mais discreta e ficam fora da pista do jogador.
