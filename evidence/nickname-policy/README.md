# Nickname obrigatório — 05/11/2026

Cliente Godot 4.7.2. Capturas reais do motor; conta e respostas do serviço são
fixtures locais explicitamente identificadas no teste. Nenhum acesso ao Supabase.

| Verificação | Resultado |
|---|---|
| `tests/nickname_onboarding/flow_test.gd` | 37 verificações, failures=0 em desktop e nos dois perfis iPhone abaixo |
| `tests/t18_auth/flow_test.gd` | 20 verificações, failures=0; HTTP simulado |
| `tests/duel_local/flow_test.gd` | 87 verificações; modo local preservado |
| `tests/iphone/layout_guard.gd --iphone` | 504 verificações, failures=0 nos nove modelos |
| `python3 tools/player_ui/check_design.py` | OK |
| `node tests/web_pwa/sw_test.js` | 29 verificações, failures=0 |
| Export Web release 4.7.2 / web_nothreads | Concluído sem erros de importação/scripts/exportação |
| Chromium Web real, UA iPhone, DPR 3 | Abertura e convidado passaram; canvas CSS 720×353 dentro de 844×390 |

O teste cobre `null`, espaços, placeholders, controle/invisíveis, limites de tamanho,
conflito informado pelo servidor simulado, confirmação duplicada, trava do serviço,
remoção dos editores de Perfil/Ajustes, estado carregando, troca de conta durante
requisição e convidado sem cadastro. Tab permanece no formulário obrigatório.

| Tela | Desktop 1672×941 | iPhone 844×390 | iPhone 640×360 |
|---|---|---|---|
| Cadastro | [ver](1672x941_cadastro.png) | [ver](844x390_cadastro.png) | [ver](640x360_cadastro.png) |
| Perfil | [ver](1672x941_perfil.png) | [ver](844x390_perfil.png) | [ver](640x360_perfil.png) |
| Ajustes | [ver](1672x941_ajustes.png) | [ver](844x390_ajustes.png) | [ver](640x360_ajustes.png) |
| Perfil carregando | [ver](1672x941_carregando.png) | [ver](844x390_carregando.png) | [ver](640x360_carregando.png) |

Estes testes **não provam unicidade global nem bloqueio de renomeação no banco**.
Isso depende das constraints, RLS e RPCs do backend, que não foram consultadas ou
alteradas pelo Codex. Não houve teste em iPhone físico, Safari real nem login real
Google/Discord nesta entrega. O smoke Web cobre abertura e convidado, com todas
as solicitações externas bloqueadas; a conta obrigatória foi exercitada nas fixtures nativas.

[Prompt completo para o responsável pelo Supabase](../../docs/backend/PENDENCIAS_2026_11_05.md).
