# Decks: integração GAME e CATALOG

## Decisão do produto

O dono confirmou nesta conversa que **resgatar um deck da Comunidade deve
guardá-lo na conta e liberá-lo para jogar no Mata-Mata**. Favoritar, guardar
somente no aparelho ou copiar imagens não satisfaz esse requisito.

Também solicitou corrigir a divisão entre GAME e CATALOG. O CHAT está fora do
escopo. Este documento registra a integração pendente; não afirma implantação.

## Estado confirmado no código

| Responsabilidade | Conexão atual |
| --- | --- |
| Login, perfil, inventário e partidas | GAME — `shuzporktifgiotvnpbz` |
| Criador, Storage privado, revisão e Comunidade | GAME |
| Consulta do catálogo público oficial | CATALOG — `bsxicvlngphazesuzaee`, sem sessão |

`CreatorSync`, `CommunityService` e `DeckReviewService` ainda usam o cliente
GAME. `CatalogService` usa o cliente público CATALOG. Não foi feita uma
migração de dados nem uma simples troca de URL. A sessão GAME não pode ser
reutilizada diretamente como sessão CATALOG; `SupabaseClient` mantém essa
proteção e os testes de conexões continuam cobrindo-a.

`DuelService.load_decks()` consulta `qse_duel_decks`. Publicar um deck de
criador não o inclui automaticamente no catálogo validado das partidas.
O contrato da revisão manual implantada também registra essa separação.

## Trabalho necessário no servidor e no cliente

1. Inspecionar os dois projetos: tabelas, funções, RLS, Storage, decks e
   permissões existentes. Preservar os envios, decisões e vínculos dos autores.
2. Definir a ponte autenticada entre GAME e CATALOG antes de mudar o destino
   do criador ou dos arquivos. Não abrir o bucket privado ou encaminhar JWTs
   entre projetos para contornar a integração.
3. Registrar o resgate por conta no servidor, com unicidade por deck/versão
   conforme o modelo encontrado e elegibilidade validada no servidor.
4. Integrar as cartas aprovadas à resolução de decks do Mata-Mata, com IDs
   estáveis, mantendo validações de sala, partidas online e modo bot.
5. Conectar a ação Resgatar à resposta confirmada, atualizar a biblioteca da
   conta e o seletor de decks. Tratar duplicidade, retirada, logout e falhas.
6. Testar com contas reais: resgate, repetição, nova sessão, seleção e partida
   com bots e jogadores reais. Testes com fixtures não comprovam implantação.

Não há RPC de resgate inventada pelo cliente nem confirmação local de posse.
As assinaturas finais dependem da inspeção do backend existente.

## Bloqueio do ambiente de desenvolvimento

A configuração consultada ainda não disponibiliza acesso administrativo:
o requisito `QSE_SUPABASE_MANAGEMENT_TOKEN` tem `has_saved_binding=false`, e a
sessão ativa não possui esse vínculo. A configuração de rede necessária está
no rascunho e ainda não está publicada na sessão ativa.

O dono deve associar o segredo salvo ao requisito e publicar o ambiente.
Não colocar credenciais no Git, no cliente Web ou nesta documentação.
Uma chave anon/public permite chamadas públicas/RLS; não permite administrar
SQL ou instalar funções. Quando o acesso estiver ativo, verificar primeiro
se a credencial alcança ambos os projetos antes de pedir outra.

Nenhum SQL foi executado e nenhum dado remoto foi alterado nesta etapa.
