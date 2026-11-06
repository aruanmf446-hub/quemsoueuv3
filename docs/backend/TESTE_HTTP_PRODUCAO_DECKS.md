# Teste HTTP de decks em produção — concluído

Após autorização explícita do dono, o teste foi executado usando as contas QA
OWNER, READER e R1 já configuradas nos GitHub Secrets. Nenhuma conta foi criada
ou excluída. As credenciais permaneceram no Actions.

## Resultado

[Execução 42275200498](https://github.com/aruanmf446-hub/quemsoueuv3/actions/runs/42275200498):
**Success, 50/50 verificações aprovadas**, sem casos pulados.

Foram verificados login, resgate real, repetição sem duplicidade, isolamento
da coleção, catálogo online, prévias PNG privadas assinadas, recusa de leitura
sem assinatura, sala privada com dois jogadores e bot, seleção de cartas,
revelação e estabilidade da ordem dos turnos. Ao sair, o adversário perdeu
a permissão de pedir novos manifestos e não ganhou o deck na coleção.

A primeira execução parou antes do resgate porque OWNER ainda não tinha
nickname. Após autorização explícita para gerar os dados necessários,
OWNER e READER receberam seu primeiro nickname pelo fluxo normal de cadastro.
Nicknames válidos existentes não foram trocados. Não houve alteração de
senha, concessão de moderação ou modificação das contas fora do teste.

## Limpeza verificada

As duas contas saíram da sala e as três sessões do teste foram desconectadas
com escopo local, preservando outras sessões das contas.

O operador conferiu UUID, nome exclusivo do run, sala privada/fechada, horário
e hash do criador antes da exclusão. A remoção foi limitada à sala criada
pelo teste, com verificação da cascata e nova consulta independente:

| Registro | Antes | Depois |
| --- | ---: | ---: |
| Sala | 1 | 0 |
| Membros restantes (bot) | 1 | 0 |
| Partida | 1 | 0 |
| Jogadores da partida | 3 | 0 |
| Cartas da partida | 9 | 0 |
| Eventos da partida | 3 | 0 |

Convites, links de convite e expulsões ligados à sala também ficaram em zero.
O deck original continua publicado, com revisões de metadados/imagens intactas.
O resgate normal de OWNER e a versão aprovada no CATALOG foram preservados;
as coleções de READER e R1 não receberam esse resgate.

## Evidências e repetição

[Evidências do run](../../evidence/community-claims/live/42275200498-verification.json).
O relatório original do CI registra a limpeza como pendente naquele momento;
os arquivos `cleanup` e `readback` comprovam a conclusão posterior pelo operador.

`tools/e2e/community_claim_live.py` executa a etapa `claim` do workflow existente.
O push na branch de trabalho só seleciona essa etapa com o marcador explícito
`[qa-claims]`; o padrão permanece `access` (login/consultas). Os relatórios
publicados não contêm e-mails, senhas, tokens ou URLs assinadas.

O teste anterior que propunha criar contas temporárias não foi executado,
após rejeição da revisão automática. O procedimento aprovado reutilizou as
contas existentes e teve sua limpeza conferida separadamente.

Essa é uma validação HTTP em produção. As capturas Web do cliente usam fixtures;
Safari/iPhone físico continua dependendo da conferência no aparelho.
