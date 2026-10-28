# Testes reais

Executar `python3 tools/godot/run_smoke.py --godot godot --output /tmp/qse-smoke`.
O runner importa recursos, abre dez fases por 30 quadros físicos, executa nove transições e abre/fecha as oito telas pelo menu. Cada caso roda um processo real; qualquer ERROR do motor reprova, inclusive com exit code zero.

Executado localmente no Godot oficial 4.6.3: 21/21 casos aprovados, incluindo importação, dez fases, nove transições e menu com oito rotas. Evidências em `tests/godot_evidence_t08`. Não são testes visuais, de campanha completa, combate ou balanceamento.

O workflow manual usa a distribuição oficial exata 4.7.2, sem fallback, e publica os logs como artefato. Essa versão não está instalada aqui; sua consulta/download ficou bloqueada por HTTP 403 do proxy. A execução 4.7.2 permanece pendente; não foi iniciada execução paga ou remota de Actions.
