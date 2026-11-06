# Pesquisa e autoria dos decks da Comunidade

A lista de resultados e o detalhe exibem **Criado por <nickname>**. O nickname
vem de `creator.nickname` retornado pelo GAME, não do nome do Google, e-mail ou
campo digitável do deck. Se faltar, a interface informa Criador não informado.
O nome completo fica no tooltip quando precisa de reticências no cartão.

A pesquisa local já comparava nome do deck e criador, mas a vitrine só carregava
os primeiros 48 registros. Agora começa com uma página e completa as páginas de
metadados quando há pesquisa, usando o `next_cursor` opaco da RPC existente.
A RPC atual filtra `p_query` por nome/descrição, não por nickname; por isso o
cliente pagina metadados e aplica o filtro pelo criador. A normalização existente
aceita maiúsculas e acentos. As capas são carregadas em lotes dos resultados,
sem buscar cartas/originais apenas para pesquisar.

Atualizar na Biblioteca renova a listagem; erro informa que os resultados podem
estar incompletos e permite tentar novamente, preservando o catálogo anterior.
Cursores repetidos terminam com erro. Novas decisões obtidas no acompanhamento
também invalidam o prazo do cache da vitrine.

## Contrato consultado, sem executar SQL

`20261105222227_qse_deck_review_atomic_decide_20261105.sql` define aprovação como
published/public e reprovação como rejected/private.
`20261102003754_t24_3a_comunidade_consolidada.sql` lista somente published/public
e retorna a autoria a partir do perfil do dono. O cliente conserva essa regra
quando esses campos vêm explicitamente no retorno. Não há mudança de RPC,
migration, Storage, permissões ou conta; nenhum acesso ao Supabase.

## Validação

Godot 4.7.2: 16 verificações, zero falhas, em cada resolução: 1672×941 (base
padrão), 844×390 e 640×360 (perfil iPhone). Catálogo em memória com 60 decks,
com o deck pesquisado além dos primeiros 48. Testes de pendente, rejeitado,
aprovado, pesquisa por nickname/nome, normalização, autoria no cartão/detalhe,
autor ausente sem expor e-mail/nome do Google, falha de rede, cursor repetido e
recuperação. As capturas são reais do motor com dados TESTE.

Regressões: T27_COMUNIDADE 14/14, DECK_STORAGE_REVIEW 25/25, T23_LIBRARY 32/32,
T24_LIBRARY 18/18. Design checker: OK; importação/export Web sem erros de
scripts/cenas/recursos.

Build Web real: Chromium com user agent de iPhone, 844×390 e DPR 3. Toque no
campo, pesquisa USUARIO X, resultado além da primeira página, abertura por toque
e crédito Criado por Usuário X nos dois lugares: passou, zero erros de script.
Requisições externas bloqueadas antes da rede. Não é validação de um deck real
no Supabase, de contas reais ou em iPhone físico.

```sh
xvfb-run -a godot --path . --script res://tests/community_attribution/flow.gd
xvfb-run -a godot --path . --script res://tests/community_attribution/flow.gd -- /tmp/prova 844x390 --iphone
node tests/community_attribution/web_probe.cjs /pasta/do/site /tmp/prova-web
```
