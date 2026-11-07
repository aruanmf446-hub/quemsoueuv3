# Cobertura ampliada de idiomas

Catálogos com 1.257 mensagens por idioma: inglês, espanhol, francês, japonês, chinês simplificado e russo. Inclui variantes literais usadas pela interface, mensagens dinâmicas, criação/revisão/status de decks, configurações, lobby, duelo, tutoriais e shell do PWA.

Corrigido o lobby que habilitava tradução apenas em inglês. Controles preservam o texto de origem para trocar idioma em execução. Placeholders HTML acompanham o idioma; valores digitados, nomes de jogadores, cartas/decks e chat permanecem intactos. Fonte CJK reutilizada e subconjuntada (~523 KiB). Nenhuma arte nova foi gerada.

## Verificação executada

Godot 4.7.2: catálogos/glyphs e interface real, 28.956 verificações, zero falhas (a maioria são verificações de mensagens e caracteres, não cenários independentes). Regressões de nickname, configurações, recargas, texto Web, carrossel, decks e duelo local passaram; logs anexos. PWA: 31 verificações, zero falhas.

Export Web real em Chromium: seis idiomas, seis telas cada (editor, revisão, amigos, duelo, lobby e tutorial). Inglês em 1672×941; demais em viewport 844×390, user agent de iPhone e DPR 3. Rede externa bloqueada, dados de fixture; nenhuma alteração de conta ou backend. Capturas em web/. O nome “Configurações” é dado proposital do teste para comprovar que nomes não são traduzidos.

Após conferir as imagens, foi ajustada também a altura de títulos CJK do hero. A captura adicional em 640×360 registra essa correção; a matriz inicial de 36 imagens antecede somente esse ajuste de encaixe.

## Limites

Não equivale a teste em iPhone físico/Safari, Android nativo ou Windows. Não foram testados pagamentos, autenticação remota ou uploads reais nesta etapa. Narrativas extensas de phase_stories.json, conteúdo remoto e algumas tarefas especializadas ainda podem conter português; não há alegação de tradução integral de todo conteúdo do jogo. A página de marketing web/site não integra esta entrega de localização do jogo.
