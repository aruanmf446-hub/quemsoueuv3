# CONTINUIDADE DO PR #39

## Acabamento visual — rodada seguinte de 30/10/2026

O usuário aprovou a **estrutura**, reprovou o acabamento e enviou nova imagem de
referência. A rodada de polish preserva as regiões e refina a apresentação.
Leia [POLIMENTO_VISUAL.md](POLIMENTO_VISUAL.md) e veja
[capturas atuais e testes](../../../evidence/battle-reference/polish-2026-10-30/README.md).

- Retratos/bustos maiores, painéis e tabuleiro com relevo e sombras leves.
- Foco das ilustrações corrigido, tarjas, bordas e seleção refinadas; nenhum PNG substituído.
- Tipografia, ambientação, ícones em alta densidade e coluna direita refinados.
- Destaque ativo desaparece após revelada a eliminação; sigilo e regras preservados.
- Godot 4.7.2: **392 verificações gráficas por tamanho**, **383 headless**, smoke **30/30**.
- Chromium: partida local percorrida com toque emulado; limites no relatório.
- **Mesma branch/PR #39, main intacta, aguardar avaliação visual.**

As atualizações anteriores abaixo são histórico, não substituem as capturas atuais.

## Atualização de 30/10/2026 — revisão técnica concluída, visual pendente

A continuação está na mesma branch e no mesmo PR, sem alterar a main.
Veja [capturas e resultados atuais](../../../evidence/battle-reference/revisao-2026-10-30/README.md).

- Godot 4.7.2: smoke completo **30/30**; funcional sem o erro de fonte registrado abaixo.
- Apresentação gráfica: **383 verificações** por janela em 844×390, 640×360,
  1920×1080 e 2532×1170 com densidade 3; todas passaram.
- Corrigidas a remoção imediata das imagens privadas ao ocultar a tela e a entrada
  nativa de toque nas cartas, evitando clique sintético duplicado.
- Acrescentadas verificações de teclado, privacidade, vitória e espectador.
- Preservados os nove PNGs, a grade sem rolagem, os serviços, os retratos e a composição existente.
- Build Web de 54,57 MiB: partida local percorrida no Chromium com toque emulado;
  capturas e ressalvas de configuração/certificado/mídias estão no relatório.
- Android físico, serviços remotos autenticados e comparação com a imagem original
  da batalha permanecem sem validação. Não afirmar aprovação estética.
- **Manter o PR em rascunho e aguardar avaliação do usuário; não fazer merge automático.**

O restante deste documento registra a passagem original, anterior à revisão acima.

