# Mata-Mata: reações e confirmações contextuais

Branch: `work/duel-avatar-apresentacao`. Melhorias incrementais sobre a versão publicada;
não altera regras de vitória, autenticação, inventário, economia ou Modo História.

## Implementação

- Sala Mata-Mata: o avatar equipado toca `anim_2` no campo existente, com uma
  instância preservada entre atualizações. Os demais retratos continuam leves e
  recebem sua apresentação animada na contagem.
- Contagem: apresenta os participantes numerados na ordem recebida da autoridade,
  com o mesmo `LobbyStage`/`CharacterSlot`, transições curtas e o FX existente
  `battle_pick.wav`. Um palco por apresentação, sem um viewport por jogador.
- Música: efeito temporário de −10 dB no bus Music; não interrompe a faixa nem muda
  a preferência de volume. O efeito sai ao terminar ou abandonar a apresentação.
- Local: sorteio único ao criar a partida; a ordem fica disponível desde a seleção.
  A contagem reserva 1,8 s por participante, com mínimo de 5 s.
  Jogadores eliminados são pulados pela regra já existente, sem sortear novamente.
- Derrota: `anim_3` toca no retrato do eliminado após o resultado aparecer,
  mantendo a carta escolhida visível.
  Vitória: `anim_4` na apresentação dos vencedores. As reações respeitam os prazos
  existentes: não obrigam a partida a aguardar o clipe inteiro. O primeiro turno
  encerra qualquer apresentação inicial ainda aberta.
- Preparação assíncrona dos recursos dos participantes durante a seleção; cache dos
  clipes e cópias das bibliotecas preservam os recursos importados. Instanciação e
  compilação de shaders continuam dependendo do desempenho do dispositivo.
- ✓ verde e ✕ vermelho sobre a carta/deck: controles nativos com foco e tooltip,
  estilos em `PlayerUI.decision_controls`. A seleção incompleta fica bloqueada.
  Confirmações em andamento não podem enviar uma segunda ação pela mesma tela.
- A carta removida desaparece da galeria depois da revelação; as removidas de
  rodadas anteriores permanecem ocultas durante os próximos suspenses.
- A interface conserva vidas/mão anteriores durante o suspense e a animação de
  entrada. Título e lista de atingidos só aparecem no momento da revelação.
- Bots locais têm três estilos de fala, marcados como BOT, sem consultar cartas
  secretas. Há intervalo e deduplicação por evento para evitar mensagens repetidas.

## Assets existentes

Nenhum personagem, FBX, textura ou animação foi criado, substituído ou apagado.
Os sete avatares principais têm as entradas `anim_2`, `anim_3`, `anim_4` no catálogo.
O teste percorre os 21 clipes e verifica movimento nos ossos do modelo principal.
A numeração segue a orientação do dono; os arquivos não possuem uma classificação
semântica confiável de lobby/derrota/vitória para confirmar automaticamente a intenção.

**El Fuego:** o catálogo tem `agachado`, `ataque`, `defesa`, `morte`, saltos e
`retorno`, mas não `anim_2/3/4`. Sua apresentação preserva a pose existente.
Não foi atribuída uma reação diferente nem criada uma animação substituta.

## Pendências para o responsável pelo backend

Não houve acesso ao Supabase nem alteração de migrations ou Edge Functions.
O cliente online não sorteia uma ordem própria e não publica mensagens em nome de bots.

1. **Ordem online:** conferir `qse_duel_start`/avanço de fase e retornar `turn_order`
   imutável já na seleção/contagem. Sortear uma única vez, persistir e usar essa mesma
   sequência em todos os clientes; avançar atomicamente apenas uma vez por ação/prazo,
   ignorando eliminados. Reservar tempo para a apresentação antes do primeiro turno.
   Se a API não retornar a ordem antes dos turnos, esta versão não inventa uma intro
   divergente. O salto ocasional de turnos online não foi reproduzido nem dado como resolvido.
2. **Chat de bots online:** gerar e persistir mensagens pelo servidor no contrato
   existente de chat, identificando o bot e deduplicando por partida/evento. Não
   permitir que um cliente se passe por outro participante. As personalidades desta
   entrega estão habilitadas somente nas partidas locais.
3. Validar com dois clientes reais simultâneos: mesma ordem, uma ação por turno,
   latência/reconexão e mensagens compartilhadas. Sem esse teste não há afirmação
   de correção do servidor online.

## Reproduzir os testes

Godot 4.7.2 oficial, executado na raiz do projeto:

```bash
godot --headless --path . --script res://tests/duel_avatars/animations.gd
godot --headless --path . --script res://tests/duel_avatars/interactions.gd
godot --headless --path . --script res://tests/duel_local/flow_test.gd
godot --headless --path . --script res://tests/battle_reveal/flow.gd
python3 tools/player_ui/check_design.py
node tests/web_pwa/sw_test.js
# Capturas com janela real, inclusive perfil exclusivo do iPhone:
xvfb-run -a godot --audio-driver Dummy --path . --script res://tests/duel_avatars/interactions.gd -- /tmp/avatar-shots 1672x941
QSE_TEST_IPHONE=1 xvfb-run -a godot --audio-driver Dummy --path . --script res://tests/duel_avatars/interactions.gd -- /tmp/avatar-shots 844x390 --iphone
QSE_TEST_IPHONE=1 xvfb-run -a godot --audio-driver Dummy --path . --script res://tests/duel_avatars/interactions.gd -- /tmp/avatar-shots 640x360 --iphone
```

Os testes de interação usam uma partida local e uma fixture de vidas explicitamente
identificada para provocar a derrota. Não simulam validação de servidor nem iPhone físico.
Resultados e capturas: [evidence/duel-avatars](../evidence/duel-avatars/README.md).
