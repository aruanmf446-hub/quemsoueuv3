# Evidências e limites

- `physical73.log`: 73 verificações, zero falhas; cargas, desbloqueios, separação de itens, ruptura física, congelamento, dash, salto real do Cactus e parada real no abismo.
- `iphone_guard.log`: nove modelos,504 verificações,zero falhas. Houve uma execução anterior com falha transitória de navegação no SE; repetição isolada e rodada completa final passaram. Diagnóstico foi acrescentado ao teste.
- `iphone_models/`:108 capturas reais do motor,12por modelo, convertidas paraJPEG sem recorte/montagem. Não são aparelho físico.
- `route-01..09`: nove travessias físicas concluídas sem morte; foram executadas ANTES do último refinamento de separação de recargas/partição do chão e HUD. Reexecutar sobre o commit final.
- `web_before_final_refinements/`: WebAssembly real,iPhoneUA844×390,DPR3, oito quadros por toque, leitura longa sem avanço automático,dash e releitura após reload, destinos externos bloqueados. Export anterior aos últimos refinamentos de HUD/desbloqueios/recargas; repetir no estado final. O teste agora também exige persistência das habilidades após reload; essa exigência adicional ainda precisa ser executada.
- `preliminary_desktop/`: nove imagens reais do motor ANTERIORES ao HUD circular final. Não usar como aprovação visual final.
- `pwa28.log`:28verificações,zero falhas.
- `desktop_actions.log`: log da última execução; conferir seu resultado antes de afirmar aprovação.

Picos de tempo de quadro estão nos JSONs. O benchmark passou a medir p95 dos quadros e a registrar separadamente os intervalos físicos que incluem o hit-stop intencional; não promete ausência de engasgos. Sem validação em Safari,aparelho físico,Windows ou Android real.
