# Teste FBX de dança nos oito avatares

Solicitação do dono: usar um FBX de dança real para mostrar o mesmo movimento
nos outros personagens. Este fixture fica fora dos assets/produtos do jogo.

Fonte pública: Three.js, `examples/models/fbx/Samba Dancing.fbx`:
https://github.com/mrdoob/three.js/blob/dev/examples/models/fbx/Samba%20Dancing.fbx

SHA-256 do arquivo testado:
`b9003ee562c87bf03051c3a502411b0808d3513f1d74a2011f7530d9f067069f`.

O arquivo contém `Take 001` (0,958 s) e `mixamo_com` (18,2 s). O teste usa o
segundo, que contém a dança, não a primeira animação do arquivo. O FBX bruto e
o modelo doador não foram adicionados ao repositório nem à loja.

## Fluxo reproduzível

Utilizar uma cópia isolada do projeto preparada para os fixtures Web, com o
marcador `.iphone_web_fixture_stage`, os assets originais e os scripts atuais.

1. `python3 tests/fbx_dance/fetch_source.py <stage>` baixa/verifica a fonte.
2. Importar o stage no Godot 4.7.2 (`--headless --editor --import --quit`).
3. Executar `--headless --path <stage> --script res://tests/fbx_dance/bake.gd`.
4. Exportar o fixture Web com `tests/iphone_deck/export_fixture.py`.
   O helper preserva os arquivos gerados no stage.
5. `node tests/fbx_dance/record.cjs <pasta-do-site> <pasta-dos-frames>`.
   Exemplo de URL: `?fixture=fbx_dance&group=1` (ou `group=2`).
6. Codificar as sequências PNG com ffmpeg, 10 fps. Os vídeos entregues mostram
   0–5,9 s da dança, sincronizados entre os personagens.

`bake.gd` gera recursos Animation separados por rig no stage, preservando as
posições e escalas de repouso. Transfere o delta global das rotações, adapta a
altura do quadril e mantém a dança no lugar com apoio dos pés. Não modifica
FBX/OBJ/texturas dos personagens. A correspondência dos ossos e o erro de apoio
dos pés são verificados durante a geração. Este procedimento é um bake offline
de teste; não representa importação/retargeting automático liberado na loja.

`preview.gd` usa CharacterSlot e o palco originais. O gravador amostra a animação
no Godot Web e aguarda o desenho real antes de salvar cada frame. Não usa imagens
geradas por IA nem interpolação de vídeo. O framerate da gravação não é uma
medição de performance do jogo.

Evidência e mídia: `evidence/fbx-samba-test`. Não há ativação de venda, alterações
de conta/Supabase, publicação no main ou no Pages.
