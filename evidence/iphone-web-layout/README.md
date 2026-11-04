# iPhone — validação nativa e Web real

Godot **4.7.2.stable.official.ed1daf0bf**, templates oficiais Web sem threads,
verificados por SHA-512. Chromium com user agent iPhone, 844×390, DPR 3 e
WebAssembly real. Não é Safari nem iPhone físico.

| Tela Web | Evidência |
|---|---|
| Boot de produção | [captura](web/production.png) |
| Criar sala | [captura](web/form.png) |
| Sala de cinco participantes | [captura](web/room.png) |
| Escolha das cartas | [captura](web/selection.png) |
| Personagens paginados | [captura](web/skins.png) |
| Amizades | [captura](web/friends.png) |
| Perfil | [captura](web/profile.png) |
| Carteira | [captura](web/wallet.png) |
| História | [captura](web/story.png) |
| Músicas | [captura](web/music.png) |

## O que foi corrigido

- O fullscreen do canvas esticava um buffer calculado para a área segura. Só no
  iPhone, o shell mantém o jogo dentro dessa área e sai do fullscreen do canvas.
  O PWA instalado continua ocupando a tela do aparelho. Foram medidos 720×353 CSS
  em offset 62×16 e buffer 2160×1059, com escala uniforme e DPR 3.
- O formulário usa rótulos curtos em uma linha, fontes preservadas e decks paginados.
  Criar fica sempre visível; não há rolagem vertical do formulário.
- Sala: ações de iniciar/configurar/sair ficam fora da rolagem de participantes.
  A fixture de cinco participantes cabe também sem rolagem do conteúdo.
- O canvas de batalha recebeu a isenção do piso de fonte, pois já escala pela altura
  virtual 480. Legendas têm fonte 16 e duas linhas completas; Confirmar usa fonte 16.
  O tabuleiro mantém rolagem para preservar o tamanho das artes e acessar todo o pool.
- Personagens: páginas de três entradas, sem rolagem vertical, mantendo os retratos.
- As seis MINI_ROUTES foram medidas: nenhuma sobreposição de player com texto ou botão.
- O estilo do hero foi centralizado em PlayerUI; não houve criação de tema paralelo.

## Resultados

- Guarda de nove modelos: **511 verificações, zero falhas**.
- Formulário e ações da sala nos nove modelos: **252 verificações, zero falhas**.
- PWA: **28 verificações, zero falhas**, inclusive reparo da área segura após mudança de CSS.
- **108 capturas nativas**: 12 telas por modelo. Os JPEGs em `models/` são apenas
  compressões dos PNGs do motor, sem montagem ou alteração da interface.
- Batalha de cinco participantes: [captura nativa obrigatória](battle_5_players_750x353.png).
- Seleção Web: três toques escolheram exatamente três cartas e habilitaram Confirmar;
  [estado medido no motor](selection-interaction.json).
- Regressões: formulário T26 (24 verificações), duelo local, revelação de batalha,
  T24 iOS e sessão/música aprovados. Os harnesses de formulário emitiram diagnósticos
  conhecidos de RID/recursos na saída; isso foi registrado, sem ignorar erros de script.
- Importação/exportação e verificação de design: sem erros de script ou parse.

[Resultados estruturados](results.json), [logs](logs/) e
[instruções reproduzíveis](../../tests/iphone/WEB_VALIDATION.md).

## Limites

Sala/seleção mostram as cenas reais com payload do LocalDuelServer e fake RPC de T26,
explicitamente identificados como fixtures. Nenhuma sala online foi criada: todos
os pedidos externos do navegador foram abortados antes de chegar à rede. Os erros
`Failed to fetch` nos logs decorrem desse bloqueio deliberado. Não foram acessados
Supabase, banco, Edge Functions ou migrations; tampouco foram solicitadas credenciais.

Capturas em navegador e motor não validam aparelho físico. A confirmação final cabe
ao dono, fechando e reabrindo o PWA depois da publicação. O botão de instalação que
aparece em algumas capturas é do shell no modo Safari simulado, não do mini player.

A captura final da seleção também simula `navigator.standalone=true`, sem o convite de instalação. O modo instalado simulado não equivale a um iPhone físico.
