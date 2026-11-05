# Evidências do Reino V3

- `verified_regressions/`: 14 etapas aprovadas no estado final dos cenários/HUD:
  mecânicas84/0, controles10/0, layout, legado10, progresso, regras desktop/toque,
  variedade, parkour, checkpoints e travessias01/03/06/09.
- `routes_after_physical_refinements/`: nove percursos completos sem morte/respawn,
  após separar itens e peças rompíveis. Últimos detalhes visuais/HUD foram conferidos
  novamente nas quatro travessias acima. Logs registram diferenças entre quadros e física.
- `final_gallery/`: 54 JPEGs de capturas reais sem recorte, três perfis × nove fases
  × dois pontos. O distrito5 usa teleporte de fixture e ator parado explicitamente;
  não demonstra vitória nem jogabilidade. Auditoria de limites de status/pausa: zero falhas.
- `web_final/`: WebAssembly4.7.2, Chromium com UA iPhone844×390/DPR3, oito cenas por
  toque, leitura sem avanço automático, dash, preferência de leitura e descobertas
  conservadas após reload. Hosts externos bloqueados; não houve chamadas ao backend.
- `duel_regressions/`: duelo local e revelação de batalha aprovados.
- `battle_iphone/`: captura real de partida local cinco jogadores,750×353; não é partida online.
- `iphone_guard.log`: nove modelos,504 verificações,zero falhas. Houve falha transitória
  anterior no SE; repetição isolada e rodada completa passaram.
- `iphone_models/`:108 capturas nativas das telas internas,12por modelo.
- `pwa29.log`:29 verificações,zero falhas,incluindo ocultar/restaurar convite de instalação.

Histórico: `physical73.log`, `desktop_actions.log`, `route-01..09`,
`preliminary_desktop/` e `web_before_final_refinements/` são rodadas anteriores.
Os resultados mais recentes estão nos diretórios indicados acima.

Limites: p95 headless das rotas finais2,7–4,6ms; maior pico1,04s. Isso não mede GPU
nem desempenho de aparelho. Avisos intermitentes de AudioStreamWAV/Playback no
ObjectDB ao encerrar fixtures imediatamente permanecem registrados nos logs.
V-Sync indisponível no driver software e aviso de âncoras na captura de batalha
são limitações do harness. Sem validação em Safari, iPhone físico, Android ou Windows.
