# Batalha — revisão de 30/10/2026

Continuação do PR #39, sem mudança de regras, backend, personagens ou cartas.
**Aguardando avaliação visual do usuário. Não fazer merge automaticamente.**

## Capturas reais do Godot 4.7.2

Capturadas com renderizador Compatibility, Xorg/Mesa llvmpipe. Não são mockups.
O teste cria uma partida local real com os nove PNGs existentes e bots locais.
Fixtures de apresentação são explicitamente identificadas abaixo; nunca entram nos catálogos.

| Janela | Captura |
|---|---|
| 844×390 | [Rodada](844x390-battle.png), [seleção](844x390-selection.png), [mão aberta](844x390-private-hand.png) |
| 640×360 | [Rodada](640x360-battle.png), [confirmação — fixture](640x360-confirmation-fixture.png) |
| 1920×1080 | [Rodada](1920x1080-battle.png) |
| 2532×1170, densidade 3 simulada | [Rodada](2532x1170-d3-battle.png) |

Estados de apresentação com dados em memória: [confirmação](844x390-confirmation-fixture.png),
[chat com transporte de teste](844x390-chat-fixture.png), [vitória](844x390-victory-fixture.png).
A confirmação força a vez local para examinar a geometria; a vitória força o resultado
somente no teste. O fluxo e as regras reais também são exercitados pelo teste existente do Duelo.

## Correções nesta continuação

- Ao ocultar a batalha ou perder o foco, a mão volta ao estado oculto e suas imagens
  são removidas imediatamente. A volta de Configurações não reapresenta miniaturas privadas.
- Cartas recebem toque nativo, mouse e teclado. O clique sintético de um toque é ignorado
  para evitar selecionar e desmarcar a mesma carta em um único gesto.
- Novas verificações de toque, clique sintético duplicado, teclado, privacidade, vitória
  e espectador, preservando os testes de mouse e serviços existentes.

## Validação

- [Smoke completo](smoke.json): **30/30 grupos**, incluindo dez fases, nove transições,
  funcional, apresentação da batalha, navegação, Duelo, chat e menu.
- [Apresentação headless](battle_presentation.log): **377 verificações**, zero falhas.
- Apresentação gráfica: **383 verificações por janela**, zero falhas, em
  [844×390](final844.log), [640×360](final640.log), [1920×1080](final1920.log) e
  [densidade 3](finalretina.log). Inclui entrada nativa de toque e teclado, além de mouse.
- [Navegação real](battle_navigation.log): **10 verificações**, zero falhas.
- [Duelo local](duel_local.log): **54 verificações**, zero falhas.
- [Chat existente](chat_flow.log): **20 verificações**, zero falhas, transporte de teste.
- [Configurações](settings.log): zero falhas.
- `python3 tools/player_ui/check_design.py`: passou.
- [Funcional](functional.log): passou no Godot **4.7.2**. O erro de fonte `mh > 4096`
  informado na passagem, executada no 4.6.3, não se reproduziu; nenhum código de campanha
  foi alterado para contornar o teste.

Os casos de 7/30 opções e 5/12/20 participantes são estresse de geometria em memória.
Trinta opções em celular continuam muito densas: isso não equivale à legibilidade das
nove cartas principais nem constitui aprovação estética.

## Build Web e teste no navegador

Exportação Web final: `index.pck` com **57.219.448 bytes (54,57 MiB)**.
Chromium/Playwright em 844×390, eventos de toque emulados e SwiftShader (GPU por software):
criação de partida local → adicionar bot → iniciar → escolher três cartas → confirmar →
começar rodada → mostrar mão. As capturas comprovam [três seleções sem duplicação](web-844x390-selected.png),
[rodada iniciada](web-844x390-battle.png) e [mão aberta](web-844x390-hand.png).
Nenhuma medição de desempenho em aparelho é inferida desse teste.

**Teste Web local com ressalvas:** o [registro](web-local.json) mostra erro da interface
opcional `QSE_PUBLIC_CONFIG`, falha de certificado na consulta pública ao catálogo remoto
e 404s de músicas/carregamento, cujos arquivos externos não foram copiados para esta
pasta de exportação (o workflow de deploy faz essa cópia separadamente).
A partida local funcionou; isso não valida integração remota, áudio ou a publicação em Pages.
O exportador concluiu com saída zero; registrou erros de detecção Vulkan do ambiente
mesmo usando Compatibility. Não houve alteração de renderizador ou qualidade gráfica.

## Limites e dependências

Não houve teste em Android físico, iPhone ou com conta remota autenticada. A simulação
no desktop não comprova toque em aparelho físico nem desempenho de GPU móvel.
A imagem original de referência da batalha não está neste checkout: a revisão segue o
brief integral e o lobby aprovado, sem alegar comparação visual exata com a imagem ausente.

O chat integrado é **privado entre amigos**, não chat de sala. Voz e links de convite
não existem; a interface não simula essas funções. O código real da sala online pode
ser copiado, mas não foi testado com uma sala remota nesta rodada.

Aprovação técnica não substitui sua avaliação visual destas capturas.
