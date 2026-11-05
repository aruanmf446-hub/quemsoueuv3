# Bot de assets do Reino do Deserto

Bot assistido por Codex: organiza a fila, monta os argumentos da ferramenta de
imagens, registra as fontes e prepara os recursos nativos no Godot. **Não é um
serviço24h, não chama APIs pagas por conta própria e não gera imagens apenas
executando Python.** A etapa de geração é executada por Codex com image_gen
nesta conversa. Não precisa de credenciais adicionais.

## Operação

1. `python3 tools/asset_pipeline/desert_bot/asset_bot.py next --limit 2`
   imprime os argumentos exatos para a ferramenta de imagens. Não altera a fila.
2. Codex executa as chamadas `image_gen__imagegen` com esses argumentos e mostra
   as imagens reais. Lotes são limitados a um ou dois itens; não gerar os itens
   restantes automaticamente nem afirmar gasto fixo de cota.
3. `python3 tools/asset_pipeline/desert_bot/asset_bot.py register ID /caminho/gerado.png`
   registra PNG RGBA com transparência, origem e hash. Não sobrescreve fontes
   nem aceita um item já registrado. Registrar somente resultado real de image_gen.
4. `python3 tools/asset_pipeline/desert_bot/asset_bot.py build --godot /caminho/godot`
   prepara os itens novos em RGBA8, maior dimensão1024, mipmaps, proporção
   preservada e ResourceSaver comprimido. Reabre cada recurso para conferir dimensões.
   Só marca prepared após sucesso e acrescenta os itens ao catálogo existente.
5. `python3 tools/asset_pipeline/desert_bot/asset_bot.py status` mostra a fila.

Estados: pending → generated → prepared. prepared **não significa aprovação
visual nem integração em fase**. O dono revisa a imagem; posicionamento no jogo é
uma etapa separada com captura do motor. Fontes estão sob source/.gdignore;
recursos.res são reutilizáveis em Sprite3D. Não criar personagens substitutos,
não mexer em backend, não fazer merge/main ou publicar sozinho.

Para continuar em outra sessão: leia este arquivo, queue.json e PROVENANCE.md;
use a referência existente, não regenere itens prepared, execute só o lote pedido.
Se a ferramenta de imagens estiver indisponível, pare a geração e registre a
limitação; não invente arquivos nem use desenhos provisórios como resultado.

Dependências locais: Python3/Pillow (já usado pelas capturas do projeto) e Godot4.7.2.
