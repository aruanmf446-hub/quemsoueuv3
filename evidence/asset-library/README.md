> Registro da preparação do lote. A integração posterior está em [ten-approved](../ten-approved/README.md).

# Lote grande de assets

Dez imagens realmente geradas; quinze módulos no catálogo total. As dez novas
texturas foram salvas e reabertas no Godot4.7.2 com alfa e mipmaps, máximo1024.
Fontes PNG sob source/.gdignore; runtime.res reutilizável, proporção preservada.

`placements.json`: validador executado no Godot,10 fases,63 posições,failures=0.
Cada largura cabe num piso real; alvos percentuais ajustados para apoio seguro.
Fase2 mantém apoio>=8m; portal da mineradora somente na saída da9; progressão
congelamento3/corrida4/Ruptura5 conferida contra o controlador existente.

**Isto valida recursos e o plano, não montagem visual ou jogabilidade instalada.**
Nenhuma cena ou controlador foi alterado nesta entrega; novos assets continuam
com placed_in_game=false. Exigem recortes de piso, composição na câmera e captura
real durante integração. Galeria em docs/desert/assets/LOTE_GRANDE.md.

Reproduzir: `godot --headless --path . --script res://tools/asset_pipeline/desert_bot/resolve_placements.gd -- /tmp/placements.json`.
Preparação: `asset_bot.py build --godot /caminho/godot` (processa somente generated).
Bot rejeita lote>2 sem --large-batch; os hashes das12 fontes da fila foram
conferidos, e todos os15 módulos do catálogo têm destino em alguma fase.
