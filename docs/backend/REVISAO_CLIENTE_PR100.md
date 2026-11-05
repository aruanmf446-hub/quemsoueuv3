# Cliente e PR #100 — revisão manual de decks

Fonte corrigida conferida por Git: PR #100, commit **d96d0ecbe9e56a0eeb3b3d93fdb63ee8be7870c9**,
branch `chatgpt/decks-review-game-20261105`, destino `work/decks-storage-revisao-manual`.
O responsável pelo backend informou que as três migrations já foram aplicadas.
**Não reexecutá-las.** O Codex não acessou o Supabase nem executou SQL.

## Compatibilidade do cliente

- As quatro RPCs e os parâmetros correspondem ao cliente: access, queue com
  `p_limit:50`, detail por UUID e decide com UUID/boolean/motivo ou null.
- Nickname pode ser `null`. A tela mostra “criador sem nickname”, sem criar ou
  alterar perfil. O revisor é identificado pela autorização do servidor; não
  depende de ID QSE ou de nickname no cliente.
- Capa pode ser `deck_cover.png`, uma prévia de carta escolhida/automática ou
  null. Originais não são baixados pela tela de revisão.
- Prévia ausente vem como null; aprovação fica bloqueada na tela. Erros do
  servidor `missing_images_or_previews`, contagem inválida e sessão ausente têm
  mensagens próprias. Aprovação retorna `review_note:null`, aceita pelo cliente.
- Retirada pelo autor entre abertura e decisão retorna `invalid_status` ou
  `deck_not_found`: a tela atualiza a fila e não confirma aprovação inexistente.
- Rejeitar/corrigir/reenviar: hash do conteúdo detecta mudança no original e nas
  prévias mesmo com o mesmo UUID, nome de arquivo e enquadramento. Conteúdo igual
  mantém a retomada sem upload duplicado. Originais locais continuam intactos.
- Cada abertura do detalhe busca novamente as prévias pendentes. A imagem é
  reutilizada só durante essa abertura, evitando mostrar uma versão anterior
  após correção. A URL recebe uma revisão por abertura e o pedido HTTP solicita
  revalidação, para não depender do cache do navegador. Se o download falhar,
  não usa o arquivo antigo para aprovar.

## Correção SQL validada e PR integrado

O commit `d96d0ec` contém exatamente seis terminadores `;` adicionados após
`$function$`. Uma comparação integral confirmou que o restante dos três arquivos
é idêntico ao commit anterior `4f858b6`.

Validação dos arquivos completos com o parser PostgreSQL `pglast v8.7`:

| Arquivo | Terminadores adicionados | Comandos válidos |
|---|---:|---:|
| `20261105222130_qse_deck_review_acl_and_storage_20261105.sql` | 2 | 15 |
| `20261105222157_qse_deck_review_read_rpcs_20261105.sql` | 3 | 9 |
| `20261105222227_qse_deck_review_atomic_decide_20261105.sql` | 1 | 3 |
| Total | 6 | 27 |

O PR #100 foi integrado à branch **work/decks-storage-revisao-manual**, incluindo
os registros já aplicados e o relatório do responsável. Nenhuma migration foi
editada pelo Codex ou reaplicada; não houve acesso ao Supabase. A main e o Pages
não foram atualizados nesta integração.

A falha de sintaxe está resolvida. A análise anterior permanece como histórico
em `evidence/deck-review-pr100/sql-review.json`; a validação atual está em
`evidence/deck-review-pr100/sql-review-corrected.json`.
Os scripts do cliente permaneceram idênticos aos da versão testada; o merge
trouxe somente documentação e os registros SQL. Os testes com contas reais
continuam pendentes conforme o roteiro abaixo.

O privilégio TRUNCATE continua como pendência separada relatada pelo responsável;
nenhum TRUNCATE, REVOKE ou outro comando de banco foi executado nesta revisão.

## Teste real que ainda precisa ser feito pelo dono

Usar uma versão publicada do cliente desta branch e duas contas reais. Nenhuma
senha/token deve ser enviada ao Codex. O jogo já possui o cadastro obrigatório
de nickname para contas que ainda não o concluíram; a autorização de revisão
fica vinculada à conta, independente desse texto.

1. Conta autora: criar um deck com 5 imagens e nomes diferentes, escolher capa
   e ajustar os dois recortes. Enviar; conferir status em revisão.
2. Conta revisora: abrir Biblioteca → Revisão manual, conferir capa e ambas as
   prévias. Reprovar com motivo e conferir o retorno em Meus Decks da autora.
3. Autora: corrigir a imagem mantendo a mesma carta e extensão, reenviar.
   Revisor: reabrir o detalhe e confirmar que recebeu a imagem nova.
4. Aprovar; conferir a exibição na Biblioteca e a leitura das prévias pela
   autora e outra conta. Confirmar que os originais continuam protegidos.
5. Em outro envio, manter o detalhe aberto no revisor e retirar o deck pela
   autora. Tentar aprovar; o cliente deve avisar e retirar o deck da fila.
6. Conta sem permissão: não pode consultar pendências nem decidir por chamada
   direta. Testes HTTP/RLS com sessões reais e concorrência simultânea são do
   responsável pelo backend; as fixtures locais não substituem esses testes.

Duelo online continua fora desta integração: decks publicados não entram
automaticamente no catálogo de partidas, conforme o relatório do responsável.
Nenhuma regra de partida, autenticação, economia ou música foi alterada.
