# Entrega — denúncias e decks da Comunidade

## Caminhos no jogo

- **Denunciar deck:** Biblioteca → Comunidade → abrir deck → Denunciar.
- **Denunciar jogador:** Amizades → abrir perfil público → Denunciar jogador.
- **Salvar deck de outro criador:** abrir na Comunidade → Resgatar grátis. Aparece em
  Meus Decks e na escolha de decks do Mata-Mata, com o criador identificado.
- **Salvar criação própria:** Criar deck → imagens e nomes → Salvar rascunho;
  revisar/enviar à conta e à revisão manual pelo fluxo existente.

As denúncias só exibem confirmação após resposta explícita do servidor. Erros
preservam o motivo. Não é permitido denunciar a própria conta/deck. A denúncia
pendente de um jogador não se duplica e há limite de 10 novos alvos por 24 horas.
Não há banimento automático de jogadores. As denúncias de jogadores ficam privadas
em `qse_v3.player_reports`, para análise administrativa no GAME; esta entrega não
cria uma tela administrativa de julgamento de jogadores. A regra existente de
três denúncias distintas para devolver um deck à revisão foi preservada.

## Supabase

A migration `20261106210000_player_reports.sql` foi aplicada **uma vez** no GAME,
com histórico e hash do arquivo conferidos. RPC `qse_player_report(text,text)`:
identidade vem da sessão, alvo resolvido pelo ID público, tabela com RLS, sem
leitura/escrita direta ou TRUNCATE para jogadores. Não reaplicar a migration.

GAME mantém login, criação, revisão, denúncias e propriedade do resgate. CATALOG
mantém as versões aprovadas e as prévias privadas usadas pelo resgate e pelo duelo.
A integração e a Edge Function de decks já estavam implantadas e validadas nesta
sessão. CHAT não foi alterado. Nenhum segredo administrativo entra no cliente.

## Validação executada

| Verificação | Resultado |
| --- | --- |
| Criação, 15 uploads, gravação/leitura das cinco cartas e envio à revisão | [27/27 no HTTP real](https://github.com/aruanmf446-hub/quemsoueuv3/actions/runs/42278875103) |
| Denúncias de deck/jogador, duplicidade, autoria, sessão e exclusão da fixture | [27/27 no HTTP real](https://github.com/aruanmf446-hub/quemsoueuv3/actions/runs/42279184807) |
| Resgate real, coleção e partida online com bot | [50/50 no HTTP real](https://github.com/aruanmf446-hub/quemsoueuv3/actions/runs/42275200498) |
| Formulário de jogador no Godot 4.7.2 | 16 verificações, zero falhas |
| Regressão de denúncia de deck e retorno dos envios | 33 verificações, zero falhas |
| Godot Web/Chromium, desktop 1672×941 e iPhone UA/DPR3 em 844×390 e 640×360 | digitação, toque, preservação do motivo, erro e confirmação; zero erros de script |
| `tools/player_ui/check_design.py` | OK |
| `tests/web_pwa/sw_test.js` | 31 verificações, zero falhas |
| SQL: autenticação, motivo, autoria, duplicidade, limite, ACL e RLS | aprovado em transação revertida |

O teste PWA usou `/usr/bin/chromium` via wrapper de `chromium.launch`, pois o
Chromium padrão do Playwright não estava instalado. As verificações do teste
não foram alteradas. As capturas Web são fixtures isoladas, sem chamadas ao
Supabase; o teste HTTP de produção é separado. Não houve teste em iPhone físico.

Foi criado apenas um deck QA temporário, aprovado por operação administrativa
restrita ao UUID/nome/hash do autor e às cinco cartas/quinze imagens conferidas.
Não se atribuiu a decisão a um revisor real nem se promoveu conta QA. As denúncias
positivas usaram somente essa fixture e contas QA, nunca decks/jogadores reais.
A leitura administrativa confirmou a denúncia de jogador antes da limpeza.
Deck, cartas, quinze imagens e denúncias QA ficaram em zero. Contas, nicknames,
resgates legítimos e o deck real da validação anterior foram preservados.

Evidências: [capturas e resultados](../../evidence/player-reports/README.md),
[limpeza](../../evidence/player-reports/production-cleanup.json).

## Publicação

A implementação está na main, commit `92dfb4e`. O [deploy Pages/PWA
42279692646](https://github.com/aruanmf446-hub/quemsoueuv3/actions/runs/42279692646)
terminou com **Success**. O build preserva também as mudanças do modo História
que entraram pelo PR #103 durante a validação.

Abra https://aruanmf446-hub.github.io/quemsoueuv3/ e feche/reabra o PWA para
receber a atualização; se aparecer “Reiniciar para atualizar”, aceite no lobby.
