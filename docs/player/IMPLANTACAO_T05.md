# Tarefa 05 — relatório consolidado de encerramento

## Resultado efetivo

**Produção ainda não implantada.** O critério de liberação exige testes com JWT real de dois usuários; esses testes estão bloqueados por limite de envio de e-mail do Supabase Auth. Esta entrega inclui implementação aplicada no projeto isolado, não apenas planejamento.

- Projeto principal confirmado: `xgmlphejalzakucllsmw`.
- Projeto isolado criado na mesma organização: `ifomrkzmxgwwjapoeklo`, nome `qse-v3-tarefa05-validation`, PostgreSQL 17.11.0.003, ACTIVE_HEALTHY.
- Continuação e encerramento a partir de `work/backend-supabase-05`, commit `e89a1dd32d427d5fdb2d54741730eb9f6c1b4dc9`. Nenhuma migration ou teste aprovado foi refeito.
- Base de código: `codex/telas-sistemas-jogador-03`, commit `e7ac72db03e753e5dc1f24c802f6cfc332f23802`.
- Nenhuma cena, gameplay, câmera, modelo ou serviço Godot alterado.
- Branches Supabase indisponíveis no plano atual; o projeto isolado separado foi a alternativa aceita.
- Nenhum segredo administrativo foi solicitado ou recuperado. Os testes HTTP usam apenas chave publicável e, quando houver login, JWT de usuário.

## Alterações implementadas

1. Migration 0001: revoga EXECUTE de PUBLIC, anon e authenticated em `public.rls_auto_enable()`, se existente, preservando a função/event trigger. Restringe schema privado, privilégios padrão, tabelas, sequências e helpers. Reaplica somente as permissões de leitura previstas.
2. Migration 0002: valida o limite bigint de `p_before` antes do cast; valores maiores que 9223372036854775807 retornam `invalid_cursor`. Revoga ACLs de PUBLIC/anon/authenticated antes de conceder EXECUTE explícito para authenticated nas onze RPCs.
3. Migration 0003: remove EXECUTE de anon no helper de presença e sinaliza pré-condição de ativação. **Não aplicada**, porque configuração de canais privados e política de revogação ainda não foram validadas.
4. Harness HTTP `tests/test_backend_http.py`: implementa login, refresh/logout, perfil, carteira zero, RLS por JWT via probe invoker de staging, amizade, equipamento e negação de conclusão sem prova. Interrompe em falha e registra apenas casos efetivamente executados.
5. `supabase/tests/t05_stage_rls_probe.sql`: diagnóstico SECURITY INVOKER exclusivo de staging; não é parte da API de produção. Não aplicar no projeto principal.
6. `.runtime/` ignorado no Git; credenciais temporárias não integram o commit.

## Migrations efetivamente aplicadas

| Destino | Versão registrada pelo Supabase | Nome |
|---|---|---|
| Isolado | 20261028160419 | 202610280001_player_foundation |
| Isolado | 20261028160612 | 202610280002_player_api |
| Isolado | 20261028161212 | t05_stage_only_rls_probe |
| Principal | nenhuma | Nenhuma migration desta tarefa aplicada |

O conector atribui timestamp próprio ao histórico; os nomes preservam a referência aos arquivos. Não confundir o timestamp registrado com o prefixo original do arquivo. A migration propositalmente inválida de recuperação falhou e não consta no histórico.

## Tabelas implantadas — somente ambiente isolado

Todas as 16 tabelas em `qse_v3` têm RLS habilitado:

- character_catalog
- desert_phases
- player_profiles
- account_preferences
- player_statistics
- campaign_progress
- completion_evidence
- phase_completions
- player_achievements
- character_unlocks
- player_loadout
- friendships
- friend_requests
- processed_requests
- wallets
- wallet_transactions

O catálogo contém cowboy, michelly, rodrigo, lorena, gus, lana, halloween e el_fuego. As dez fases do Deserto foram cadastradas. El Fuego continua vinculado a desert_campaign_completed; não há produtor de provas, recompensas ativadas ou crédito arbitrário ao cliente.

## RPCs instaladas no isolado

`qse_profile_self`, `qse_profile_update`, `qse_account_preferences`, `qse_profile_public`, `qse_find_players`, `qse_friends`, `qse_friend_action`, `qse_wallet`, `qse_wallet_history`, `qse_progression_snapshot`, `qse_progression_command`.

Nomes, parâmetros e formatos de resposta existentes preservados. Não foi criada API concorrente. O probe de staging é apenas teste, com SECURITY INVOKER e identidade JWT, e nunca deve acompanhar o deploy principal.

## Testes executados e limites

