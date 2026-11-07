# Compra de emotes — GAME

O placeholder `dance_01` tem preço histórico de **100 coins** e permanece inativo.
A dança aprovada `samba` é outro item: **preço ainda não definido**, prévia
visível no cliente e compra/resgate bloqueados. Nenhum produto Samba foi criado
ou ativado no GAME; esta alteração não executa migrations nem concede emotes. Não utiliza gemas,
R2, outro provedor, serviço de pagamento ou acesso ao projeto CHAT/CATALOG.

## Contrato

`qse_emote_shop()` retorna `coins` como string e `items` com `id`, `name`,
`price_coins`, `animation_key`, `available` e `owned` da própria conta.

`qse_emote_purchase(p_emote text, p_request uuid, p_expected_price bigint)`
valida sessão e preço, bloqueia a carteira, usa o lançamento privado existente
`qse_v3.post_wallet_entry` e concede a posse na mesma transação. O retorno
confirmado tem `owned`, `already_owned`, `emote_id`, `coins_after` e
`transaction_id`. Não recebe identidade, saldo, moeda ou valor de débito do cliente.

Tabelas privadas `qse_v3.emote_products` e `qse_v3.player_emotes`, com RLS e
sem leitura, escrita ou TRUNCATE por jogadores. O cliente só usa as RPCs.
Preço adulterado, saldo insuficiente, emote indisponível e reaproveitamento de
uma chave para outro produto são recusados. Carteira bloqueada e chave de posse
única impedem cobranças repetidas. A falha na concessão reverte o débito.

## Item universal da conta

A chave de posse é `(user_id, emote_id)`: o emote pertence à conta GAME, sem
vínculo com personagem, skin ou paleta. Trocar de avatar nunca gera outra
compra. Nome/nickname não identificam o proprietário; a RPC usa `auth.uid()`.
Desativar um produto não remove a posse de quem já o comprou.

O cliente sincroniza a coleção ao entrar na conta e ao abrir a loja. Depois da
compra, o botão passa de Comprar para **Usar emote**. A reprodução usa a posse
confirmada da sessão e o mesmo item em todos os personagens compatíveis, sem
esperar uma consulta HTTP a cada uso/troca de skin. Uma nova instância/dispositivo
consulta a coleção do servidor. Logout ou troca de conta limpa a coleção local;
o cache é vinculado ao UUID do usuário e não concede direitos a outra conta.

`EmoteShopService.play_owned()` é a entrada reutilizável para um CharacterSlot.
Confere proprietário, posse e alvo atual antes de tocar o movimento. O painel
cancela a reprodução atrasada se mudar de personagem/tela. Isto não adiciona
um comando de rede para outros participantes nem novos gatilhos em sala/partida.

`data/emotes.json` registra um objeto por emote. `universal_emotes.gd` resolve
um clipe compartilhado compatível ou um clipe preparado para cada rig, remapeia
os caminhos dos ossos e rejeita ossos inexistentes. Não executa trilhas de método,
áudio ou movimento do nó da cena. Diferenças de proporção/rest pose continuam
exigindo preparação e validação dos assets; não é retargeting artístico automático.
As variações de cor usam o mesmo rig e o mesmo direito de uso.

O registro de `dance_01` tem `clips={}` porque o arquivo real ainda não foi
anexado. `universal_assets_ready()` permanece falso. Essa verificação exige
arquivos para todos os personagens; a validação dos rigs e a revisão visual
também precisam passar antes de ativar o produto. A demonstração não é entregue
como movimento comprado. Prévia e miniatura passam a preferir o movimento real
quando seus assets estiverem registrados.

### Acesso Supabase

O acesso GAME já configurado foi suficiente: auditoria de leitura confirmou a
chave global de posse, RPC de compra autenticada e ausência de INSERT direto
para jogadores. Não é necessária outra chave Supabase, alteração de schema ou
permissão nova. O cliente usa a sessão GAME existente; não recebe Management
token nem service_role. CATALOG, CHAT e Stripe não participam da posse do emote.

## Implantação

Migration `20261106215000_emote_shop.sql` **já aplicada uma vez no GAME** e
registrada no histórico com o hash do arquivo. **Não reaplicar manualmente.**

Produto `dance_01`: 100 moedas, `animation_key=emote_dance_01`, `active=false`,
`asset_ready=false`. A verificação de produção encontrou zero posses. A implantação
não debitou carteiras nem concedeu o exemplo a contas reais. CHAT e CATALOG não
foram alterados. O cliente continua na branch de prévia; não houve deploy Pages.

Antes de liberar a venda: receber o movimento real, importar/retargetear para os
modelos suportados, vincular o alias e as miniaturas, validar movimento e uso,
publicar o cliente correspondente e só então aprovar/ativar o item no GAME.
As variações de cor já têm seleção junto ao personagem. O uso do emote comprado
está conectado no painel. Gatilhos de lobby/sala/partida e transmissão para outros
jogadores continuam fora desta entrega; não foram alteradas regras de partida.

## Validação da conexão universal

- Auditoria read-only no GAME: posse por usuário/emote, compra autenticada,
  sem escrita direta e produto real ainda inativo/sem asset aprovado.
- SQL real com contas e produto sintéticos, tudo revertido por ROLLBACK:
  uma compra, um débito, nova leitura pela mesma conta, isolamento, posse
  preservada após desativação e ausência de vínculo com personagem/variante.
- Godot 4.7.2: 45 verificações do adaptador/posse nos oito modelos, recuperação
  em nova instância, uso sem recompra/HTTP, isolamento e cancelamento de alvo.
- Regressão da compra: 14 verificações, failures=0. Design check: OK.
- Godot Web + Chromium em 1672×941, 844×390 e 640×360: uma compra de fixture,
  saldo 250→150 e uso em Cowboy/El Fuego/Halloween sem outro débito. Os dois
  tamanhos menores usam iPhone UA/DPR 3. Zero erros de script.

Os clipes originais usados nesses novos testes validam ligação ao rig e posse;
**não representam uma dancinha real aprovada para venda**. Não houve compra
HTTP com conta real, teste em dois aparelhos ou validação em iPhone físico.
Nenhuma migration nova ou alteração persistente de dados foi necessária.
Evidências em `evidence/universal-emotes`. Cliente permanece na branch.

## Validação executada

- PostgreSQL real, dados sintéticos com BEGIN/ROLLBACK: compra, preço de 100,
  saldo insuficiente, gemas intactas, isolamento, idempotência, ACL/RLS,
  exclusão de conta e reversão atômica quando a entrega falha.
- HTTP real sem sessão: ambas as RPCs recusam com 401 / `42501`.
- Godot 4.7.2: 19 verificações dos contextos/loja, 32 de movimento nos oito
  modelos, 14 de compra/repetição/resposta perdida/sessão e 26 de regressão
  dos decks comunitários, sem falhas. Design check: OK.
- Godot Web/Chromium em 1672×941, iPhone UA/DPR3 em 844×390 e 640×360:
  três exemplos, dança, confirmação por 100 moedas, saldo 250→150, item
  adquirido e fechamento da confirmação, sem erros de script.

O teste Web usa um catálogo e uma carteira de fixture, com movimento marcado
como disponível exclusivamente para testar o fluxo. Não é uma compra em conta
real. A transação real foi exercitada no PostgreSQL e revertida. Não houve teste
HTTP positivo com conta real, concorrência simultânea em dois clientes nem teste
em iPhone físico. O bloqueio por linha e as restrições estão no código do servidor.

[Evidências](../../evidence/skin-emotes/examples-shop/README.md).
