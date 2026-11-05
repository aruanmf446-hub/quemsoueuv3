# Compatibilidade do cliente com a PR #99

PR inspecionada: `83e707b`; base do cliente: `cb3bfc4`.
Godot 4.7.2 oficial, execução headless, respostas de perfil simuladas e sem rede.

- A regressão de Unicode NFC reproduziu um falso erro na comparação anterior.
- Após o ajuste: `tests/nickname_onboarding/flow_test.gd`, **40 verificações,
  failures=0**; inclui perfil confirmado em NFC, trava, proprietário da sessão,
  confirmação duplicada, convidado e mensagem `nickname_required` do duelo.
- `python3 tools/player_ui/check_design.py`: OK.
- `git diff --check`: OK.

Sem alteração de layout ou assets. Não foram refeitas capturas do motor nem
exportação nesta revisão, pois a alteração funcional é a condição de confirmação
da resposta. Não houve teste de servidor real, OAuth, concorrência entre JWTs,
partida online ou chat entre dois clientes. Nenhuma migration ou Edge Function
foi alterada, mesclada ou publicada por este ajuste.