| Verificação | Resultado efetivo |
|---|---|
| 0001 e 0002 no Supabase isolado | Aplicadas com sucesso |
| Tabelas/RLS | 16/16 |
| ACL das 11 RPCs | anon sem EXECUTE; authenticated com EXECUTE |
| Helper ensure_player | authenticated sem EXECUTE |
| rls_auto_enable | anon sem EXECUTE no ambiente isolado |
| Catálogo | 8 IDs corretos |
| Auth settings por HTTP | E-mail habilitado, signup habilitado, confirmação exigida, login anônimo desabilitado |
| HTTP sem JWT nas 11 RPCs | 11/11 negadas com HTTP 401/403 |
| Cursor overflow 9223372036854775808 | invalid_cursor |
| Cursor máximo bigint | histórico vazio válido |
| Cursor malformado | invalid_cursor |
| Recuperação por savepoint | Alteração temporária de checkpoints desfeita; baseline confirmado |
| Falha controlada de migration | Divisão por zero; CREATE TABLE revertido; objeto ausente após falha |
| Compilação Python | py_compile passou |
| Cadastro com endereços fictícios | Rejeitado: email_address_invalid; nenhuma conta criada |
| Cadastro dos 2 e-mails de teste informados pelo usuário | HTTP 429 over_email_send_rate_limit; nenhuma conta criada |
| Login real da conta A | Falhou; conta não foi criada |
| Casos autenticados A/B subsequentes | Não executados; harness interrompeu no login |
| Auth e gameplay no Godot | Não executados |
| Restauração de backup/PITR | Não executada; testes transacionais não comprovam recuperação de desastre |

A verificação SQL do cursor foi executada sob `SET LOCAL ROLE authenticated`, sem BYPASSRLS, com subject de teste. Isso **não** foi apresentado como validação de JWT real ou isolamento A/B com dados existentes.

O teste inicial de savepoint tentou um valor de catálogo proibido e foi corretamente recusado por CHECK; depois foi feito teste válido em checkpoints, com restauração confirmada. Nenhuma dessas alterações foi persistida.

Advisors de segurança no isolado: quatro INFO de RLS sem policy em catálogos/provas/journal (negação intencional ao cliente) e onze WARN de RPCs SECURITY DEFINER executáveis por authenticated (superfície intencional, sujeita a testes de identidade). Nenhuma exposição anônima dessas RPCs foi encontrada. Não remover esses controles para silenciar advisors.

## Bloqueio concreto de Auth

O cadastro normal retornou `429 over_email_send_rate_limit` para ambos os e-mails fornecidos. As consultas seguintes confirmaram zero usuários no projeto isolado. Não houve JWT emitido no fluxo testado.

Uma tentativa de criar fixtures diretamente em auth.users/auth.identities foi bloqueada pela revisão automática: contornaria o fluxo oficial de Auth por uma operação privilegiada não aprovada especificamente. **Essa inserção não foi executada**, e não foi contornada por outro caminho.

As tentativas de cadastro foram encerradas após o 429. Por instrução do usuário, não haverá novas tentativas nesta etapa, mudanças de segurança, acesso ao painel pelo navegador ou inserções nas tabelas internas de Auth. O projeto isolado e as migrations já aplicadas permanecem preservados.

## Funcionalidades e prontidão

| Sistema | Situação |
|---|---|
| Cadastro/login | Endpoints reais acessíveis; criação de contas bloqueada pela quota de e-mail |
| Perfil/nickname | SQL/RPCs instalados em staging; teste autenticado pendente |
| Carteira/histórico | SQL/RPCs instalados; cursor corrigido; validação por usuário real pendente |
| Inventário/equipamento | Catálogo e regras instalados; prova por JWT pendente |
| Amizades/busca | SQL/RPCs instalados; fluxo A/B pendente |
| Progresso/checkpoints | Estrutura instalada em staging; fluxo autenticado pendente |
| Conclusão/desbloqueio de El Fuego | Mantido fechado sem prova confiável |
| Economia/recompensas | Nenhuma recompensa ou crédito real ativado |
| Presença | Desativada; 0003 não aplicada |
| Produção | Intacta, aguardando gate de testes reais |

## Instruções para Codex e Claude

Não alterar as interfaces de `scripts/services/`. Os contratos continuam em `data/ui/api.json`, `data/ui/services.schema.json` e `data/progression/contract.v2.schema.json`.

A configuração pública do projeto principal, **para usar somente após o deploy e a validação**, é:

```json
{
  "url": "https://xgmlphejalzakucllsmw.supabase.co",
  "publishable_key": "sb_publishable_qu2EVZZwYGsgjl1hhZpl6g_Yro17P79",
  "persist_session": false
}
```

