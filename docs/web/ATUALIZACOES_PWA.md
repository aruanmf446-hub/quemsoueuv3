# Atualizações rápidas do PWA

Implementação preparada em branch, sem publicar esta alteração na main.

## O que causava a demora

O shell anterior consultava atualizações a cada 30 minutos. O aviso só surgia
quando o service worker terminava de preparar os arquivos obrigatórios, inclusive
o pacote grande do Godot. Esse tempo de download parecia ausência de atualização.
O botão de fechar/abrir não garantia que a instalação acabasse nos primeiros
15 segundos previstos pelo antigo atalho automático de startup.

## Comportamento novo

- Marcador pequeno `jogar/version.json` identifica o commit publicado, com consulta
  `no-store` e parâmetro de cache a cada verificação. Fica fora do cache do worker.
- Consulta ao abrir, a cada minuto enquanto a página está visível e ao recuperar
  foco, visibilidade ou conexão (com proteção contra eventos repetidos).
- `sw.js?build=<commit>` muda uma vez por versão, mantém um único registro no mesmo
  escopo e usa `updateViaCache: none`. Arquivos do jogo usam a URL do hash para não
  reaproveitar uma resposta HTTP antiga sob a chave de uma versão nova.
- O HTML pequeno é validado pelo hash antes de entrar no cache. Resposta antiga
  do CDN faz a instalação falhar e permite tentar novamente, preservando a versão
  em uso. Essa validação não pretende substituir a distribuição atômica do Pages.
- A detecção informa “Baixando atualização” antes de o pacote terminar. O motor
  inalterado continua reutilizado pelo hash de conteúdo. Não há promessa de pular
  o tempo necessário para baixar um pacote alterado ou propagar o deploy no CDN.
- Ajustes tem um botão permanente “Verificar atualização” no cabeçalho. O painel
  informa versão carregada/publicada, estado e ação explícita de reiniciar.
- A página externa `/atualizar/`, vinculada no rodapé do site, verifica/prepara o
  worker de `/jogar/` sem iniciar o Godot. Se houver outra aba/app do jogo aberto,
  pede para fechar antes da ativação. Em um mesmo navegador, isso permite recuperar
  um shell antigo que ainda não oferece a nova verificação interna.

## Segurança e dados

Não apaga IndexedDB, localStorage, sessão, rascunhos, progresso ou outros caches.
Não desinstala o PWA nem remove seu registro. A substituição do cache de arquivos
mantém o comportamento por conteúdo do worker existente.

Não há recarga automática de uma partida. Reiniciar depende da ação explícita e
do sinal do motor: lobby, Ajustes ou Conta, fora de sala. O sinal é republicado
quando o estado da sala muda, mesmo sem troca de rota. O shell também bloqueia
reinício enquanto `qseStoryPlaying` estiver ativo. Outras abas do jogo impedem
ativação, pois uma aba antiga pode ainda ter o handler de recarga automática.
O editor de decks fica fora das rotas seguras para evitar perder uma edição.

No iPhone, Safari e PWA instalado podem ter armazenamentos/registros separados.
A página externa só atualiza o contexto do navegador em que foi aberta; não é
controle remoto do app instalado. Nesse app, use o botão interno ou retorne ao
app para a verificação imediata. Não foi feita validação em aparelho físico.

## Primeira disponibilização

Esta solução só estará disponível no site após merge/deploy autorizado. Uma
versão antiga não ganha o botão interno por alteração remota de configuração.
Após a primeira publicação, a página externa pode preparar a versão nova para o
mesmo navegador; o novo shell passa a consultar em intervalos curtos. Não orientar
o jogador a apagar dados do site ou desinstalar para receber uma atualização.

## Validação

- `node tests/web_pwa/sw_test.js`: worker único, cache, ativação consentida e ponte
  de texto/PWA. Engine do fixture é explicitamente sintético.
- `node tests/web_pwa/update_test.cjs <pasta> <evidencias>`: quatro builds de teste,
  HTTP cache longo, pacote atrasado, atualização automática/manual, offline, foco,
  abas abertas, HTML antigo de CDN, reuso do wasm e preservação de login/IndexedDB.
  Página externa em desktop, dois landscapes e retrato; botão visível sem rolar.
- `tests/pwa_update_settings/web.cjs`: build Godot Web 4.7.2 real via
  `tests/iphone_deck/export_fixture.py`, em 1672×941, 844×390 e 640×360, iPhone UA/DPR3
  nos dois últimos; clique/toque no botão nativo e abertura/fechamento do painel.
- `tools/web/check_pwa.py` verifica o marcador e a igualdade dos IDs da página,
  worker e versão, além de garantir um único registro e o carregamento do verificador.

Capturas e logs em `evidence/pwa-fast-update`. Nenhum pagamento, autenticação remota
ou backend foi alterado. As versões update-a/b/c/d e input-fixture são dados de teste.
