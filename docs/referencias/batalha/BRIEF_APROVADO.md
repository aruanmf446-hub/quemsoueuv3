# QUEM SOU EU V3 — IMPLEMENTAÇÃO VISUAL DA TELA DE BATALHA

**Operador:** Codex  
**Projeto:** `aruanmf446-hub/quemsoueuv3`  
**Motor:** Godot 4  
**Referência visual:** imagem aprovada anexada  
**Resolução de referência:** 844 × 390 — horizontal (landscape)

## 1. Objetivo

Reconstruir a interface da tela de Batalha / Partida local seguindo a imagem de referência aprovada.

A tela deve apresentar qualidade visual de jogo comercial, com identidade cartoon premium, fundo azul-escuro, acabamentos grafite, contornos dourados discretos e ilustrações coloridas.

A imagem é a referência para a composição, mas a implementação precisa ser funcional e responsiva, não uma imagem estática.

**Não modificar regras do jogo, personagens, cartas, lógica de eliminação ou funcionamento existente.**

---

## 2. Organização da tela

A interface será dividida em quatro áreas principais.

| Região | Elementos |
|---|---|
| Topo esquerdo | Voltar e título da partida |
| Topo central | Avatares, nomes, vidas e reações dos jogadores |
| Centro | Instrução da rodada e tabuleiro de cartas |
| Coluna direita | Tempo, configurações, sala, chat de voz, chat de texto e cartas privadas |

Não criar uma lista de jogadores adicional na esquerda.

Os avatares dos jogadores devem existir somente no topo, evitando duplicação e poluição visual.

## 3. Layout de referência — 844 × 390

Usar as seguintes dimensões como ponto de partida, ajustando conforme o espaço real disponível:

| Elemento | Posição aproximada | Dimensão |
|---|---|---|
| Cabeçalho | Superior esquerdo | 155 × 34 |
| Jogadores | Superior central | 465 × 49 |
| Título da rodada | Acima das cartas | Altura 29 |
| Tabuleiro | Centro-esquerda | 625 × 255 |
| Coluna direita | Direita | Largura 185 |
| Controles superiores | Direita, topo | Altura 37 |
| Voz | Direita, abaixo dos controles | Altura 38 |
| Chat | Direita, centro | Altura flexível |
| Cartas privadas | Direita, inferior | Altura 90–105 |

Valores orientativos, não coordenadas absolutas obrigatórias. Utilizar containers e anchors para garantir adaptação.

### Hierarquia visual

**Primeira prioridade:** cartas públicas.

**Segunda:** jogador da vez e aviso da rodada.

**Terceira:** chat, cartas privadas e controles da sala.

Evitar painéis grandes ou elementos decorativos que reduzam a área disponível para as cartas.

---

# 4. ASSETS NECESSÁRIOS

Criar uma pasta organizada para a identidade visual da batalha, por exemplo:

`assets/ui/battle/`

Não mover nem duplicar imagens que já estão corretamente organizadas no projeto. Localizar e reutilizar os recursos existentes.

## A. Fundo da batalha

**Asset:** `battle_background.webp`

**Descrição:** fundo cinematográfico abstrato azul-marinho muito escuro, com formas geométricas discretas, diagonais, algumas áreas desfocadas e iluminação azul suave.

Características:

- Sem personagens.
- Sem textos ou botões embutidos.
- Baixo contraste para não competir com as cartas.
- Sem molduras medievais exageradas.
- Aparência moderna de interface de videogame.
- Adaptável a diferentes proporções de tela.

**Localização:** atrás de toda a interface.

O fundo poderá ser uma textura ou uma composição de elementos Godot. Evitar imagens pesadas desnecessárias.

## B. Moldura do tabuleiro

**Asset:** `battle_board_frame.png`

**Descrição:** painel grafite/azul-escuro com contornos geométricos discretos e filetes dourados finos.

O tabuleiro deve parecer uma peça integrada à interface, não uma mesa medieval.

Características:

- Centro escuro, sem detalhes que prejudiquem a leitura.
- Cantos angulares e acabamento premium.
- Leve iluminação nas bordas.
- Sem textos.
- Bordas escaláveis, preferencialmente via `NinePatchRect` ou `StyleBoxFlat`.

**Localização:** centro da tela, envolvendo o aviso da rodada e a galeria.

## C. Painéis de jogadores

**Assets conceituais:**

- `player_panel_normal`
- `player_panel_active`
- `player_panel_eliminated`

