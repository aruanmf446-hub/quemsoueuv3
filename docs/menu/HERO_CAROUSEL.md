# Hero principal — História, Mata-Mata e Biblioteca

Evolução da implementação do PR #97 na própria branch `work/hero-carousel-inicio-v3`.
O hero ocupa uma única área com três slides horizontais; não há banners empilhados.

## Arte e controles

Os fundos em `assets/menu/hero/` foram editados a partir das três referências fornecidas
pelo proprietário em 04/11/2026, removendo logo, textos, botões, setas, painéis de seleção
e player ilustrados. Os personagens e a composição das referências foram preservados.
Não se utiliza a imagem completa como interface ou um mapa de hotspots.

`hero_carousel.gd` cria `TextureRect` para os fundos e controles Godot para logo oficial,
header, títulos, descrições, recompensa, CTA, setas, indicadores e rodapé.
Os WebP têm 1672×941, aproximadamente 900 KB somados. A importação usa compressão
lossy 0,85 e mipmaps: aproximadamente 1,3 MB somados de texturas importadas.
As imagens usam `KEEP_ASPECT_COVERED`, sem deformação; o layout e as capturas verificam
as bases atuais de `UIScale`, inclusive a base 1200×675 do iPhone. O shell continua
responsável pela área segura e por landscape; não foi alterado.

## Interação

- Ordem inicial: História (`story`), Mata-Mata (`duel`), Biblioteca (`deck_library`).
- Animação horizontal de 0,45 segundo, com bloqueio de ações durante a transição.
- Setas laterais, indicadores, abas e teclas esquerda/direita alternam os slides.
- Tab navega pelos controles; Enter ativa os botões. O player também aceita Espaço.
- Um arraste horizontal que começa sobre o CTA cancela o clique; apenas o botão abre o modo.
  Tocar no cenário não abre rotas.
- Avanço automático a cada 10 segundos, reiniciado pela interação manual.
- Pausa durante toque/arraste, botão pressionado, tela interna, Novidades, modal de
  nickname e perda de foco da aplicação. Toque cancelado e redimensionamento liberam o gesto.
- Header: História, Mata-Mata e Biblioteca selecionam slides; Personagens, Amizades e
  Ajustes abrem `skins`, `friends` e `settings`. A aba selecionada recebe borda dourada.
- Novidades e Ver Amigos chamam as implementações existentes.

`main_menu.gd` mantém a integração do PR original. `Navigation`, serviços, sessão,
inventário, progresso e convites não foram reconstruídos. `NowPlaying` permanece acima
do hero e utiliza o transporte real; seus botões ganharam foco e tratamento de teclado.
O palco 3D original fica pausado quando o hero ilustrado está ativo. Se uma arte faltar,
o componente preserva o lobby original em vez de ativar uma composição incompleta.

## Verificação

Motor: **4.7.2.stable.official.ed1daf0bf**, arquivo oficial com SHA-512 verificado.
As evidências e os resultados estão em [evidence/hero-carousel-v3](../../evidence/hero-carousel-v3/README.md).

```bash
export GODOT=/workspace/.tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64
"$GODOT" --headless --path . --script res://tests/hero_carousel/flow_test.gd
"$GODOT" --headless --path . --script res://tests/hero_carousel/flow_test.gd -- --resolution=712x338 --iphone
# Com DISPLAY disponível (ex.: Xvfb :99):
DISPLAY=:99 LP_NUM_THREADS=2 "$GODOT" --path . --audio-driver Dummy \
  --script res://tests/hero_carousel/flow_test.gd -- --output=/tmp/hero-desktop
DISPLAY=:99 "$GODOT" --path . --audio-driver Dummy \
  --script res://tests/hero_carousel/capture.gd -- /tmp/hero-iphone 712x338 --iphone
python3 tools/player_ui/check_design.py
```

Os testes geram eventos reais de mouse, toque e teclado no viewport. A captura pausa
apenas o relógio automático durante o readback da GPU; o teste funcional depois espera
os 10 segundos reais para validar o autoplay. As capturas são do motor, não montagens.
Não equivalem a testes em Safari/iPhone físico, Android ou EXE Windows.
OAuth Google/Discord real não foi executado: as regressões de sessão usam fixtures.
A política de rede desta máquina inicialmente bloqueia os três hosts Supabase do
`data/backend/client.json`; nenhuma credencial foi solicitada ou substituída.

O teste existente `tests/web_pwa/sw_test.js` passou nas verificações iniciais de cache e
landscape, mas expirou esperando `registration.waiting`: o shell atual pode ativar a
atualização automaticamente nos primeiros 15 segundos. O teste monta um motor simulado,
não executa o hero. Shell, service worker e esse teste não foram alterados neste PR.
