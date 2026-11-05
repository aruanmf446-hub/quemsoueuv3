# Revisão do cliente para a PR #99 — 05/11/2026

Referência inspecionada: `origin/pr-99`, commit `83e707b`.
[PR #99](https://github.com/aruanmf446-hub/quemsoueuv3/pull/99).
Cliente de partida: main `cb3bfc4`.

## O que mudou no estado das pendências

O dono encaminhou o relatório de implantação do GAME e CHAT: seis migrations
aplicadas, gateway v11 ativo e testes SQL isolados com rollback aprovados.
O relatório diz que os dados existentes foram preservados e que T21/T22 já
possuem implementação no servidor. Essas são informações do responsável pelo
backend; o Codex não consultou os projetos Supabase para confirmá-las.

O código da PR foi lido pelo GitHub. A PR não foi mesclada, nenhuma migration
foi reexecutada e nenhuma Edge Function foi publicada pelo Codex.
O merge dessa PR serve para versionamento; segundo o relatório, não é necessário
para ativar o que já foi implantado. Não reenviar o pedido antigo como se fosse
uma implantação nova.

## Compatibilidade conferida no código

| Área | Backend registrado na PR | Cliente |
|---|---|---|
| Perfil próprio | mesmos oito campos, nickname nulo antes da escolha | contrato existente compatível |
| Erros de nickname | `error` + `error_code`: taken/locked/invalid | mensagens existentes compatíveis |
| Nome canônico | trim ASCII + Unicode NFC; chave lowercase | ajuste da confirmação descrito abaixo |
| Duelo sem nickname | `nickname_required` | fallback de `DuelService.message` já utiliza a mensagem de `ServiceResult` |
| Ordem | `turn_order` persistido antes da seleção | apresentação existente usa a ordem recebida no countdown |
| Tempo | mínimo 5 s, `ceil(7 + 1.8 × participantes)` | respeita o prazo fornecido pelo servidor |
| Bots online | `sender_name` já inclui ` · BOT`, `is_you=false` | o adaptador preserva esse nome e a UI já o exibe |

Não foi criado outro sorteio, gerador de falas online ou sistema de nickname.

## Ajuste do cliente

O formulário exigia igualdade literal entre a entrada e o nome retornado. O
backend pode receber `Cafe` + U+0301 e armazenar `Café` em NFC. A comparação
literal pode sinalizar falso erro apesar de a gravação ter sido confirmada.

Agora o sucesso exige a resposta bem-sucedida e o perfil confirmado da mesma
conta com nickname válido (`ProfileService.has_nickname`). O cliente conserva
exatamente a grafia retornada pelo servidor. Não aplica uma normalização própria,
não inventa um nome e não libera resposta pertencente a outra conta.

A regressão usa a UI real com transporte simulado, sem rede: o cenário falhou
na comparação antiga e passou após o ajuste. Também cobre o erro de sala
`nickname_required` e mantém os testes anteriores de proprietário da sessão,
trava, confirmação duplicada, convidado, carregamento e conflito.

## Limites da revisão

Continua pendente a integração com duas sessões reais: disputa concorrente de
nickname, OAuth/restauração de sessão, ordem/timeout/reconexão/pick repetido,
entrega idêntica das falas dos bots e autorização do chat. O relatório da PR
expressamente não declara esses cenários aprovados. O Codex não executou esses
testes nem solicitou credenciais.

Publicação/moderação/Storage, favoritos, playlist e amizades também precisam de
E2E real; o relato de estruturas implantadas não é prova de que todos os fluxos
do cliente já estão integrados. Não recriar T21/T22 com base nos pedidos antigos.

Evidência local: `evidence/pr99-client-compat/nickname-policy.log`.
