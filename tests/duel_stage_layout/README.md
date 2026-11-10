# Mata-Mata — geometria e apresentações

`client.gd` abre a cena real, cria uma sala local com três bots e compara painéis e
cartas entre seleção, turnos, remoção de cartas, mão aberta e chat recolhido.
Dados alterados diretamente são fixtures locais de estados; não atingem Supabase.
Exemplo: `godot --headless --path . --script res://tests/duel_stage_layout/client.gd -- 844x390 --iphone`.
Passe uma pasta como segundo argumento para capturas com renderer gráfico.

`export.py` atualiza somente a cópia isolada marcada por `.iphone_web_fixture_stage`
e exporta o motor Web real. `web.cjs <raiz-site> <evidências>` abre desktop e duas
janelas iPhone UA/DPR3 no Chromium. O teste verifica textura completa, proporção,
estabilidade, clipes existentes e seleção real por mouse/toque com confirmação.
O prazo de seleção é estendido na fixture e os heartbeats automáticos são parados:
a GPU emulada pode demorar mais de trinta segundos para capturar um único quadro.
Isso evita avançar a autoridade para countdown durante medições de outro estado.
Os testes de cronologia autoritativa são separados em `timing.gd`.

Não usar a fixture como main de produção. O export de produção exclui tests/*.
Capturas do Chromium não comprovam Safari/iPhone físico nem desempenho real.

Limite do runner Web: o teste de abrir/recolher a mão usa uma mão vazia nessa
fixture de estados. O runner nativo injeta duas cartas privadas reais para testar
seu conteúdo e os mesmos limites. O Web confirma também seleção por toque/clique
e a chamada real de confirmação ao servidor local; não testa salas online reais.

## Resultado desta execução (09/11/2026)

- Native: 55 verificações por tamanho (1672×941, 844×390 e 640×360), zero falhas;
  incluem duas cartas privadas e estabilidade de painéis ao mostrar/recolher.
- Web: somente desktop chegou às verificações de arte completa, proporção e
  geometria estável em seleção/turnos/remoção/mão vazia/chat. Foram capturados
  os clipes anim_2/anim_3/anim_4 no palco real, além do tabuleiro.
- O runner Web parou em `selection confirmation on real card`: depois dos dois
  cliques não encontrou um botão visível chamado `AcceptSelection` no relatório.
  Isso permanece sem diagnóstico conclusivo; não comprova seleção aceita nem
  aprovação do teste completo. As execuções Web de iPhone não foram alcançadas.
- O ajuste final de altura máxima privada para 96 foi realizado depois da
  exportação e dos testes acima. Nenhuma nova execução foi feita pelo agente
  de validação após essa expressão mudar. A geometria nativa acima não é prova
  específica desse último ajuste nem da contenção individual das imagens.
- Os clocks e heartbeats da fixture Web foram isolados porque, antes disso,
  o timer de seleção avançava durante a captura lenta da GPU emulada e invalidava
  medições de uma fase anterior. Os JSON finais registram a fase medida.

Evidências: `evidence/duel-stage-layout/`. Os JSON guardam geometrias comparadas;
o runner não gerou `results.json` de aprovação porque terminou com a falha acima.
Não houve testes em aparelho físico, Safari ou duas contas online.


## Publicação autorizada — 10/11/2026

O dono autorizou publicar o PR #121 na main. O runner Web foi corrigido para
exercitar a seleção real antes dos estados simulados e esperar o fim efetivo do
palco, incluindo o carregamento do modelo, em vez de aguardar 6,8 segundos fixos.
A falha anterior era do roteiro de teste: ele tentava clicar nas cartas enquanto
a apresentação ainda recebia os eventos. Não houve mudança do servidor online.

Nesta revisão: 57 verificações nativas por resolução (1672×941, 844×390 e
640×360), dez de transições e 91 da partida local completa, todas sem falhas.
Os testes foram executados com Godot 4.7.2 na cópia isolada já importada;
a primeira tentativa no worktree sem cache de classes não carregou PlayerServices.

Verificação adicional do relato mais recente: 62 checks por resolução, zero
falhas, incluindo vinte participantes sem alterar os limites de PlayersScroll,
BattleBoard, UtilityRail, BattleChat e PrivatePanel. A ordem da apresentação vem
de turn_order da autoridade; não há novo sorteio no cliente.

Regressão PWA nesta sessão: com o Chromium instalado, o runner passou as
verificações iniciais de registro/cache/manifest, mas parou em sw_test.js:45 com
"Failed to update a ServiceWorker ... unknown error ... fetching the script".
Não foi declarado aprovado; nenhum arquivo PWA foi alterado nesta entrega.
