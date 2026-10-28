# Testes reais

Executar `python3 tools/godot/run_smoke.py --godot /caminho/Godot_v4.7.2-stable_linux.x86_64 --output /tmp/qse-smoke`.

Validado no Godot oficial 4.7.2.stable.official.ed1daf0bf: 22 casos finais aprovados (importação, dez fases, nove transições, teste funcional com 12 verificações e menu com oito rotas abertas/fechadas). Evidências em `tests/godot_evidence_472`; preservados os resultados anteriores 4.6.3. O teste funcional foi repetido após corrigir sua preparação de dano fatal; primeira tentativa preservada separadamente.

Corrigidos recuo de dano anulado pela movimentação e reinício sobre inimigos, com proteção temporária ao reaparecer. Sem alteração de assets, iluminação, Supabase, autenticação ou economia. Aparência, animações vistas em tela e balanceamento completo ainda exigem editor.

Workflow oficial 4.7.2 acionado por push nesta branch e manualmente, sem fallback de versão. A chamada direta e consulta pela API de Actions retornam Forbidden neste ambiente; aprovação local não deve ser confundida com resultado remoto.
