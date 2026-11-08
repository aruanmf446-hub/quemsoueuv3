# Atualização rápida — evidências de teste

Consultar docs/web/ATUALIZACOES_PWA.md para arquitetura, uso, primeira publicação e limites.

Chromium com service workers reais: 25 verificações, zero falhas. Quatro versões
sintéticas e pacote propositalmente atrasado; cache HTTP longo; HTML de CDN antigo;
offline; foco; bloqueio durante partida/campanha e com outra aba aberta; ativação
consentida, reuso do wasm e preservação de localStorage/IndexedDB. PWA existente:
31 verificações, zero falhas (ponte de texto incluída).

Godot Web 4.7.2 real exportado: clique/toque no botão de Ajustes e painel funcionando
em 1672×941, iPhone UA 844×390 e 640×360, DPR3. Contas são fixtures locais; nenhuma
chamada real de backend. Capturas em godot-web/. Página externa em external/, também
390×844. Versões update-d e input-fixture são IDs de teste, não versões de produção.

Carrossel/rotas no Godot: 69 verificações, zero falhas. Catálogos/glyphs: 31.395
verificações, zero falhas (a maioria verifica mensagens/caracteres, não cenários
independentes). check_design.py, check_catalogs.py, check_site.py, check_pwa.py,
node --check e git diff --check passaram.

Sem teste em iPhone físico/Safari, APK ou EXE. Esta alteração não foi publicada
na main/Pages. Nenhum dado de jogador foi apagado; nenhuma arte nova foi gerada.
