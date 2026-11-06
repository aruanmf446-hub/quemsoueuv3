# Resgate de decks — GAME e CATALOG

Migrations e gateway implantados em **06/11/2026**, após autorização do dono.
Cliente publicado no main/Pages: execução [42262100661](https://github.com/aruanmf446-hub/quemsoueuv3/actions/runs/42262100661),
commit `5d1262995acc253e136920f4356d904342fc1355`, resultado **Success**.
O dono definiu: resgatar deve guardar na conta e liberar no Mata-Mata.
As credenciais dos dois projetos estão disponíveis; os acessos à Management API
foram confirmados. O bloqueio anterior do ambiente foi resolvido.

## Divisão de responsabilidades

| Conteúdo | Projeto |
| --- | --- |
| Login, autores, rascunhos, originais, revisão manual | GAME `shuzporktifgiotvnpbz`, fluxo existente preservado |
| Registro de resgates e validação de partidas | GAME, novas RPCs |
| Versões aprovadas e prévias imutáveis distribuídas | CATALOG `bsxicvlngphazesuzaee`, tabela e bucket novos privados |
| Catálogo oficial existente | CATALOG, preservado |

CHAT não participa desta implementação. Não há migração de contas, exclusão de
decks existentes ou publicação dos originais. Os decks enviados continuam no
fluxo de criação/revisão atual. No primeiro resgate de uma revisão aprovada,
suas prévias são copiadas para uma versão imutável no CATALOG.

## Fluxo implementado

1. O botão nativo **RESGATAR GRÁTIS** chama `qse-deck-catalog` no GAME.
2. A função valida a sessão no Auth GAME. Somente depois solicita ao banco os
   metadados e caminhos de prévias de um deck efetivamente aprovado e público.
3. Copia apenas PNGs de Biblioteca/duelo, até 2048×2048 e 4 MiB por imagem, para
   o bucket privado `qse-community-previews` no CATALOG. Não copia originais.
4. Registra a versão e verifica novamente o estado e a revisão no GAME antes
   de finalizá-la. Retirada/alteração durante o preparo impede sua conclusão.
5. A RPC de resgate, chamada com a sessão do próprio jogador, registra a posse.
   Há um único vínculo por conta/deck. Repetir não duplica; uma nova revisão
   aprovada pode atualizar a versão vinculada.
6. Meus Decks mostra a coleção e o criador. O seletor do Mata-Mata oferece os
   decks resgatados e disponíveis, incluindo o jogo local com bots.
7. As imagens são obtidas por URLs assinadas de uma hora e ficam em cache por
   conta. O JWT GAME nunca autentica no CATALOG; a chave administrativa do
   CATALOG existe somente na função do servidor.

As cartas usam `community_<versão-sem-hífens>/<uuid-da-carta>`. São IDs estáveis,
independentes da posição na galeria. A mecânica de seleção, turnos, bots e
revelação continua usando os sistemas existentes.

## Posse, sala e retirada

- O administrador da sala precisa ter resgatado cada versão comunitária que
  seleciona. A validação é do GAME, inclusive contra chamadas diretas.
- Os demais participantes podem carregar as cartas da sala enquanto forem
  membros; isso não lhes concede uma cópia permanente do deck.
- A retirada pelo autor mantém o registro na coleção, marcado indisponível,
  e impede novos resgates e partidas com esse deck. Uma partida já em andamento
  continua resolvendo sua versão imutável. Expulsão/saída remove o acesso remoto
  pelas permissões de sala.
- Logout/troca de conta limpa os catálogos e texturas em memória. Partidas
  oficiais locais continuam independentes de login; a sala local com conteúdo
  vinculado à conta é encerrada ao trocar/sair da conta.
- Cache não substitui o registro de posse. Online, as permissões são novamente
  verificadas pelo servidor. Uma consulta antiga não sobrescreve o resultado
  de um resgate mais recente.

## Implantação realizada e validação restante

Os testes anteriores rodaram com **ROLLBACK**. Após aprovação, foram aplicadas
somente as duas migrations novas e registradas, na mesma transação, com as
versões dos arquivos. Os hashes registrados foram comparados ao código.
`qse-deck-catalog` está ACTIVE, versão 1. Sessão ausente/falsa retorna HTTP 401;
o preflight CORS retorna 204. O bucket novo foi confirmado privado.

O teste HTTP com sessões reais foi concluído após autorização explícita:
[run 42275200498](https://github.com/aruanmf446-hub/quemsoueuv3/actions/runs/42275200498),
**50/50 verificações aprovadas**, com OWNER/READER/R1 existentes. Houve
resgate real, download privado assinado, sala com adversário e bot, seleção
e revelação de cartas. A sala e seus registros derivados foram removidos e
conferidos por leitura independente; contas e resgate QA foram preservados.

Roteiro de implantação (executado; não reaplicar migrations):

1. Aplicar somente `supabase/catalog/migrations/20261106160000_community_versions.sql`
   no CATALOG e `supabase/game/migrations/20261106160100_community_claims.sql` no
   GAME, registrando essas versões no histórico. Não reaplicar migrations antigas.
2. Configurar `CATALOG_SERVICE_ROLE_KEY` somente nos secrets das Edge Functions
   do GAME. Não usar anon/public para essa operação, nem inserir esse valor no
   cliente, repositório, logs ou arquivos de evidência. O acesso administrativo
   já validado permite configurar esse segredo; não é preciso colar outra chave
   nesta conversa.
3. Implantar `supabase/game/functions/qse-deck-catalog/` no GAME. Configurar
   `verify_jwt=false` na plataforma: o handler exige e valida explicitamente o
   token no Auth GAME, incluindo recusa de token falso/ausente. `SUPABASE_URL`
   e `SUPABASE_SERVICE_ROLE_KEY` são as variáveis nativas do próprio GAME.
   O handler não depende de bibliotecas externas; `index.ts` importa `handler.js`.
4. Testar HTTP real: sessão ausente/falsa, resgate, duplicidade, isolamento,
   retirada e autorização das prévias. Testar uma partida online real e bots.
5. Publicar o cliente somente após o servidor estar disponível. Fazer merge e
   acompanhar `deploy-web.yml`/Pages apenas com autorização de publicação.

A migração não registra o deck de produção como resgatado por nenhuma conta.
A geração da versão ocorre sob demanda, pelo fluxo real de resgate.

Os contratos públicos da Management API para migrations, secrets e deploy de
funções foram consultados. A implantação ocorreu somente após a autorização explícita do dono,
registrada na conversa. Evidências em `evidence/community-claims/deployment.json`.

## Validação

[Relatório, capturas e comandos](../../evidence/community-claims/README.md).
Os testes HTTP usaram sessões reais do gateway implantado. Testes do banco
com rollback e capturas Web com fixtures são evidências distintas. Não houve
validação no Safari/iPhone físico.

O teste HTTP com contas reais está [concluído, com autorização e limpeza verificadas](TESTE_HTTP_PRODUCAO_DECKS.md).
