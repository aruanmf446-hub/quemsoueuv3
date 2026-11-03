# Layout no iPhone (PWA) — referência para APK, EXE e navegador

Este documento registra **como o jogo foi ajustado para iPhone** (app instalado pela tela de
início e Safari) e serve de base para validar os demais aparelhos depois.
Android, Windows (EXE), iPad e navegador de computador **não foram alterados**.

> Status: validado por capturas reais do motor em todos os tamanhos de iPhone abaixo.
> **A validação no aparelho físico é do dono do projeto** (app instalado). Capturas do motor
> não substituem o teste no iPhone.

## 1. Área segura com faixas pretas (web/shell.html)

Só quando o navegador é um iPhone (`window.qsePwa.iphone`):

- O canvas do Godot fica **somente dentro da área segura**. O próprio iOS informa a área de cada
  modelo (`env(safe-area-inset-*)`), então funciona em qualquer iPhone, atual ou futuro.
- Notch / Dynamic Island (laterais com o aparelho deitado), barrinha de início (embaixo) e uma
  faixa mínima de **16 pt no topo** (onde o iOS captura toques do sistema) ficam **pretas**.
  Nenhum botão, texto ou campo de mensagem fica embaixo delas.
- O canvas é dimensionado pela página (`canvasResizePolicy = 0`): o motor segue o tamanho do canvas.
- Com o teclado aberto o jogo não é redimensionado (não "pula" enquanto se digita).

## 2. Base de design do iPhone (scripts/ui/ui_scale.gd)

| Aparelho | Base de design | Observação |
|---|---|---|
| PC, Android, iPad, navegador de computador | 1672 × 941 | regra "layout padrão" (inalterada) |
| **iPhone (PWA/Safari)** | **1138 × 640** | interface ~70% maior que antes |

- Stretch continua `canvas_items` / `expand`: telas mais largas só mostram mais espaço.
- `UIScale.is_iphone()` identifica o perfil; testes simulam com `--iphone`.
- **Piso de legibilidade** (`IPHONE_MIN_FONT = 20` px de design ≈ 11 pt no 13 mini e ≈ 13 pt no
  Pro Max): só textos menores sobem; os grandes ficam como estão. Telas com escala própria
  (batalha) marcam `qse_no_font_floor` e ficam fora do piso.
- Ajustes por tela usam `UIScale.is_iphone()` só onde o espaço exigiu (lista abaixo). Não há
  "+x%" genérico.

## 3. Componentes padrão (todas as plataformas)

- **Voltar**: `PlayerUI.standard_back(button, label)` — mesmo texto/seta, tamanho
  `PlayerUI.BACK_SIZE` (152×60; +8 de altura no iPhone), fonte `CONTROL_FONT`, estilo secundário.
  Usado em todas as telas (Biblioteca mostra "Biblioteca"/"Galeria" quando volta a um nível).
- Batalha mantém o seu "Voltar" compacto (escala própria do tabuleiro).

## 4. Tamanhos úteis validados (pt, aparelho deitado, sem notch/barrinha/faixa do topo)

| Grupo | Modelos | Tela CSS | Área útil |
|---|---|---|---|
| pro_max | 16/17/18 Pro Max | 956×440 | 832×403 |
| pro | 16/17/18 Pro, 17 | 874×402 | 750×365 |
| air | iPhone Air | 912×420 | 788×383 |
| plus | 16 Plus, 15 Plus, 15 Pro Max | 932×430 | 838×393 |
| plus14 | 14 Plus | 926×428 | 832×391 |
| std61 | 16, 15, 15 Pro | 852×393 | 734×356 |
| notch61 | 16e, 17e, 14, 13, 12 | 844×390 | 750×353 |
| mini | 13 mini (menor altura) | 812×375 | 712×338 |
| se | SE 3ª geração (mais estreito, sem notch) | 667×375 | 667×359 |

A tabela de captura está em `tests/iphone/models.txt`. Piores casos: **mini** (altura) e **SE** (largura).

## 5. Ajustes por tela no iPhone

| Tela | Ajuste |
|---|---|
| Lobby | abas medidas pela largura útil real; título "Reino do Deserto" mais alto e menor para não encostar no JOGAR |
| Login/Conta | logo menor no topo; painel de login largo (470) e alto; Voltar padrão |
| Novidades / Resgatar | janela quase em tela cheia; banner mais baixo; cartões inteiros (arte, nome, descrição, botão); botão RESGATAR sempre visível; textos maiores |
| Modo História | cartões de fase mais baixos com JOGAR visível; margem nunca maior que a tela |
| Mata-Mata · Criar sala | abas de decks quebram linha; rótulos longos e subtítulos quebram linha; resumo cabe até no SE |
| Batalha | sem recuo próprio (a página já cuida das bordas); fora do piso de fonte; chat visível também na partida local (recolhido, mensagens só no aparelho); voz oculta na partida local |
| Configurações | painel principal mais largo para os valores (nickname/e-mail) não cortarem |
| Demais (Biblioteca, Amizades, Perfil, Personagens, Carteira, Músicas) | piso de fonte + Voltar padrão; conteúdo rola onde já rolava |

## 6. Como reproduzir

```bash
# todas as telas em todos os iPhones (precisa de xvfb)
GODOT=/caminho/godot tests/iphone/capture_models.sh /tmp/iphone
# uma tela/um tamanho
xvfb-run -a godot --path . --script res://tests/iphone/capture_iphone.gd -- /tmp/out 712x338 lobby,news --iphone
xvfb-run -a godot --path . --script res://tests/iphone/capture_news.gd -- /tmp/out 712x338 --iphone
xvfb-run -a godot --path . --script res://tests/ios_t24/battle_capture.gd -- /tmp/out 712x338 6 batalha --iphone
node tests/web_pwa/sw_test.js   # página: área segura, faixas pretas, teclado nativo
```

Folhas de contato por modelo: `docs/evidence/iphone/<grupo>.jpg`.

## 7. Para validar outros aparelhos depois (APK, EXE, navegador)

1. Medir a **área útil real** (Android: recortes de câmera e barra de gestos; PC: janela).
2. Decidir a base de design do perfil (iPhone usa 1080×608) e o piso de fonte.
3. Rodar as mesmas capturas com o perfil e conferir: nada cortado, nada sob recortes, botões
   com toque confortável (≥ ~40 pt), textos ≥ ~9,5 pt.
4. Registrar aqui a tabela de tamanhos e os ajustes por tela.
