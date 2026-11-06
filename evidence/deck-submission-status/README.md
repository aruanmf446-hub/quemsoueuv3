# Acompanhamento dos decks enviados

Entrada: **Biblioteca → Meus Decks → Acompanhar envios**. Também há acesso pelo
menu do deck e pela tela de revisão. O botão informa quantos decks foram
reprovados. A lista pertence somente à conta atual.

Estados: rascunho, em revisão, reprovado, em correção, aprovado/publicado e
removido. A tela consulta o servidor ao abrir e oferece Atualizar status.
Falha de conexão informa que o estado exibido é o último salvo.

A reprovação mostra o motivo completo, com quebra de linhas, e **Corrigir e
reenviar**. O motivo permanece no editor e na revisão enquanto o autor ajusta
nomes, descrição e imagens. Reenviar envia o MESMO UUID para outra decisão;
não aprova automaticamente nem cria cópia do deck. Depois da confirmação do
servidor, o estado volta a Em revisão e o motivo anterior deixa de aparecer.
Uma nova reprovação mostra o motivo novo. Não há notificação por e-mail/push.

## Contrato existente, sem mudança de backend

A consulta usa `qse_creator_decks` (status/review_note) com a sessão e RLS
existentes. Os triggers e o Storage só deixam editar decks em draft. Antes de
sincronizar uma correção de rejected, CreatorSync confere o status atual e usa
`qse_deck_unpublish` para reabrir o rascunho; essa RPC preserva review_note.
Se o deck já estiver em revisão/publicado/removido, a cópia antiga não o retira
automaticamente. O pedido seguinte usa `qse_deck_publish_request`.
Nenhuma migration, Edge Function, credencial ou conta foi alterada.

## Evidências

Godot 4.7.2: 29 verificações por resolução, todas com failures=0, em 1672×941
(base padrão), 844×390 e 640×360 (perfil iPhone). As capturas são reais do motor,
com dados fictícios identificados como TESTE. Cobrem pendente, reprovado e
aprovado. Os testes exercitam troca da imagem, edição, preservação do motivo,
reenvio sem duplicar, segunda reprovação, aprovação, falha de conexão,
cliques repetidos, conta vazia, troca de conta e resposta atrasada.

Regressões com backend em memória: T21_SYNC 25/25, T27_COMUNIDADE 14/14,
DECK_STORAGE_REVIEW 25/25. Importação completa do projeto sem erros de scripts,
cenas ou recursos; `python3 tools/player_ui/check_design.py`: OK.
Build Web 4.7.2 real, fixture isolado: Chromium com user agent de iPhone,
viewport 844×390 e DPR 3. Passaram por toque: abrir correção, digitar nome,
revisar, reenviar, acompanhar Em revisão e atualizar para Aprovado. Zero erros
de script/cena no navegador; requisições externas bloqueadas antes da rede.
As imagens oficiais presentes na fixture não representam um deck real de rap.

Os testes não acessam Supabase. Teste com contas reais e iPhone físico fica
para o dono; capturas do motor não comprovam funcionamento em Safari.

Reprodução:

```sh
xvfb-run -a godot --path . --script res://tests/deck_submission_status/flow.gd
xvfb-run -a godot --path . --script res://tests/deck_submission_status/flow.gd -- /tmp/status 844x390 --iphone
node tests/deck_submission_status/web_probe.cjs /pasta/do/site /tmp/prova
```