Preferir estilos Godot a três imagens completas quando possível.

**Normal:** fundo grafite-azulado com contorno sutil.

**Ativo:** fundo escuro com contorno dourado luminoso e animação leve de destaque.

**Eliminado:** fundo dessaturado, avatar escurecido e indicação clara de eliminação.

**Localização:** topo central.

Cada painel apresenta:

- Retrato real do personagem.
- Nome do jogador.
- Vidas restantes.
- Estado da partida.

Os avatares devem ter tamanho expressivo, mas nunca sobrepor nomes ou outros elementos.

## D. Avatares dos jogadores

**Fonte:** personagens já cadastrados no jogo.

Não criar novos personagens nem redesenhar as skins.

Reutilizar os retratos disponíveis ou gerar retratos a partir dos modelos 3D existentes quando necessário.

**Estados visuais necessários:**

1. Normal.
2. Jogador da vez.
3. Reação ao dano.
4. Eliminação/derrota.
5. Vitória.

As reações devem acontecer dentro do painel do jogador no topo.

Exemplo: João é eliminado. Seu avatar reage à derrota, o destaque desaparece, as vidas chegam a zero e o painel fica acinzentado.

Não abrir janelas adicionais para essas reações.

Se não existirem animações específicas, usar transições visuais simples sem alterar os modelos.

## E. Cartas públicas

**Assets:** ilustrações originais já utilizadas pelo sistema de cartas.

Não recriar, substituir ou inventar imagens.

Criar estilos reutilizáveis:

- `card_normal`
- `card_hover`
- `card_selected`
- `card_eliminated`

A carta tem:

- Ilustração ocupando a maior área.
- Tarja inferior preta translúcida.
- Nome centralizado.
- Contorno dourado fino.
- Cantos discretamente arredondados.

**Carta selecionada:** destaque dourado e pequena animação de escala, sem deslocar as demais.

**Carta eliminada:** escurecimento e indicação de eliminação.

Preservar a proporção da imagem e impedir distorções.

## F. Painel de chat

**Asset conceitual:** `battle_chat_panel`

Preferir implementação com `PanelContainer` e Theme.

Descrição:

- Fundo azul-escuro.
- Borda grafite.
- Cantos arredondados.
- Cabeçalho com ícone e título.
- Badge vermelho com contagem de novas mensagens.
- Mensagens organizadas por remetente.
- Campo de escrita inferior.

**Localização:** coluna direita, região central.

## G. Painel de cartas privadas

**Asset conceitual:** `battle_private_cards_panel`

Descrição:

- Mesmo estilo do chat.
- Título “Suas cartas” ou “Sua carta”, conforme quantidade.
- Ícone de cadeado.
- Prévia oculta quando recolhido.
- Botão de mostrar/ocultar.

**Localização:** abaixo do chat, na coluna direita.

A mão privada nunca deve se misturar visualmente com as cartas disponíveis para eliminação ou votação.

## H. Ícones

Utilizar ícones vetoriais limpos e consistentes.

| Ícone | Aplicação |
|---|---|
| Seta esquerda | Voltar |
| Ampulheta | Tempo |
| Engrenagem | Configurações |
| Copiar | Código da sala |
| Link/compartilhar | Convite |
| Microfone | Chat de voz |
| Microfone cortado | Voz desativada |
| Balão de conversa | Chat |
| Cadeado | Privacidade |
| Olho | Mostrar cartas |
| Olho cortado | Ocultar cartas |
| Coração | Vidas |
| Indicador de notificação | Novas mensagens |

Preferir SVGs leves ou recursos vetoriais já existentes.

Não usar emojis como substitutos permanentes de ícones profissionais.

---

# 5. FUNCIONAMENTO DE CADA ÁREA

## 5.1. Cabeçalho

**Localização:** canto superior esquerdo.

Elementos:

- Botão Voltar.
- Título “Batalha · Partida local”.

Manter compacto, sem subtítulos desnecessários.

O botão Voltar deve respeitar o comportamento de navegação existente.

## 5.2. Participantes

**Localização:** faixa superior central.

Exibir os jogadores da partida com retrato, nome e vidas.

O jogador da vez recebe destaque dourado.

Reações visuais acontecem no próprio avatar.

A distribuição precisa funcionar também com quantidades diferentes de participantes, sem sobreposições.

Não duplicar lista de jogadores na esquerda.

