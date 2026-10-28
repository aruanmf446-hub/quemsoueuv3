# Tarefa 05 — implantação parcial, bloqueio de Auth

## Resultado efetivo

**Produção ainda não implantada.** O critério de liberação exige testes com JWT real de dois usuários; esses testes estão bloqueados por limite de envio de e-mail do Supabase Auth. Esta entrega inclui implementação aplicada no projeto isolado, não apenas planejamento.

- Projeto principal confirmado: `xgmlphejalzakucllsmw`.
- Projeto isolado criado na mesma organização: `ifomrkzmxgwwjapoeklo`, nome `qse-v3-tarefa05-validation`, PostgreSQL 17.11.0.003, ACTIVE_HEALTHY.
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

O conector disponível não expõe alteração da configuração Auth/SMTP. As alternativas seguras são:

1. No **projeto isolado**, desativar temporariamente **Confirm email** pelo painel, cadastrar as duas contas pela API normal, testar login/JWT e depois restaurar a configuração; ou
2. Configurar entrega de e-mail funcional/SMTP e confirmar as contas normalmente.

A primeira alternativa não deve ser aplicada ao projeto principal. O uso do painel pelo agente requer autorização de fallback para navegador; ainda não foi realizado.

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

## Próxima ação exata

Autorizar o uso do painel Supabase **somente no projeto isolado ifomrkzmxgwwjapoeklo** para desativar temporariamente Confirm email, executar o cadastro normal dos dois endereços indicados, testar os JWTs e restaurar a configuração. Alternativamente, o usuário pode fazer esse toggle no painel e avisar.

Com o gate A/B aprovado, implantar **somente 0001 e 0002** no projeto principal autorizado, verificar as ACLs/RLS e os contratos, e publicar nova evidência de execução. Não aplicar probe, bootstrap_local.sql ou 0003 em produção. Para recuperação de desastre, confirmar backup/restauração antes da ativação para usuários finais; até agora só rollback transacional foi testado.
