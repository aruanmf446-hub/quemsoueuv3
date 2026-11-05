# Decks com Storage existente e revisão manual

Direção atual: Supabase GAME existente + bucket privado **qse-deck-originals**.
Sem Cloudflare, Worker, R2, GitHub token no jogo ou outro provedor.
A branch anterior `work/decks-revisao-repositorio` é uma alternativa descartada;
não mesclar nem seguir suas instruções de implantação.

## O que já existe no código

- `CreatorSync`: upsert em `qse_creator_decks`/`qse_creator_cards`, imagens,
  prévias de Biblioteca/duelo e capa no Storage, usando o JWT da conta.
- `CommunityService`: `qse_deck_publish_request`, status e motivo de recusa,
  retirada, vitrine e leitura autenticada das prévias publicadas.
- Rascunhos separados por dono, originais preservados e IDs estáveis em reenvios.
- O usuário não precisa de conta GitHub. Não há cobrança pela criação nem API
  de geração de imagens. Quotas/custos do Storage continuam sujeitos ao plano.

Os arquivos aprovados continuam no **Storage**. O código do jogo permanece no
GitHub/Pages. Não é necessário gerar um novo commit/build para cada deck aprovado.
Copiar automaticamente as imagens para o GitHub não faz parte deste caminho.

## Cliente preparado nesta branch

`work/decks-storage-revisao-manual` parte da main e reaproveita esse fluxo.
O editor oferece prompt baseado nos oficiais e envia para revisão gratuitamente.
Biblioteca → **Revisão manual** abre a tela nativa do dono. O servidor precisa
confirmar seu papel; jogadores comuns não recebem a fila nem ações de decisão.

`deck_review_service.gd` prevê o contrato abaixo, exclusivamente no GAME existente.
Não há endpoint de hospedagem novo. Essas RPCs são **propostas para conferência**:
não foram criadas nem verificadas no servidor por esta entrega. Se ausentes,
o cliente exibe “a revisão pelo jogo ainda precisa ser habilitada no Supabase”.
Não simula aprovação, papel administrativo ou envio bem-sucedido.

## Contrato para o responsável pelo Supabase

Todas as chamadas usam `auth.uid()` da sessão. Autorização de revisor deve ficar
no servidor, em lista administrativa protegida; não confiar em parâmetros de
usuário, nickname, metadata editável pelo usuário ou papel de administrador de sala.

| RPC | Entrada | Retorno |
|---|---|---|
| `qse_deck_review_access()` | `{}` | `{"is_moderator":true/false}` |
| `qse_deck_review_queue(p_limit integer)` | `{"p_limit":50}` | `{"items":[{"id":"uuid","name":"…","status":"pending_review"}]}` |
| `qse_deck_review_detail(p_deck uuid)` | `{"p_deck":"uuid"}` | `{ "deck":{ "id":"uuid", "name":"…", "description":"…", "status":"pending_review", "creator":{"nickname":"…"}, "cover_path":"caminho ou null" }, "cards":[{ "id":"uuid", "name":"…", "preview_library_path":"…", "preview_duel_path":"…" }] }` |
| `qse_deck_review_decide(p_deck uuid,p_approved boolean,p_reason text)` | UUID, boolean, motivo ou null | `{"deck_id":"uuid","status":"published ou rejected","review_note":"…"}` |

Falha de negócio no formato existente `{"error":"forbidden"}`,
`invalid_status`, `deck_not_found`, `invalid_reason`, `min_cards` ou
`missing_images_or_previews`. Sem sessão: recusar; jogador comum:
`access=false` e recusar as outras três RPCs, inclusive chamadas diretas.

- Decisão deve ser atômica, travar o deck e aceitar somente `pending_review`.
  Um segundo revisor ou clique repetido não deve sobrescrever a decisão anterior.
- Aprovação valida 5–30 cartas, nomes e imagens/prévias válidos e existentes;
  publica pelo mecanismo confiável do servidor preservando os guards atuais.
  Cliente não escreve `status`, `visibility`, `review_note` ou `published_at`.
- Reprovação exige motivo de 3–280 caracteres e conserva o deck do autor.
- Escrita/remoção de imagens ou cartas permanece bloqueada durante revisão e
  após publicação. Não enfraquecer os triggers existentes para habilitar a tela.
- Registrar revisor/decisão com um mecanismo administrativo confiável existente
  ou propor um registro de auditoria restrito. Não expor notas privadas na vitrine.
- Queue/detail não devem expor e-mail, UUID de autenticação como campo de perfil,
  tokens ou segredos. Caminhos de Storage incluem o owner UUID por contrato;
  são fornecidos apenas para leitura autenticada autorizada, não URLs públicas.