Essa chave é publicável e visível no cliente por definição; não é credencial administrativa. Pode ser fornecida pela variável `QSE_SUPABASE_PUBLISHABLE_KEY`, pelo `user://backend.cfg` ou `QSE_PUBLIC_CONFIG.publishable_key` no Web, conforme BACKEND.md. Não fornecer service_role/secret.

A chave/URL principal acima **ainda não tornam o backend operacional**, pois as migrations não foram aplicadas nesse destino. O cliente atualmente valida a URL principal e não deve ser redirecionado silenciosamente ao projeto de testes.

Preservar números econômicos como strings; profile_public pode retornar {}; owner vem de auth.uid(); não enviar UUID do dono nas operações. Reenvios idênticos usam o mesmo request_id. Equipamento usa snapshot v2; nenhuma união de desbloqueios offline.

A presença mostrará indisponibilidade enquanto a autorização não estiver ativada. Não inventar estado online. A UI existente pode tentar abrir canais, mas não existem policies de presença autorizadoras no backend implantado.

## Verificações finais sem sessão

Nesta continuação foram executados somente três testes adicionais HTTP no projeto isolado, sem cadastro, login ou escrita no banco:

| Caso | Resposta observada | Resultado |
|---|---|---|
| JWT malformado em qse_wallet | HTTP 401, PGRST301 | Aprovado |
| Tentativa de selecionar qse_v3 via Accept-Profile | HTTP 406, PGRST106 | Schema privado não exposto |
| Tentativa de chamar post_wallet_entry como RPC pública | HTTP 404, PGRST202 | Ledger privado não exposto |

Total consolidado: **15 verificações HTTP sem sessão aprovadas** — 12 anteriores preservadas, sem repetição, e 3 adicionais. Essas verificações não substituem login, isolamento A/B com dados ou execução com JWT real. A compilação Python do novo teste passou. Nenhum teste autenticado foi reexecutado.

Evidências sanitizadas: `docs/player/evidence/T05_TEST_RESULTS.json`. A/B com JWT está explicitamente PENDENTE; o teste anterior de login interrompido continua registrado sem ser transformado em aprovação.

## Procedimento de retomada — API oficial, após a quota permitir

1. Retomar somente mediante nova solicitação; confirmar o fim do limite de envio sem loops automáticos. Se houver Retry-After, respeitá-lo. Não alterar confirmação de e-mail nem políticas para contornar o 429.
2. Usar o projeto isolado `ifomrkzmxgwwjapoeklo` e sua chave publicável, nunca credenciais administrativas. Reutilizar a implementação e as migrations existentes; não reaplicá-las.
3. Consultar o estado das contas de teste antes de cadastrar, para evitar duplicação. Os dois e-mails já foram fornecidos pelo usuário; credenciais temporárias ficam apenas no arquivo local ignorado `.runtime/stage.json`.
4. Para contas ainda inexistentes, usar `POST /auth/v1/signup` com e-mail/senha. Encerrar imediatamente em novo 429 e registrar a resposta sem tokens ou senhas. Confirmar o e-mail pelo fluxo oficial quando exigido.
5. Fazer login via `POST /auth/v1/token?grant_type=password`. Somente um JWT emitido pelo Auth com role authenticated habilita o teste A/B. Não forjar JWT nem inserir usuários por SQL.
6. Com as duas contas confirmadas, executar `python3 tests/test_backend_http.py --phase authenticated` na branch de backend. O arquivo `.runtime/stage.json` deve conter `url`, `key` publicável e `users.a/users.b` com e-mail/senha das contas de teste. O runner exige a URL isolada e não pode usar o principal. Não publicar o arquivo de credenciais.
7. O runner valida identidade, perfil/nickname, carteira zero, privacidade do schema, RLS por probe SECURITY INVOKER, amizades, equipamento, conclusão sem prova, refresh/logout. Registrar somente os casos efetivamente executados; não transformar casos bloqueados em aprovados.
8. Preservar os 12 resultados HTTP sem login já aprovados; não repetí-los sem nova mudança/falha que o justifique.
9. Produção permanece bloqueada até os testes com usuários reais e a verificação de recuperação necessária. Não aplicar o probe, bootstrap_local.sql ou migration 0003 no principal. Presença e verificador de fases permanecem pendências separadas.

## Encerramento da Tarefa 05

Entrega encerrada com implantação **somente no projeto isolado** e testes autenticados pendentes. Não há backend de produção liberado. Nenhuma nova pergunta ou ação de cadastro faz parte deste encerramento. O projeto principal `xgmlphejalzakucllsmw` não recebeu migrations desta tarefa.
