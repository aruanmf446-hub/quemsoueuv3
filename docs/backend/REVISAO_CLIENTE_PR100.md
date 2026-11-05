# Cliente e PR #100 — revisão manual de decks

Fonte conferida por Git: PR #100, commit **4f858b6e6dda1c5e47b8b6c871c01771c2ad9b53**,
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

## Pendência no PR #100: registros SQL com erro de sintaxe

Validação **somente de texto**, com o parser PostgreSQL `pglast v8.7`:

| Arquivo registrado no PR | Resultado |
|---|---|
| `20261105222130_qse_deck_review_acl_and_storage_20261105.sql` | Erro próximo a `revoke`, offset 2867 |
| `20261105222157_qse_deck_review_read_rpcs_20261105.sql` | Erro próximo a `CREATE`, offset 405 |
| `20261105222227_qse_deck_review_atomic_decide_20261105.sql` | Erro próximo a `revoke`, offset 4109 |

Faltam terminadores `;` depois das linhas que fecham funções com `$function$`.
Adicionar esses terminadores **apenas em uma string em memória** fez os três
textos passarem no parser (15, 9 e 3 comandos, respectivamente). Nenhum comando
foi executado e nenhum arquivo de migration foi alterado.

O PR #100 foi inspecionado por Git, mas **não mesclado** na branch do cliente.
O autor deve corrigir a formatação dos registros antes da integração, mantendo
nomes/versões e a indicação de que já foram aplicados. A análise do texto não
verifica o estado atual do servidor reportado pelo responsável.

Mensagem para o ChatGPT responsável pelo PR:

```text
O cliente foi conferido com as RPCs do PR #100. O parser PostgreSQL encontrou
falta de ; após os fechamentos $function$ nos três arquivos SQL versionados.
Corrija somente esses terminadores nos registros do PR, preservando nomes,
versões e o aviso de que as migrations já foram aplicadas. Valide o parse dos
arquivos completos. Não execute/reaplique SQL no GAME para corrigir arquivos
do GitHub. Não altere ACL, RLS ou semântica das funções por causa desse ajuste.
```

Resultado reproduzível da análise de texto: `evidence/deck-review-pr100/sql-review.json`.
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