**Branch:** `codex/battle-reference-layout` · **Base:** `main` em `6cff1f0` (PR #38 integrado).

O usuário pediu publicação imediata por expiração da sessão para outro Codex continuar. Este PR é rascunho: **não está aprovado, não fazer merge automaticamente**.

## Pedido e referência

Leia [BRIEF_APROVADO.md](BRIEF_APROVADO.md), transcrição integral do texto enviado pelo usuário. A referência visual é a imagem da conversa: tabuleiro central 3×3, jogadores somente no topo, painel direito com tempo/configurações/chat/mão privada, fundo abstrato azul-marinho e bordas geométricas finas douradas. A imagem original da referência não está disponível como arquivo neste checkout; o dono pode fornecê-la novamente. A captura abaixo é do motor e mostra a implementação parcial, não substitui a referência aprovada.

**Obrigatório:** todas as opções públicas visíveis simultaneamente, sem rolagem, carrossel, paginação ou cartas cortadas. Não alterar regras, cartas, personagens ou backend. Usar os nove PNGs reais atuais; a imagem conceitual tem cartas que não existem no catálogo: não inventá-las.

[Captura parcial real em 844×390](../../../evidence/battle-reference/844x390-parcial.png).

## Implementado até aqui

- `scripts/ui/screens/duel_match_view.gd`: apresentação reconstruída como Control, tabuleiro fixo, participantes superiores com retratos reais e vidas, instrução/temporizador reais, confirmação inline sem modal sobre as cartas, mão privada lateral oculta por padrão, estados de revelação/eliminação/vitória.
- `scripts/ui/screens/duel_screen.gd`: modo de layout para a batalha, rolagem externa desabilitada, margens compactas e safe-area; mantém a instância durante refresh; restaura o layout normal ao sair. Batalha encerrada preserva a composição, sem declarar bot campeão.
- `scripts/ui/player_screen.gd`: não tenta focar o botão de retorno quando o cabeçalho padrão está oculto.
- `scripts/ui/battle/`: estilo a partir de PlayerUI, geometria escalável do fundo/molduras, carta pública com recorte focal proporcional do PNG original e painel compacto de conversa privada.
- `assets/ui/battle/`: somente SVGs leves novos. Retratos em `assets/portraits` e cartas em `assets/duel/decks` reutilizados; nenhuma ilustração foi recriada.
- `tests/battle_reference/flow.gd`: fluxo local real, eventos de mouse, geometria, seleção, privacidade, suspense, chat com transporte de fixture e layouts de estresse. `navigation.gd`: navegação real batalha → Configurações → batalha → lobby. Ambos adicionados ao runner de smoke.

## Dependências reais

**O CHAT existente é privado entre amigos, não chat de sala.** O painel lateral chama o ChatService e transporte existentes. No modo local sem conta, mostra indisponibilidade, sem mensagens fictícias de bots. O histórico pode recolher mantendo a conversa aberta; sair da batalha fecha a conversa e interrompe suas consultas. Troca de conta remove os balões.

Voz não existe: indicador indisponível, sem ativação falsa. Código de sala só aparece no modo online com código real e copia para a área de transferência. Não há geração de link de convite. Configurações abre a rota existente e o relógio do servidor continua correndo.

## Validação feita / o que ainda precisa terminar

Motor local disponível: **Godot 4.6.3**, Compatibility/Mesa/Xvfb. Projeto/CI especificam 4.7.2. Não houve Android físico nem navegador.

- Teste existente do Duelo local passou com 54 verificações e capturas reais após a reestruturação. Algumas execuções apontaram aviso de foco em cartas não interativas; foi adicionada guarda de focus_mode depois delas. Reexecutar na versão final.
- Nova suíte visual passou com 365 verificações em 1672×941, 844×390 e 640×360; execução headless passou com 360 (sem capturas). Houve ajustes posteriores pequenos; reexecutar antes de concluir.
- Navegação real da batalha: 10 verificações passaram. Chat existente: 20. Configurações: 28.
- Alta densidade simulada (2532×1170, `--ui-scale=3`) inicialmente revelou corridas do heartbeat nas fixtures de confirmação e overflow transitório. O teste passou a parar o heartbeat depois do refresh real e a usar fase controlada somente nos casos de apresentação. A última repetição estava terminando ao publicar: conferir os logs e repetir.
- O smoke completo estava em execução. Importação, dez fases e nove transições passaram; `battle_presentation` e `battle_navigation` passaram. A etapa `functional` FALHOU no motor local com `Condition "mh > 4096"` em `combat_readout.gd:25` (rasterização de fonte). Ainda não foi comparado com a main nem corrigido. Não declarar smoke completo verde.
- Geometria de 7 e 30 opções e 5/12/20 participantes usa fixtures SOMENTE em memória, não decks publicados. A grade de 30 cartas é muito densa em celular; não representa aprovação estética ou legibilidade equivalente à composição principal de nove cartas.

## Próximos passos

1. Executar as suítes novamente com o código final e verificar erros do motor, não só exit code.
2. Inspecionar capturas atuais em 844×390, 640×360, desktop e densidade 3. Garantir que confirmação, mão privada e chat nunca cortem ou encubram o tabuleiro.
3. Conferir foco/teclado, toque em Android, troca de conta e ocultação da mão ao perder foco; validar states encerrado, vitória e espectador.
4. Revisar qualidade visual com a imagem aprovada e o usuário. Ainda há trabalho de acabamento e documentação de entrega.
5. Investigar a falha de fonte do functional separando o que já ocorre na main. Rodar o smoke no motor configurado no CI.
6. Atualizar evidências, descrição e status do PR. Não fazer merge automaticamente.

## Comandos úteis

```sh
python3 tools/player_ui/check_design.py
godot --headless --path . --script tests/battle_reference/flow.gd
godot --headless --path . --script tests/battle_reference/navigation.gd
godot --path . --script tests/battle_reference/flow.gd -- 844x390 /tmp/battle-844
godot --path . --script tests/battle_reference/flow.gd -- 640x360 /tmp/battle-640
godot --path . --script tests/battle_reference/flow.gd -- 2532x1170 /tmp/battle-retina --ui-scale=3
godot --path . --script tests/duel_local/flow_test.gd -- /tmp/battle-real 844x390
python3 tools/godot/run_smoke.py --godot /caminho/godot --output /tmp/battle-smoke
```

Use `--script` por extenso e user:// isolado para os testes. Não editar `.godot/` nem cenas `.tscn` manualmente. Não publicar fixtures como dados reais. O chat já está habilitado por padrão; não reimplementar gateway, serviços ou backend.
