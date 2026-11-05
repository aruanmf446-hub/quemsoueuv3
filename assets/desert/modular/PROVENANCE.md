# Biblioteca modular do Reino do Deserto

- `source/stone_masonry.png`: textura de albedo realmente gerada com image_gen em05/11/2026. Pedido: alvenaria de arenito medieval desértico, detalhes de desgaste, sem personagem/interface/perspectiva. Fonte de autoria preservada, excluída da importação pelo .gdignore.
- `stone_masonry.res`: ImageTexture nativo RGB8 de1024×1024 (~3,6MB), com mipmaps, compressão do ResourceSaver, produzido a partir da fonte pelo Godot4.7.2. Script reprodutível: `tests/desert_night/build_masonry.gd`. Carregável no runtime sem importador do editor. Não é uma imagem de fase.
- Panorâmicas distantes reutilizadas: `assets/desert/night_city/{citadel,bazaar,outskirts}.png`, com autoria anterior documentada no diretório. Os planos simplificados do ZIP não são usados no novo cenário.
- A geometria próxima vem de `scripts/desert/t15d/modular_architecture.gd` e `city_props.gd`: fachadas, lajes, arcos, canais, palmeiras, lanternas, galerias, trilhos, carrinhos, portais e estruturas de madeira. Malhas 3D independentes da arte de fundo, materiais compartilhados e rochas agrupadas em MultiMesh.
- Personagens preservados nos FBX/modelos oficiais do catálogo; GLB de armas e demais arquivos em assets/characters não foram alterados. Malagueta e suas animações originais continuam no interior da fase10.
- Nenhuma nova panorâmica foi gerada para fingir uma fase jogável. O painel de revisão é montado de capturas reais do motor, identificando os pontos teleportados da fixture.

- `assets/story/covers/phase_01.res` até `phase_10.res`: capas de512px, capturadas no Godot4.7.2 sem HUD, instaladas por `tests/desert_night/install_native_covers.gd`. Não são imagens geradas. O enquadramento da capa1 é mais aberto para mostrar o portal; a câmera jogável permanece igual.

- `source/capital_desert.png`: novo fundo de dunas/cidade realmente gerado pela ferramenta de imagens, usando os telhados aprovados como referência. Somente cenário distante das fases1/2; não substitui plataformas/colisões. `capital_desert.res` é ImageTexture RGB8 1672×941 com mipmaps; reconstruir com `tests/desert_night/build_capital_backdrop.gd`.
