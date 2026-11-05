# Revisão isolada do teto reprovado

Branch `codex/revisao-telhado`, baseada em `b38f356`. **Não publicada na main.**

A versão anterior desenhava dois planos coincidentes no piso da fase 2: laje genérica e cobertura. Essa sobreposição causava faixas/tremulação. A fase 2 agora tem uma só cobertura, uma cornija frontal e faces planas; o material usa sandstone.png repetível em vez do atlas da fachada. As cores dos materiais novos são convertidas de sRGB e sem brilho especular forte.

O obstáculo suspenso sobre postes virou um volume de telhado fechado, apoiado na laje, com alvenaria nas faces e telhas de barro em duas inclinações. O centro continua percorrível. A colisão convexa acompanha as inclinações visíveis, inclusive quando o objeto cruza limites de trechos. A posição deixa espaço para aterrissar antes do vão seguinte.

Não altera controles, poderes, inimigos, tarefas, outras fases ou backend. Sem novos assets externos. Os novos detalhes de telhas são geometria simples agrupada por material.

Capturas gráficas reais em Godot 4.7.2 Compatibility/Mesa, com aproximação por fixture e corrida física sobre o objeto: `iphone/` 844×390, `desktop/` 1672×941 e `640/` 640×360. JPGs convertidos sem recorte. São prévias para revisão estética, sem validação em iPhone físico ou navegador nesta rodada.

- Percurso completo fase 2: PASS, sem mortes. O autopiloto foi atualizado para consultar a altura inclinada real; mantém as verificações de morte, saída, tempo e checkpoints.
- `roof_surface_test.gd`: 56/56 raios confirmam que a colisão acompanha o teto.
- `check_design.py`, `scope_test.py --base b38f356` e `git diff --check`: PASS.

O primeiro percurso do protótipo falhou perto do fim: foi ampliada a área de aterrissagem e corrigida a consulta do autopiloto, que ainda assumia um teto plano. A nova travessia passou. A aprovação visual cabe ao proprietário.