- Bucket permanece **privado**. Conceder ao revisor somente leitura das prévias
  `_library.png`, `_duel.png` e `deck_cover.png` do deck em revisão, validando
  vínculo e autorização. Não abrir os originais, todo o bucket ou todos os rascunhos.
- O cliente aceita imagens apenas dos caminhos retornados no detalhe para o
  UUID correto. Cache de revisão fica separado por conta e é inacessível pelo
  serviço após logout/troca de conta.
- Não alterar os decks oficiais, partidas, autenticação, economia ou música.
  Biblioteca da comunidade e catálogo de partidas são integrações distintas:
  confirmar a participação de decks publicados no duelo antes de prometer uso online.

## O que o dono faz manualmente

1. Ter em mãos o e-mail usado no login do jogo. Não é necessário obter ou criar
   um ID QSE. Não fornecer tokens/senhas.
2. Abrir o ChatGPT com o plugin Supabase e colar o prompt abaixo. Informar o
   e-mail nessa conversa quando solicitado; o plugin deve localizar a conta
   existente no projeto GAME e confirmar com você antes de autorizar o revisor.
3. Receber o relatório das RPCs/políticas e trazer a resposta para o Codex ajustar
   qualquer diferença de contrato. Não é necessário criar conta em outro provedor.
4. Depois da publicação do cliente, testar com jogador e revisor: enviar, reprovar,
   ler o motivo, corrigir, reenviar, aprovar e conferir a vitrine. Fechar/reabrir
   o PWA após uma atualização do cliente. Isso não foi testado em produção aqui.

## Prompt para o ChatGPT com plugin Supabase

```text
Projeto: Quem Sou Eu V3. Quero autorizar minha conta existente como revisora.
Peça o e-mail que uso no login do jogo para localizar a conta. Não exija um
identificador QSE; não crie outra conta nem altere meu perfil para este fluxo.

Usaremos somente o Supabase GAME existente e seu Storage privado. Não criar
Cloudflare Worker, R2, outro provedor ou credencial administrativa no cliente.
Confirme que o projeto GAME é shuzporktifgiotvnpbz antes de qualquer alteração.

Inspecione primeiro qse_creator_decks, qse_creator_cards, bucket qse-deck-originals,
qse_deck_publish_request, qse_deck_unpublish, qse_community_decks e
qse_community_deck, triggers de moderação e políticas de Storage/RLS.
Não reexecute migrations já aplicadas. Preserve o fluxo atual.

Confira o contrato documentado em docs/backend/DECKS_STORAGE_REVISAO_MANUAL.md
na branch work/decks-storage-revisao-manual de aruanmf446-hub/quemsoueuv3.
Se não puder ler o GitHub, peça que eu cole a seção de contrato.

O cliente prevê quatro RPCs no GAME: qse_deck_review_access(),
qse_deck_review_queue(p_limit integer), qse_deck_review_detail(p_deck uuid),
qse_deck_review_decide(p_deck uuid,p_approved boolean,p_reason text).
Reaproveite equivalentes existentes ou implemente apenas o que faltar,
respeitando os retornos e requisitos do documento.

Localize a conta real pelo e-mail de login e confirme comigo qual conta será
autorizada antes de conceder a permissão. Use seu identificador Auth existente
somente no mecanismo protegido do servidor. Se não houver correspondência
única, pare e explique. Não autorize automaticamente quem chamar primeiro.
Administrador de sala, nickname ou metadata editável não concedem moderação.

Bucket privado; originais protegidos; revisor pode ler apenas as prévias/capa
dos decks pendentes. Usuários comuns não podem listar pendências de terceiros,
ler suas imagens nem aprovar por chamada direta. Decisão atômica somente de
pending_review, com validação de 5–30 cartas/imagens para aprovar e motivo de
3–280 caracteres para reprovar. Preserve travas de escrita durante moderação.

Não alterar autenticação, nickname, partidas, economia, músicas ou decks
oficiais. Não implementar cobrança nem geração de imagens. Informe
separadamente se o duelo online já reconhece decks de criadores; não mude
regras de partida para resolver isso sem apresentar a necessidade.

Ao terminar, devolva nomes/assinaturas reais, exemplos JSON sem segredos,
políticas alteradas e resultado dos testes de permissão: autor, outro jogador,
revisor e chamada sem sessão. Diferencie testes de banco/API de testes dentro
do jogo; não alegue validação no jogo ou iPhone sem executá-la.
```

## Limites desta entrega

O Codex não acessa o Supabase, não pede credenciais e não cria/aplica migrations
ou Edge Functions. Os testes do cliente usam fixtures sem rede. A infraestrutura
real, permissões de revisão e envio com contas reais dependem da conferência
pelo responsável com o plugin. As capturas nativas não são teste de iPhone físico.
