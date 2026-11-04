# Web real no iPhone simulado

Use o Godot oficial 4.7.2 e seus templates `web_nothreads_release.zip` e
`web_nothreads_debug.zip`, com checksums oficiais verificados. O export normal:

```bash
GODOT=/workspace/.tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64
mkdir -p /tmp/qse-web-production/quemsoueuv3
"$GODOT" --headless --path . --export-release Web /tmp/qse-web-production/quemsoueuv3/index.html
```

Para telas que exigem sala, prepare uma **cópia de staging sem `.git`**, com as mesmas
pastas `assets`, `data`, `scripts`, `scenes`, `addons`, `web` e `tests`. Não copie
Supabase, migrations, credenciais, builds ou evidências. Esta cópia não é uma branch
nem um worktree. Mantenha o checkout original intacto.

Somente no staging:

1. Crie o arquivo vazio `.iphone_web_fixture_stage`.
2. Em `project.godot`, troque `run/main_scene` por `res://tests/iphone/web_fixture.tscn`.
3. No preset Web, use `custom_features="iphone_layout_fixture"` e retire `tests/*` do
   filtro de exclusão. O preset de produção permanece inalterado.
4. Importe o staging, execute `--script res://tests/iphone/make_web_fixture.gd` e
   exporte Web para `/tmp/qse-web-fixture/quemsoueuv3/index.html`.
5. Complete ambos os exports com loading, músicas, manifest, ícones e voice bridge
   como em `.github/workflows/deploy-web.yml`, sem o dashboard autenticado.

Sirva as duas pastas somente no loopback, portas 8133 e 8134, respectivamente. Rode:

```bash
QSE_IPHONE_OUTPUT=/tmp/qse-iphone-web node tests/iphone/web_probe.cjs
```

`QSE_PRODUCTION_URL` e `QSE_FIXTURE_URL` permitem escolher outros endpoints locais.
`QSE_IPHONE_STANDALONE=1` também simula o sinal de app instalado (sem convite de instalação); não é um aparelho físico. O probe usa Chromium instalado em `/usr/bin/chromium`, user agent de iPhone,
viewport 844×390 e `deviceScaleFactor: 3`. Ele bloqueia todos os pedidos externos
**antes da rede**; portanto não acessa Supabase e não valida autenticação ou partidas
online. Use somente URLs locais de builds próprios.

As fixtures usam o formulário real, LocalDuelServer, fake RPC de T26 e as mesmas
cenas da produção. Sala/seleção recebem payload local com o ramo visual online para
mostrar código e voz. Isso não é conexão online. O script é protegido pela feature
de teste e fica excluído do export normal. A cena de fixture é gerada pelo motor,
nunca editada como texto.

O probe verifica geometria real do canvas, ausência de fullscreen, sobreposição
do mini player, tamanhos de legenda e três escolhas por toque que habilitam
Confirmar cartas. Capturas, relatórios e erros de console são gravados no diretório
de saída. Falhas de fetch são esperadas porque os destinos externos são bloqueados;
erros de script ou geometria não devem ser ignorados.

A guarda nativa e as capturas de modelos continuam necessárias. Os harnesses agora
esperam o estado da navegação antes de auditar/capturar; mantêm todas as verificações
e usam menos frames redundantes no renderizador por software. `capture_models.sh`
preserva o status do motor com pipefail e mantém um log por modelo.

Isso não substitui Safari ou iPhone físico. O fallback de insets do Chromium é
62 px laterais, 16 no topo e 21 embaixo: canvas 720×353 CSS, buffer 2160×1059.
