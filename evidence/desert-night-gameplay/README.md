# Evidências — revisão de jogabilidade (fases 01–09)

Todas as imagens vêm do framebuffer do Godot oficial 4.7.2 (Compatibility,
Mesa/llvmpipe em Xvfb). Não há montagem nem edição além da otimização PNG sem perdas.

- `percurso_real_*`: capturas tiradas durante o percurso completo da fase 01,
  feito somente por entradas desde o spawn (`route.gd`), em 1920×1080 e 844×390.
- `faseNN_<resolução>_*`: fixtures de `inspect.gd`. O jogador é reposicionado
  para chegar a cada situação: corrida, golpe, dano, aproximação e borda do
  buraco, salto sobre o vão, morte por queda, reinício e conclusão. Elas avaliam
  aparência, não percurso. O golpe foi capturado em câmera lenta (`time_scale` 0,2).
- `*_strip_*`: sequências recortadas em volta do personagem, em ordem temporal.
- `fixture_*`: pausa e fase 02 liberada no menu, vindas das fixtures de regras e navegação.
- `routes.json`: percursos das nove fases com passo físico fixo; `qa_results.json`:
  as 23 etapas do runner; `logs/`: saídas de `feel_test` e `rules`.
