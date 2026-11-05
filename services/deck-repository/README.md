# Revisão manual de decks no repositório

Implementação sem R2. O jogador usa somente a conta do jogo. O Pages serve
arquivos; uma ponte Fetch API recebe o JWT do jogo e grava os envios no GitHub.
O código em `src/worker.mjs` pode ser hospedado como Cloudflare Worker, sem KV,
R2 ou banco adicional. Não há geração automática de imagens nem cobrança.

## Fluxo implementado

1. Biblioteca → Meus Decks → Criar deck. Nome, categoria, imagens e nomes das
   cartas continuam no editor existente, incluindo recortes e capa.
2. Escolher a referência oficial e copiar o prompt para usar manualmente na
   ferramenta de imagens. Nenhuma API de imagens é chamada pelo jogo.
3. Revisar → Enviar para revisão · grátis. Apenas contas com nickname e sessão
   válidos podem enviar. Os originais permanecem no aparelho; cópias WebP
   otimizadas são enviadas à ponte.
4. A ponte valida identidade, imagens, limites e autoria e cria um commit na
   branch **deck-inbox**, em `deck_submissions/<id>.json` e `queue.json`.
5. O dono abre **Meus envios / Revisão manual** na Biblioteca. A conta autorizada
   vê a fila, capa, cartas e nomes, e aprova ou reprova com motivo.
6. A aprovação publica somente assets e manifesto na **main**. O workflow
   `deploy-web.yml` existente exporta o jogo e atualiza Pages/PWA. O deck entra
   na Biblioteca e no Mata-Mata **local** na próxima versão baixada.
   Aprovação não significa que o deploy já terminou.
7. Meus envios mostra o histórico mesmo em outro aparelho. O rascunho local
   recebe aprovação/reprovação ao reabrir a Biblioteca (intervalo de 60 s).
   Editar um enviado exige uma cópia; excluir a cópia local não retira o envio.

**Privacidade:** este repositório é público. A fila, incluindo imagens, nickname
e ID público QSE, também é pública antes da aprovação. Só o catálogo do jogo
fica restrito aos aprovados. Não enviar conteúdo confidencial. UUID privado,
e-mail, JWT e token GitHub não são persistidos nos pacotes. O hash do proprietário
é usado para isolamento; não transforma uma fila pública em armazenamento privado.
Decks privados do fluxo antigo não são migrados nem expostos.

## Ativação pendente — necessária para receber envios reais

Este ambiente não possui conta/bindings Cloudflare. Nenhum Worker foi publicado,
nenhuma chamada ao Supabase foi executada e `data/community/repository.json`
mantém `api_url` vazio. O editor funciona, mas o envio fica desativado com aviso.
Não inserir um endereço inventado para remover o aviso.

Em um terminal do responsável com Cloudflare e GitHub configurados:

1. Usar Node 24 e instalar/executar o Wrangler 4:

   ```bash
   cd services/deck-repository
   npx wrangler@4 login
   ```

2. Preencher `MODERATOR_PUBLIC_IDS` em `wrangler.toml` com o **ID público QSE-…**
   do perfil do dono. Pode listar outros revisores separados por vírgula.
   Manter `MAIN_BRANCH=main`, `INBOX_BRANCH=deck-inbox` e o origin do Pages.
   Não usar nickname como autorização.
3. Criar um fine-grained PAT GitHub limitado a este repositório, com permissão
   **Contents: read/write**, e cadastrar como secret do Worker:

   ```bash
   npx wrangler@4 secret put GITHUB_TOKEN
   npx wrangler@4 secret put GAME_PUBLISHABLE_KEY
   npx wrangler@4 deploy
   ```

   `GAME_PUBLISHABLE_KEY` é a chave **pública/publishable** do jogo já existente;
   nunca usar service-role. Os secrets são inseridos no terminal do provedor,
   nunca no chat, em JSON do jogo ou no repositório. O PAT é uma credencial de
   servidor; não usar `${{ secrets.GITHUB_TOKEN }}` de um workflow: commits feitos
   com esse token de Actions não disparam o deploy por push. O PAT deve expirar
   e ser renovado no provedor.
4. Verificar `GET /health` (`configured:true`) e configurar a URL HTTPS real no
   campo `api_url` de `data/community/repository.json`. Publicar o jogo pelo
   processo normal. Nenhuma migration/Edge Function precisa ser alterada para
   a ponte: ela verifica JWT via JWKS e consulta `qse_profile_self` existente.
   JWTs HS256 legados não são aceitos; RS256/ES256 são suportados.
