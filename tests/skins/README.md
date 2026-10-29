# Personagens — redesign e validação

Redesign original sobre `d75bf2f`; refinamento atual parte de `d91c310`, na branch `design/personagens-cinematico`. Referências analisadas: `docs/referencias/personagens/REFERENCIA_APROVADA.png` e `IMPLEMENTACAO_ATUAL.png`.

A tela reutiliza a cena original via construção de controles em `skins_panel.gd`. O catálogo, modelos, autorização de equipamento, pesquisa, favoritos em ConfigFile, filtros e cache continuam existentes. Seleção não equipa. Nenhuma cena `.tscn` foi editada. O palco usa uma subclasse exclusiva, sem alterar a iluminação do lobby. A câmera mede as caixas das malhas na pose atual, incluindo roupas/cabelo/chapéus, e ajusta a distância conforme profundidade, aspecto e rotação. O bake CPU é temporário, uma vez por seleção: não substitui modelos nem materiais. A plataforma recebe sombras e acompanha a altura dos pés. Não usa pós-processamento ou shaders novos.

Diferenças corrigidas após inspeção das capturas reais: nomes cortados, retratos desiguais, cenário excessivamente exposto, preview sem chão, brilho excessivo do aro, cores emoji nos favoritos, cards grandes em telas pequenas e corte da pose de El Fuego.

## Reproduzir

Godot oficial `4.7.2.stable.official.ed1daf0bf`, renderizador Compatibility. Requer display X11/OpenGL (Xvfb funciona com Mesa/llvmpipe). Use XDG_DATA_HOME **novo** para não alterar equipamento/favoritos pessoais. Não execute o teste com dados pessoais.

```sh
XDG_DATA_HOME="$(mktemp -d /tmp/qse-skins-data.XXXXXX)" DISPLAY=:99 \
  /workspace/.setup/quemsoueuv3/godot/Godot_v4.7.2-stable_linux.x86_64 \
  --path /workspace/quemsoueuv3 --rendering-method gl_compatibility \
  --audio-driver Dummy --script res://tests/skins/visual.gd
```

O teste salva capturas em `/tmp/qse-skins-refined` e executa 171 verificações: catálogo real, clique no card, setas, seleção independente, pesquisa com/sem resultado, favoritos persistidos, filtro bloqueado, equipamento via serviço, estado equipado/bloqueado, rotação mouse/touch, oito modelos ordenação A–Z/Z–A, ausência de abas inexistentes/estado duplicado, contador de desbloqueio real e limites dos painéis em 1280×720, 960×540 e 800×450. As caixas das malhas e do pedestal são projetadas e verificadas em três ângulos para cada personagem nas quatro resoluções; mouse e toque também percorrem o despacho real do viewport em cada resolução menor. A captura desktop tem 1672×941. Dados isolados contêm apenas equipamento/favoritos locais gerados pelo teste. As capturas `desktop-<id>.png` e `mobile-<id>.png` de todos os modelos são geradas junto das seis capturas principais.

Também executada a suíte existente `tools/godot/run_smoke.py`: 22/22 aprovados (importação, dez fases, nove transições, funcional e menu). A abertura/fechamento de todas as oito rotas do menu foi repetida após a correção final de enquadramento.

## Evidências e limites

Os PNGs em `evidence/` são capturas do framebuffer real, sem montagem. Incluem desktop, equipado, bloqueado e três resoluções menores com galeria rolada. Comparação visual feita após cada rodada de correções.

- A referência contém personagens, coleções e ofertas ilustrativas. Mantivemos exclusivamente os oito personagens reais e a coleção cadastrada. Não existem ofertas/preços cadastrados; não foi criada loja fictícia. A galeria ocupa a área restante.
- O catálogo marca `idle_verified=false` e `idle=""` nas oito entradas. Foram preservadas as poses/animações definidas pelo carregador; não é possível declarar Idle validado sem um clipe aprovado.
- Testes executados no Linux com renderização real por software; gestos exercitados via eventos Godot. APK, navegador Web e desempenho em aparelho físico não foram validados. O renderizador Compatibility e os caminhos existentes de toque foram preservados.
- O palco usa o perfil gráfico existente: sombras reais estão disponíveis quando habilitadas nesse perfil. Não foi alterada a preferência gráfica do jogador.
- Supabase, economia, autenticação e modelos não foram modificados. A branch de refinamento é publicada para revisão, sem merge na main.

## Refinamento a partir de d91c310

- Removidas todas as abas: Emotes definitivamente; Skins, Armas e Personalização enquanto não implementadas. O título Personagens permanece.
- Contador “7/8 desbloqueados” derivado do inventário, sem número fixo.
- Na prévia, coleção e orientação de arraste aparecem uma vez; o estado fica apenas na ação Equipar/Equipado/Bloqueado. As setas ficam nas laterais do palco; Voltar permanece no cabeçalho.
- Os cartões (composição, texturas, cores, hover, retratos e estados) foram preservados. Lobby, música, serviços, dados e gameplay não receberam alterações.
- Inspeção visual das capturas dos oito personagens em desktop e mobile landscape, além das capturas principais em quatro resoluções. Evidências principais atualizadas em `evidence/`.

O smoke headless usa as caixas importadas porque o renderizador dummy não registra skins para bake. A medição de pose e os limites de enquadramento foram validados separadamente com renderização OpenGL real.
