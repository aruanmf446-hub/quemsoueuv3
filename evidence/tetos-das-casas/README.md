# Fase 2 — pisar nos tetos das próprias casas

Implementação após a confirmação explícita do proprietário: eliminar a faixa contínua de chão sobre as casas e saltar de um prédio para outro.

**Branch de revisão `codex/tetos-das-casas`, sem publicação na main.** Base: `b38f356`. A proposta anterior de cobertura com telhas permanece somente no histórico de outra branch e não compõe esta versão.

## O que mudou

- Cada superfície do mapa corresponde a uma casa inteira, preservando a proporção da arte aprovada. Usa casa residencial e casa com varanda existentes.
- O piso físico coincide com o teto já desenhado na casa, com compensação da projeção da câmera. A arte é recortada somente nos limites de trechos/partes rompíveis, sem repetir faixas da fachada para montar uma pista.
- Removidos da fase 2 o tablado contínuo, a testeira adicional, cornijas artificiais, coberturas extras e obstáculos apoiados sobre outro chão. Os vãos ficam entre casas separadas.
- 120 casas ao longo da mesma distância. Alturas diferentes, sete checkpoints, duas tarefas e tempo mínimo de campanha mantidos. A frequência física de guardas/recargas foi preservada: dez casas por encontro (antes seis módulos compridos), cinco casas por recarga (antes três).
- Protagonista, saltos, combate, poderes e demais fases preservados. Sem novos assets, alterações de backend ou redução de resolução.

## Evidência

Capturas gráficas reais do Godot 4.7.2 Compatibility, Mesa/llvmpipe. Aproximação por fixture; o ator pousa por física no teto. Os manifestos registram `on_floor=true`. Não são testes em aparelho físico ou navegador nesta rodada.

- [Casa inteira e teto jogável](iphone/casa_00.jpg).
- [Vão entre duas casas](iphone/casa_01.jpg).
- Quatro capturas em cada perfil: 844×390 iPhone emulado, 1672×941 desktop e 640×360 padrão. JPGs convertidos dos PNGs sem recorte.

## Validação

- Percurso completo fase 2: PASS, sem mortes, sete checkpoints e saída por comandos reais, sem teleporte ou invulnerabilidade.
- `reino10`: PASS.
- `skyline_roofs_test.gd`: 75/75. Agora exige casas jogáveis e ausência das coberturas/faixas rejeitadas; mantém vãos físicos e preservação do fundo.
- `parkour_revision_test.gd`: 52/52. Expectativa da fase 2 atualizada para teto da própria casa, sem obstáculo extra; preservados os testes de ponte, queda, recursos e descarregamento.
- `scenario_tasks_test.gd`: 177/177. As 19 tarefas continuam funcionais, incluindo as duas da fase 2, com ida/volta e custo zero.
- `check_design.py`, `scope_test.py --base b38f356` e `git diff --check`: PASS.
- Probe Web preparado para exigir tetos das casas em lugar de `City_roof`/terraços extras. Ainda não executado no navegador para esta versão.

Os avisos de recursos de áudio ativos ao encerrar testes são preservados nos logs. Nenhum teste foi removido; expectativas visuais antigas foram substituídas pelo requisito confirmado nesta revisão. Aprovação estética pendente do proprietário.
