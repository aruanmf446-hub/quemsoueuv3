# Áreas aprovadas — decisão do dono em 2026-11-09

Aplica-se a qualquer operador: ChatGPT, Codex, Claude, Copilot, outras IAs e pessoas.

## Congelado

Ajustes, Amizades, músicas/player, decks/Biblioteca/criação, compras/economia,
skins, traduções, atualizações/PWA e aprovação/reprovação de decks.
Preservar comportamento, visual, assets, rotas e contratos. Não refatorar, limpar,
renomear, remover, redesenhar nem alterar dependências dessas áreas por iniciativa própria.
Arquivos compartilhados não são uma brecha para alterar uma área aprovada.

## Ainda em desenvolvimento

Modo História, controles do Modo História, Mata-Mata, Novidades, APK e EXE.
Trabalhar neles não autoriza regressões nas áreas congeladas.

## Confirmação obrigatória

Quando o dono pedir uma mudança numa área congelada, antes de editar pergunte:
**“Você já aprovou [área]. Gostaria de alterar [mudança específica]?”**
Aguarde resposta afirmativa. O primeiro pedido não substitui essa confirmação.
Uma confirmação vale somente para o escopo explicado, não para toda a área.
Nunca peça a confirmação repetidamente para o mesmo escopo já confirmado.
Registre pedido, confirmação e arquivos autorizados no relatório da entrega.
Se uma mudança pendente exigir tocar uma área aprovada, faça a mesma pergunta.
Não crie confirmação fictícia nem interprete silêncio como autorização.

O congelamento inicial inclui o resultado desta entrega: o dono pediu continuar
a proteção/histórico e solicitou a prévia borrada com login. Esse escopo inicial
abrange somente histórico de recibos, convite genérico
na Biblioteca e suas traduções/estilo compartilhado. Não liberam outras alterações
em decks, compras, autenticação, skins ou nos sistemas aprovados.

## Poka-yoke executável

`approved_scope.json` registra os blobs dos arquivos congelados e padrões para
arquivos novos. `check_approved.py` compara a revisão com a política da revisão-base,
incluindo alterações/remoções/adições e os próprios arquivos da proteção.
O check roda nos PRs e antes da exportação/publicação normal do Pages.

Para uma alteração excepcional já confirmada pelo dono, o dono define a variável
GitHub **QSE_APPROVED_CHANGE** como JSON com `sha` (commit completo), `areas` e
`reason` (confirmação explícita). Exemplo: `{"sha":"COMMIT_COMPLETO","areas":["amizades","protecao"],"reason":"Confirmei a alteração X"}`.
A autorização vale só para esse commit e áreas; atualizar a própria política exige
`protecao`. A IA não pode definir essa variável nem atualizar a política por conta
própria. Após a alteração autorizada, os blobs da política devem refletir o estado
aprovado; o check também valida isso. Não remover nem contornar o check.

Instruções e CI não são uma proteção absoluta de permissões. Para impedir merge
ou push ignorando checks é necessário configurar ruleset/proteção da main com
**Approved scope guard** obrigatório, sem bypass, e revisão do dono. Esses ajustes
administrativos não são garantidos por arquivos do repositório. Uma credencial
administrativa compartilhada com uma IA não distingue automaticamente IA e dono.
