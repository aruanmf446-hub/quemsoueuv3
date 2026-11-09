# Evidências — Mata-Mata

Logs nativos: 55 verificações em cada um dos três tamanhos, zero falhas antes
do último ajuste do limite privado para 96. Capturas native640 mostram o renderer
real, enquanto os logs adicionais usam backend headless.

`web/`: Godot 4.7.2 exportado e executado no Chromium desktop; cinco screenshots
de tabuleiro/apresentação e quatro comparações de geometria. Na tentativa final,
turns/remove/hand/chat conservaram 168.95×302.25 por carta, sem AtlasTexture.
A mão Web é vazia; conteúdo de duas cartas foi exercitado apenas no nativo.

A validação Web completa **não passou**: o runner não encontrou AcceptSelection
após os cliques de seleção. Não alcançou os dois perfis iPhone. Ver limitações e
comandos em `tests/duel_stage_layout/README.md`; screenshots isoladas não comprovam
o fluxo inteiro nem funcionamento em aparelho físico.
