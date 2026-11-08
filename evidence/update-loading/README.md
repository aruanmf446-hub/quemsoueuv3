# Carregamento da atualização — 08/11/2026

O dono mostrou o modal parado em “Baixando atualização…”. O worker enviava somente
um aviso de início, sem progresso de transferência. O pedido explícito agora abre
uma tela inteira com barra de arquivos processados e MB realmente recebidos.
A barra não promete percentual por bytes, pois nem toda resposta informa seu tamanho.
Sem totais disponíveis (inclusive worker antigo), o indicador é indeterminado.

A contagem lê o stream consumido pelo CacheStorage, sem carregar o pacote inteiro
em RAM. A versão antiga permanece em execução até o reinício seguro já existente.
Fechar a tela preserva o download em segundo plano. Três minutos sem progresso
mostram recuperação; mensagens tardias de uma instalação com erro não escondem a falha.
Uma tentativa nova não enfileira update() sobre um worker já em instalação.

Teste real de service workers no Chromium com payload do motor SINTÉTICO, explicitamente
montado por tests/web_pwa/assemble.py; não é uma execução do Godot nem de aparelho físico.
38 verificações passaram: download interrompido, bytes avançando antes de terminar
o pacote, recuperação, offline, CDN inconsistente, cache por conteúdo, bloqueio de
reinício durante partida, instalação consistente e preservação de localStorage/IndexedDB.
Capturas reais do shell em 1672×941, 844×390 e 640×360. O teste também verifica a página
externa em 390×844. Comando: node tests/web_pwa/update_test.cjs <site temporário> <evidências>.
