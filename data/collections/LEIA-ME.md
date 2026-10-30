# Coleções (categorias de personagens) e novos personagens

## Criar uma coleção ("deck" de personagens)

Cada arquivo `.json` desta pasta vira uma categoria na barra **Coleções** da tela Personagens.
Não precisa mexer em código.

```json
{
  "id": "lendas",
  "name": "Lendas",
  "order": 1,
  "color": "dourada",
  "source": "list",
  "character_ids": ["cowboy", "lana", "el_fuego"]
}
```

- `id`: único, sem espaços nem acentos.
- `name`: o nome que aparece na tela.
- `order`: posição na lista (0 aparece primeiro).
- `color`: fundo das cartas da coleção. Pode ser `azul`, `dourada`, `roxa`, `verde` ou `vermelha`
  (as texturas de `assets/processed/textures/`).
- `source`: `"inventory"` mostra todos os personagens cadastrados (como a coleção Começo);
  `"list"` mostra só os IDs de `character_ids`.
- `character_ids`: IDs de `data/characters.json`. IDs que não existem são ignorados.

## Adicionar um personagem

1. Crie a pasta `assets/characters/<Nome>/` com o modelo e as animações em `.fbx`
   (`1.fbx` é o modelo com a pose base; `2.fbx`, `3.fbx`, `4.fbx` são animações) e a textura
   (`<Nome>_basecolor.jpg` ou `.png`). Abra o Godot uma vez para ele importar os arquivos.
2. Cadastre o personagem em `data/characters.json`:
   - no grupo `playable` se ele já começa liberado;
   - no grupo `unlockable` se precisa ser desbloqueado (campo `unlock`, como o El Fuego).

   Copie um bloco existente (por exemplo o da Lana) e troque `id`, `name`, `model`,
   `animations` e `height` (altura em metros).
3. Para ele aparecer numa coleção com `"source": "list"`, coloque o `id` em `character_ids`.
   Na coleção Começo (`"source": "inventory"`) ele já aparece sozinho.

O retrato da carta é gerado automaticamente na primeira vez que a tela Personagens abre
(fica em `user://thumbnails`).
