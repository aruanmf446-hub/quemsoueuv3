# Mata-Mata: proporção e apresentação

Pedido do dono em 09/11/2026: estabilizar jogadores/chat/cartas e separar as
animações dos avatares da galeria, reutilizando modelos e clipes existentes.
Branch `work/duel-layout-avatar-stage`. Sem publicação automática nesta entrega.

## Implementação

- A carta usa a imagem original inteira (KEEP_ASPECT_CENTERED), sem AtlasTexture
  de recorte focal. Slot retrato 9:16, legenda separada da arte.
- A grade considera o pool original, não a contagem restante; eliminar cartas não
  altera o formato de todas as demais. Resize real da janela continua suportado.
- Jogadores têm faixa reservada com rolagem para grupos grandes. Chat e mão
  privada mantêm espaço ao abrir/fechar; a mão tem rolagem própria.
- Palco opaco separado, um único viewport 3D reutilizado, nome e posição na ordem,
  fade suave e Continuar acessível por teclado. Sem FBX sobre as cartas reveladas.
- Lobby usa anim_2; ao final os vencedores reais recebem anim_4 e os demais anim_3.
  Não foram criados modelos, clipes, skins ou movimentos substitutos.
- Seis segundos configurados por participante depois de carregar, incluindo fades.
  O relógio local reserva tempo para isso e uma margem de carga; ao terminar/pular
  a apresentação, o servidor local avança sem esperar toda a margem restante.
- Resultados permanecem visíveis se o servidor voltar ao lobby durante a sequência;
  uma nova partida interrompe a apresentação anterior. Derrota é apresentada no
  encerramento, evitando tapar um turno ao vivo.

## Limite online acordado

O dono rejeitou trabalho adicional no Supabase. Nenhum backend, SQL, chave ou
contrato online foi modificado/acessado. A apresentação inicial online respeita a
contagem existente e é interrompida quando começar o turno; não garante seis
segundos para todos nesse trecho. O resultado final não cobre um turno ativo.
Sem teste de sessão online real nesta entrega.

## Conferência

- Godot 4.7.2: partida local completa, 91 verificações aprovadas.
- Teste novo de geometria: 57 verificações em cada janela 1672×941, 844×390 e
  640×360. Fixtures locais, sem dados de produção.
- Transições de apresentação: dez verificações aprovadas, incluindo pular a
  intro local, ignorar conclusão de partida antiga, conservar resultado na volta
  ao lobby e liberar a próxima partida.
- Três clipes nativos, Continuar por teclado e restauração do efeito temporário
  de áudio: failures=0. As capturas nativas do palco antecedem o aumento de
  fill_ratio de 0.62 para 0.72; conferir evidência Web para a versão final.
- Renderização software com carga fria foi lenta (8.9–21.8s incluindo carregamento).
  Seis segundos configurados não são promessa de FPS ou duração física nesse host.
- `tests/battle_reference/flow.gd`: 388 checks, nove falhas, log preservado.
  O teste ainda clica nos antigos ConfirmSelection/CancelSelection ocultos em vez
  de AcceptSelection/RejectSelection sobre a carta e contém expectativas antigas
  de tempo da revelação. Não foi declarado aprovado nem removido do CI.
- Runner `tests/battle_reveal/flow.gd`: completou, BATTLE_REVEAL shown=2; sem
  comprovação de interação por esse runner visual.
- Design checker e diff check aprovados. Nenhuma validação em aparelho físico.

Evidências: `evidence/duel-stage-layout/` e `evidence/duel-avatar-stage/native/`.
Nenhum arquivo de área congelada ou política de proteção foi alterado.

## Resultado Web desta bateria

Desktop Chromium: artes completas9:16 e dimensões idênticas nas quatro mudanças
(turnos, remoção, mão e chat), mais capturas dos três clipes no palco final.
A confirmação por clique falhou no runner ao não localizar AcceptSelection;
a causa não foi concluída. Os perfis Web móveis não foram alcançados.
Não declarar a bateria Web completa aprovada. As três janelas nativas passaram
57 checks cada na fonte final, incluindo duas imagens privadas inteiras no
limite final de96 unidades. O export Web anterior tinha a mão vazia nesse teste.
