# Sincronização futura com Supabase

Implementação de referência: [server_reference.py](../../tools/progression/server_reference.py) e [sync.py](../../tools/progression/sync.py). Nenhum SDK de Supabase/R2, HTTP, autenticação real, tabela ou serviço foi acessado.

## Pedido e resposta v2

O pedido contém `protocol_version`, `rules_version`, `request_id` UUID, `expected_revision` e uma operação do [contrato](CONTRATO_V2.md). O servidor obtém o dono pelo contexto autenticado. O cliente não envia `user_id`, progresso completo para sobrescrever o remoto, recompensa ou campos de concessão.

Toda resposta válida contém o ID do pedido, estado autoritativo e um resultado:

| Resultado | Significado | Ação do cliente |
| --- | --- | --- |
| `applied` | Transição aplicada uma vez | Marcar pedido, aceitar snapshot autenticado compatível. |
| `noop` | Estado já satisfaz o pedido, sem nova concessão/revisão | Marcar pedido, sem duplicar progresso. |
| `conflict` / `revision_conflict` | Revisão esperada difere da atual | Preservar pedido original e apresentar resolução/rebase. |
| `rejected` / código específico | Regra, prova ou autorização inválida | Preservar rejeição; não conceder resultado localmente. |

Respostas `applied/noop` não têm código de erro; conflitos/rejeições têm código. Mensagens de resposta com versões/regras desconhecidas são rejeitadas antes de substituir o cache.

## Idempotência e transação

- O journal é por jogador/`request_id` e guarda o digest do pedido inteiro, inclusive revisão esperada.
- Mesmo ID com mesmo conteúdo retorna o resultado original, inclusive após restaurar o journal. Mesmo ID com outro conteúdo/revisão retorna `idempotency_conflict`.
- Concluir novamente uma fase já possuída, com outro pedido válido, é `noop`. Não acrescenta conquista, desbloqueio ou entrada de evidência.
- Evidência e tentativa já consumidas não autorizam outra fase. O verificador deve vincular tentativa a jogador, fase, prazo e condições de conclusão, incluindo saída e chefe final.
- A referência serializa transições com lock e exporta estado+journal+ledger juntos. Na implantação Supabase, substituir essa serialização por uma transação durável e restrições de unicidade, incluindo concessão de `desert_campaign_completed` e `el_fuego` na mesma transação.

Não criar uma função remota que aceite `completed_phase_ids`, `achievement_ids` ou `unlocked_character_ids` do cliente como estado verdadeiro. RLS limita propriedade; não comprova vitória.

## Conflito local/remoto

1. Manter `local_state` como progresso offline provisório. Não fazer união de desbloqueios com o servidor, mesmo que o save local alegue dez fases.
2. `server_cache` no disco é só cache. `ClientSession` começa sem snapshot autenticado em memória. Para habilitar o modo online, o adaptador deve validar a origem autenticada da resposta e o jogador correspondente.
3. Comparar revisões apenas entre snapshots autenticados da sessão. Um cache local com revisão forjada muito alta não bloqueia a primeira resposta autêntica.
4. Uma resposta atrasada não regride o estado atual, mas seu resultado idempotente pode confirmar um pedido antigo conhecido.
5. Mesma revisão com outro conteúdo é erro. Uma revisão superior não pode retirar conclusões verificadas neste protocolo. Reset/admin rollback exigiria outra operação/época/versionamento, não uma mescla silenciosa.
6. Em conflito, `rebase_request(old_id, new_id)` exige snapshot autenticado recente e revalida se a intenção ainda faz sentido. Usa outro ID e preserva o pedido antigo como `superseded`. Nunca mudar o payload de um retry sob o mesmo ID.
7. Pedidos rejeitados, aplicados ou em estado desconhecido não são rebaseados automaticamente. Rejeições e conflitos ficam na outbox para diagnóstico; uma nova ação deve ter ID novo.

O modo offline de referência pode demonstrar a progressão completa com skin provisória, mas não escreve concessões definitivas em uma conta. Para usar cache confiável durante uma sessão online sem rede, seria necessária uma política adicional de snapshots assinados/verificação offline; checksum local sozinho não fornece isso e essa funcionalidade não foi implementada.

## Adaptadores ainda necessários

`completion_verifier(request, state)` é código confiável do servidor e retorna `VerifiedCompletion` somente após validar evidência independente. O default é negar conclusão. `authenticated_decoder(payload)` pertence ao transporte autenticado do cliente e devolve identidade + documento validado; nunca deve simplesmente ler um save local e chamá-lo de resposta autenticada.

Os dublês dos testes emitem documentos/evidências sintéticos. Não são uma implementação de autenticação, de anti-cheat ou de comprovação de gameplay. TTL de tentativas, persistência transacional, RLS, retenção do journal e implantação devem ser definidos/testados no serviço real, em outra tarefa.