5. Testar com contas de jogador/revisor: enviar, reprovar e ler o motivo,
   reenviar uma versão editada, aprovar, conferir o commit e o workflow Pages.
   Fechar/reabrir o PWA após o deploy. Não considerar este teste real executado
   apenas porque os testes com servidor simulado passaram.

Não conceder bypass de proteção da main sem avaliar as regras do repositório.
Se a branch exigir PR/checks antes de qualquer push do bot, a publicação direta
retornará erro; será necessário adaptar a ponte ao fluxo de PRs. A branch
deck-inbox é uma fila de dados; **não deve ser mesclada na main**.

## Limites e recuperação

- 5–30 cartas; nome do deck 3–60 caracteres; carta 1–40; nomes únicos.
- WebP estático, até 768 KiB/imagem e 6 MiB por envio incluindo capa; cliente
  reduz cópias para até 1600 px. Servidor limita dimensão, tipo e tamanho;
  moderador vê imagens decodificadas no Godot antes de aprovar.
- Máximo de três envios pendentes e cinco novos envios em 24 h por conta.
- Reenvio idêntico recupera o mesmo protocolo; corrigir um reprovado cria outro.
- Aprovar executa claim → publish → finalize, em três requisições. Isso mantém
  até 30 cartas + capa dentro do orçamento de subrequests. Falha pode ser
  retomada em **Concluir publicação** sem duplicar o deck. Reprovação fica
  bloqueada após o início da publicação.
- Atualizações concorrentes usam commits e refs sem force; em conflito, atualizar
  a lista e tentar novamente. Não sobrescrevem alterações de outros commits.
- Não há promessa de hospedagem ilimitada/gratuita: o jogo cobra zero, mas o
  responsável deve acompanhar quotas do Worker, GitHub API e tamanho do repo.
  Uploads e histórico Git crescem; remover um arquivo não apaga o histórico.
- Autoria confiável vem do perfil validado, nunca de campos enviados pelo cliente.
  Só arquivos de `assets/duel/decks/community/` e o manifesto são publicados.

## Mata-Mata online — pendência para o responsável pelo backend

O servidor online decide os decks válidos. Um commit no GitHub **não cadastra**
uma coleção em seu catálogo. Esta entrega habilita Biblioteca/local sem fingir
que uma coleção nova já funciona em salas online.

Gerar um handoff JSON offline após aprovar decks:

```bash
python3 tools/decks/repository_catalog.py --output /tmp/decks-aprovados.json
```

Entregar esse JSON ao ChatGPT com o plugin Supabase com a solicitação:
“Inspecione o contrato atual de `qse_duel_decks` e o catálogo `qse_v3.duel_decks`.
Cadastre por upsert os IDs e cartas deste JSON, preservando os decks existentes,
sem apagar dados e sem alterar regras de partida. Confirme que os IDs aceitam
o formato repo_ + 24 hexadecimais e card_01…card_30. Os arquivos já estão no
build do jogo; não precisam de Storage. Confira separadamente se a descoberta
online da Biblioteca usa outro catálogo e proponha o vínculo apropriado antes
de alterar seu esquema. Não presuma que o commit tenha atualizado o banco.”

O exportador não escreve SQL, migrations nem chama backend. O script antigo
`tools/duel/sync_decks.py` continua restrito aos decks oficiais.

## Testes reproduzíveis

```bash
node --test-isolation=none --test services/deck-repository/tests/worker.test.mjs
python3 tools/decks/repository_catalog.py
godot --headless --path . --script res://tests/deck_repository/flow.gd
xvfb-run -a godot --path . --script res://tests/deck_repository/flow.gd -- /tmp/decks 844x390 --iphone
```

Testes da ponte usam somente GitHub, perfis e chaves JWT **simulados**. Cobrem
permissões, assinatura, propriedade, limites, replay, concorrência e retomada.
Capturas e resultados desta entrega: `evidence/deck-repository/README.md`.

## Futuro

Gerador por API, pagamentos e moderação automática permanecem fora desta versão.
Contratos separados de geração/cobrança devem ser adicionados no servidor, com
chaves secretas, consentimento e preços explícitos. O cliente atual declara
`price:0`; mudar esse JSON sozinho não cria um sistema de cobrança.
