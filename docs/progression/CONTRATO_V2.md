# Contrato de progressão v2 — referência normativa

Versões desta entrega: `schema_version=2` nos saves/estados; `protocol_version=2` nas mensagens; `rules_version=desert_progression_2.0.0`; migração `legacy_to_local_save_2.0.0`. O schema executável é [contract.v2.schema.json](../../data/progression/contract.v2.schema.json). Os contratos v1 da entrega anterior permanecem como histórico e não foram reescritos.

O contrato é definitivo **para esta versão da implementação isolada**. Não representa um serviço implantado ou autorização de conta. O runtime Godot continua inalterado.

## Conteúdo e personagens

As regras em [rules.v2.json](../../data/progression/rules.v2.json) fixam por SHA-256 as fontes anteriores de catálogo, campanha, fases e schema v1. Alterar essas fontes exige revisar a versão das regras e a compatibilidade, em vez de mudar silenciosamente um save existente.

| Classificação primária | IDs nesta versão | Regra |
| --- | --- | --- |
| `playable_hero` | `cowboy`, `michelly`, `rodrigo`, `lorena`, `gus`, `lana`, `halloween` | Sete heróis iniciais equipáveis. |
| `unlockable_hero` | `el_fuego` | Bloqueado no lobby até concluir as dez fases; protagonista em todas elas desde o início. |
| `common_enemy` | `cactus` | Tropa inimiga do Deserto, não equipável. |
| `miniboss` | Nenhum cadastrado | Categoria explícita, sem inventar personagem. |
| `final_boss` | `malagueta` | Chefe final da fase 10, não equipável. |
| `campaign_only_character` | Nenhum herói/NPC cadastrado | Categoria reservada, sem skin automática. |

Cactus e Malagueta também têm escopo `campaign_only`. Classificação é o papel; escopo é onde o personagem pode existir. El Fuego não é permanentemente exclusivo da campanha: após a conquista também pode ser equipado no lobby. Sua autorização como protagonista não consulta o desbloqueio de skin nem o personagem equipado.

## Estado de progressão

`state` contém dono (`player_id` UUID), versões, revisão, lista de fases concluídas, fase ativa, checkpoint opcional, conquistas, IDs desbloqueados e equipado. Não contém moedas, preços, XP ou parâmetros de gameplay.

Invariantes obrigatórios:

1. `completed_phase_ids` é um prefixo ordenado, sem duplicações, de `desert_phase_01` a `desert_phase_10`.
2. Estão acessíveis as fases já concluídas e a próxima. Não é permitido iniciar/concluir uma fase bloqueada. Repetir uma fase concluída não repete recompensa.
3. Antes da primeira conclusão, somente a fase 1 está acessível. Concluir a fase 9 apenas libera acesso à fase 10.
4. Concluir uma fase nova requer que ela tenha sido iniciada. Checkpoint nunca é conclusão. Repetir o mesmo início/checkpoint sem mudança é `noop`.
5. O checkpoint deve pertencer à fase ativa e ao conjunto de IDs planejados dessa fase. Não há coordenadas, teleporte ou instância de cena na biblioteca.
6. Concluir a fase limpa a fase ativa e seu checkpoint. Reabrir a mesma fase ativa preserva o checkpoint; mudar a fase ativa limpa o checkpoint anterior. Há um checkpoint ativo por estado.
7. Só o prefixo completo de dez fases gera `desert_campaign_completed` e acrescenta `el_fuego` aos sete IDs iniciais. A fase 10 exige também a condição de Malagueta e a saída/conclusão verificada no fluxo servidor.
8. Equipamento deve ser um herói liberado. Inimigos, minichefes, chefes e personagens exclusivos de campanha nunca são promovidos automaticamente a skins.
9. A revisão cresce uma vez por transição efetiva, inclusive início, checkpoint e equipamento; `noop` não incrementa revisão. Listas de conclusões/conquistas/desbloqueios não duplicam entradas.

O redutor puro calcula essas relações, sem comprovar eventos de jogo. Em `offline_reference`, seus resultados são **provisórios**. Um cliente não pode transformar a saída do redutor em desbloqueio definitivo online.

## Envelope local

`save` separa quatro compartimentos:

- `local_state`: progresso provisório da referência offline.
- `server_cache`: cópia persistida de um estado de servidor, tratada como **não autenticada ao abrir o save**.
- `outbox`: pedidos e seus estados, incluindo conflitos/rejeições/substituições; não contém uma API para conceder recompensa.
- `migration_receipt`: origem, hashes, alegações e equipamento anterior, preservados para revisão.

`local_revision` é a revisão do envelope; `state.revision` é a revisão do domínio. Não comparar esses contadores entre si. A autoridade vem do contexto de execução/transporte, nunca de um campo `trusted`, `authority` ou `verified` editável no arquivo.

No modo `online_authoritative`, `ClientSession.effective_state()` exige uma resposta validada pelo adaptador autenticado da sessão atual. Reabrir um save não restaura essa confiança. Local e remoto não são combinados por união de conquistas/desbloqueios.

## Comandos do domínio

| Operação | Entrada específica | Resultado |
| --- | --- | --- |
| `start_phase` | `phase_id` | Valida acesso sequencial; ativa a fase. |
| `record_checkpoint` | `phase_id`, `checkpoint_id` | Valida checkpoint planejado da fase ativa. |
| `complete_phase` | `phase_id`; no protocolo também `attempt_id`, `evidence_id` | Valida sequência; servidor exige verificador de conclusão independente. |
| `equip_character` | `character_id` | Exige herói liberado no estado autoritativo. |

O comando online não recebe dono, recompensa, flags, conquistas ou uma alegação de derrota do chefe. `authenticated_player_id` chega ao servidor por contexto de autenticação, fora do JSON enviado pelo cliente.

## Integridade e codificação

O envelope inclui SHA-256 do JSON canônico sem o campo `integrity` inteiro. Isso detecta corrupção acidental; alguém que edite um arquivo pode recalcular o hash. **Checksum não é assinatura nem autenticação.**

Codificação da referência: UTF-8 sem BOM, chaves de objetos ordenadas recursivamente por ponto de código, arrays na ordem original, JSON compacto sem espaços externos, strings Unicode sem escape ASCII desnecessário. Inteiros representados como `1.0` são normalizados a `1`; números fracionários/não finitos não são admitidos. Revisões ficam entre 0 e `9007199254740991`, para interoperabilidade JSON. O transporte futuro deve reproduzir essa normalização ou usar o resultado canônico produzido pelo servidor.

Chaves JSON duplicadas, versões futuras, campos desconhecidos, estado semanticamente contraditório ou checksum divergente são rejeitados. Nunca substituir silenciosamente um save ilegível por progresso novo.

## Fronteira de confiança do servidor de referência

`ServerReference` é um componente em memória sem rede. Por padrão, nega conclusões: `completion_verifier=None`. Para aceitar uma conclusão nova, um adaptador **do servidor** deve fornecer `VerifiedCompletion` com jogador/fase/tentativa/evidência correspondentes, saída confirmada e, na fase 10, derrota de Malagueta. Tentativa/evidência consumidas não podem conceder outra fase.

O verificador é uma dependência obrigatória da integração real. Os dublês em `tests/helpers.py` apenas simulam uma verificação concluída; não comprovam gameplay e não podem ser usados em produção.

O journal e o ledger exportados em `server_reference_store` destinam-se a armazenamento controlado pelo servidor, não a upload de save pelo cliente. A referência usa lock para serializar transições; uma integração Supabase deve persistir estado, prova consumida e journal na mesma transação de banco. Não há tal banco ou serviço nesta entrega.