## 5.3. Instrução da rodada

**Localização:** imediatamente acima das cartas, dentro da área principal.

Durante o turno do usuário:

“É a sua vez!”

“Escolha uma carta para eliminar.”

Quando outro jogador estiver na vez, substituir o texto pelo estado real da rodada.

Utilizar dados reais do jogo, sem mensagens fixas.

O título deve ser visível, mas compacto.

## 5.4. Tabuleiro de cartas

**Localização:** centro da tela.

O tabuleiro deve ser o maior elemento visual da interface.

Utilizar grid dinâmico com até nove cartas por composição 3×3, conforme os dados reais.

**Regras obrigatórias:**

- Todas as cartas disponíveis para a ação devem aparecer simultaneamente.
- Não utilizar rolagem horizontal ou vertical.
- Não usar carrossel nem paginação.
- Não ocultar cartas nas bordas.
- Não favorecer posições por diferença de tamanho.
- Nomes sempre legíveis.
- Preservar imagens e estados reais.
- Não adicionar cartas fictícias para completar a grade.

Se houver sete cartas, mostrar as sete cartas existentes e distribuir o espaço adequadamente.

Se houver nove, apresentar as nove.

Durante a eliminação ou votação, preservar a visibilidade integral de todas as opções disponíveis.

Não modificar a lógica de seleção já existente.

## 5.5. Temporizador e configurações

**Localização:** canto superior direito.

Exibir:

- Temporizador da rodada.
- Botão Configurações.
- Código da sala com ação de copiar/compartilhar.

O tempo precisa ser atualizado pelo estado real da partida.

Usar uma indicação visual discreta quando estiver terminando, sem efeitos excessivos.

O botão Configurações deve abrir o menu correspondente, sem criar um segundo sistema de configurações.

## 5.6. Código da sala

Exibir um código curto de sala, com ação de copiar e acesso ao link de convite quando a sessão permitir.

Não usar `ABC123` como código fixo; isso é apenas ilustrativo.

Em partidas locais offline sem sala ou convite, não exibir controles falsamente funcionais.

A apresentação deve depender do modo real da partida.

## 5.7. Chat por voz

**Localização:** coluna direita, acima do chat de texto.

Criar um controle compacto com:

- Ícone de microfone.
- Estado atual.
- Ação para ativar/desativar.

Estados:

- Ativado: indicador verde.
- Desativado: indicador neutro.
- Silenciado: microfone cortado.
- Falha ou indisponibilidade: estado apropriado.

Quando houver comunicação real, poderá existir um indicador sutil no painel do jogador que estiver falando.

**Importante:** não simular chat por voz funcionando. Integrar ao recurso real quando existir e informar qualquer dependência ainda ausente.

## 5.8. Chat de texto

**Localização:** coluna direita, abaixo do chat de voz.

Deve apresentar:

- Remetente.
- Mensagem.
- Histórico.
- Campo de digitação.
- Botão enviar.
- Notificação de mensagens novas.

O chat pode ser recolhido.

Quando aberto, utiliza a área reservada da coluna direita.

**Jamais cobrir as cartas públicas durante escolha ou votação.**

A rolagem interna do histórico do chat é permitida. A proibição de rolagem se aplica à galeria de cartas.

## 5.9. Cartas privadas

**Localização:** parte inferior da coluna direita.

Painel separado, com:

- Título.
- Ícone de privacidade.
- Quantidade real de cartas.
- Botão mostrar/ocultar.
- Miniatura ou verso da carta conforme o estado.

As cartas permanecem ocultas por padrão.

Ao expandir, devem utilizar a própria região lateral ou uma apresentação que preserve o tabuleiro, sem encobrir as opções de votação.

Garantir que as regras reais de sigilo sejam respeitadas.

---

# 6. COMPORTAMENTO VISUAL

## Reações dos jogadores

Criar transições curtas:

- Jogador da vez: borda dourada.
- Dano recebido: reação breve do avatar e atualização das vidas.
- Eliminação: reação de derrota, dessaturação e estado inativo.
- Vitória: realce de comemoração.

Usar animações existentes quando disponíveis.

Não adicionar efeitos que tornem a interface pesada.

## Interação com cartas

A carta deve responder imediatamente ao toque ou clique.

Adicionar feedback visual de seleção e manter os estados sincronizados com a lógica do duelo.

Nunca deslocar outras cartas durante o destaque.

## Avisos da partida

Exemplos:

- Partida iniciada.
- Sua vez.
- Carta eliminada.
- Jogador eliminado.

Apresentar notificações temporárias em uma região que não encubra o tabuleiro.

Evitar caixas permanentes no canto inferior esquerdo, como na imagem conceitual.

---

# 7. PADRÃO VISUAL

| Propriedade | Direção |
|---|---|
| Fundo | Azul-marinho quase preto |
| Painéis | Grafite e azul-escuro |
| Destaques | Dourado/âmbar |
| Textos | Branco e cinza-claro |
| Vidas | Vermelho |
| Chat de voz ativo | Verde |
| Notificações | Vermelho |
| Bordas | Finas e discretas |
| Cantos | Levemente arredondados |
| Sombras | Suaves |
| Tipografia | Moderna, legível e consistente |

Evitar:

- Molduras medievais ornamentais.
- Brilhos exagerados.
- Textos gigantes.
- Elementos genéricos de formulário.
- Excesso de botões.
- Ícones sem função.
- Telas intermediárias desnecessárias.
- Espaços vazios grandes.
- Interface com aparência de site em vez de jogo.

---

# 8. IMPLEMENTAÇÃO NO GODOT

Utilizar o sistema nativo de UI do Godot.

Componentes recomendados:

- `Control`
- `MarginContainer`
- `HBoxContainer`
- `VBoxContainer`
- `GridContainer`
- `PanelContainer`
- `TextureRect`
- `NinePatchRect`
- `Label`
- `Button`
- `ScrollContainer` somente no histórico do chat
- `AnimationPlayer` ou `Tween`

Reutilizar cenas, scripts, dados e sinais existentes.

Não reconstruir o sistema de batalha do zero.

Separar apresentação visual de lógica de jogo.

As cartas devem ser instanciadas dinamicamente a partir dos dados existentes, não codificadas individualmente.

Evitar `SubViewport` de baixa resolução para retratos, preservar a qualidade das texturas e impedir ampliação de miniaturas pequenas.

## Resolução e adaptação

A resolução principal de referência é **844 × 390**, em modo horizontal.

Garantir:

- Adaptação a outras proporções landscape.
- Área segura em celulares com recortes.
- Todos os botões acessíveis.
- Textos legíveis.
- Cartas sem corte.
- Nenhum elemento importante fora da tela.
- Sem necessidade de rolagem do tabuleiro.

Se a composição precisar ser compactada, reduzir primeiro decoração e espaçamentos, não eliminar cartas nem elementos funcionais.

---

# 9. CRITÉRIOS DE APROVAÇÃO

A implementação será considerada aprovada somente quando:

1. O resultado visual estiver fiel à referência anexada.
2. Os avatares aparecerem no topo, com vidas e estados.
3. O jogador da vez estiver destacado.
4. As cartas disponíveis aparecerem simultaneamente, sem rolagem.
5. O chat estiver na direita, sem cobrir o tabuleiro.
6. As cartas privadas estiverem abaixo do chat, com controle de visibilidade.
7. Temporizador e configurações estiverem acessíveis.
8. Código da sala, convite e voz respeitarem as funcionalidades reais do modo.
9. As notificações não encobrirem cartas.
10. A tela funcionar em 844×390.
11. Não existirem textos, cartas ou personagens fictícios introduzidos apenas para reproduzir a imagem.
12. A lógica atual da batalha permanecer intacta.

# 10. INSTRUÇÃO FINAL AO CODEX

Antes de implementar, examine a estrutura atual do jogo, identifique os assets já disponíveis, a cena responsável pela batalha local e os scripts associados.

**Execute a implementação visual diretamente no projeto. Não entregue somente um planejamento.**

Preserve as funcionalidades atuais.

Priorize acabamento visual, qualidade dos retratos, organização dos componentes e legibilidade em dispositivo móvel.

Ao finalizar, entregue:

- Relação dos arquivos modificados.
- Relação dos assets reutilizados e novos assets efetivamente necessários.
- Captura da interface renderizada em 844×390.
- Resultado dos testes possíveis.
- Funcionalidades implementadas.
- Dependências pendentes, especialmente voz e compartilhamento de sala.

Não afirmar que algo está funcional sem ter implementado ou validado.

**Resultado esperado:** a tela de Batalha do Quem Sou Eu V3 deve reproduzir a composição da referência aprovada, mantendo a identidade visual premium e a jogabilidade integral do projeto.