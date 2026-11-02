# Proporções dos controles — revisão universal

Base: `main` em `9cc21e8`. Mantidos viewport 1672×941, stretch `canvas_items/expand`,
`PlayerUI.unit() == 1` e `UIScale.unit_for() == 1`. Nenhuma mudança em `project.godot`,
no tamanho da tela, na densidade por dispositivo ou no enquadramento dos personagens.

O ajuste é de componentes, não de zoom. As medidas são unidades da base de design:

| Componente | Antes | Depois |
| --- | --- | --- |
| Botão compartilhado | altura 52 / fonte 21 | altura 64 / fonte 26 |
| Voltar padrão | 100×44 / fonte 16 | 152×60 / fonte 26 |
| Abas do lobby | altura 44 / fonte 15 | altura 64 / fonte 24 |
| Jogar no lobby | 320×64 / fonte 22 | 460×116 / fonte 40 |
| Novidades | 140×38 / fonte 12 | 248×88 / fonte 30 |
| Miniplayer | altura 52 / transporte 44 | altura 224 / transporte 104 |

As abas do lobby calculam o encaixe pela largura da base, para que telas mais largas
não alterem a fonte nem a dimensão dos controles. Botões Equipar e Entrar na conta
não se esticam por toda a largura disponível. Busca, filtros, abas da Biblioteca,
seleção de reino/fase, Configurações, Personagens e música usam medidas maiores e
coerentes. As listas e galerias preservam a rolagem já existente.

## Evidências

Capturas reais do Godot 4.7.2, renderizador Compatibility com Mesa llvmpipe em Xorg.
Não são capturas de Safari/Chrome nem validação em telefone físico. As miniaturas e
os modelos são os existentes; não foram criados assets artísticos novos.

Os nomes dos arquivos indicam a resolução física da janela. Todas usam a mesma
base lógica, inclusive no teste com `--ui-scale=3` (densidade simulada).

- [Lobby antes, 844×390](antes-lobby_844x390.png)
- [Lobby depois, 844×390](lobby_844x390.png)
- [Personagens, 844×390](skins_844x390.png)
- [Configurações, 844×390](settings_844x390.png)
- [Biblioteca, 844×390](deck_library_844x390.png)
- [Métricas por resolução](metrics.json)

Este material é para avaliação visual do proprietário, não representa aprovação estética.
A pasta é ignorada pelo importador do Godot, para não aumentar o pacote do jogo.

## Verificação reproduzível

```bash
python3 tools/player_ui/check_design.py
python3 tools/godot/run_smoke.py --godot /caminho/Godot_v4.7.2-stable_linux.x86_64
# Requer display gráfico. Saída e dados de teste em diretórios graváveis e isolados.
XDG_DATA_HOME=/tmp/qse-ui-data XDG_CONFIG_HOME=/tmp/qse-ui-config \
  godot --audio-driver Dummy --path . --script res://tests/responsive/control_sizes.gd \
  -- /tmp/qse-ui-evidence --ui-scale=3
```

`control_sizes.gd` abre as telas reais em 1920×1080, 1280×720, 844×390 e 640×360.
Compara medidas e fontes de navegação entre resoluções e verifica os limites da tela.
Abas que preenchem o painel podem ganhar largura com o espaço extra, mantendo altura
e fonte. Captura também as cinco categorias de Configurações.

## Limitações de testes legados

Duas suítes antigas, não modificadas nesta entrega, têm expectativas anteriores à main
atual: `tests/music_t15b/verify.gd` exige quatro abas e abre Áudio no índice zero (hoje
existem cinco e o índice zero é Meu Perfil); `tests/audio/test_menu_music.gd` exige que
as 14 faixas estejam pendentes de autorização (o catálogo atual já está autorizado).
Elas falharam e foram interrompidas após acesso a elementos inexistentes. A integração
atual é coberta por `tests/ui_session_music/flow_test.gd`, `tests/settings_t22/flow_test.gd`
e pela regressão Web do smoke; as três passaram.

## Resultados desta execução

- Smoke: 31/31 grupos aprovados.
- Configurações: 17/17; Amizades: 23/23; Biblioteca: 128/128; sessão/música: 15/15.
- Primeira rodada: 113 verificações aprovadas; os registros anteriores estão preservados com sufixo `primeira_rodada`.
- Design: aprovado pelo verificador técnico. Avaliação estética continua pendente.

## Segunda rodada — correções após avaliação do proprietário

Personagens e Configurações foram aceitos e permaneceram intactos nesta rodada.
As alterações se restringem ao lobby, player de música e capa de destaque da Biblioteca:

- Jogar: 460×116, fonte 40; Novidades: 248×88 e Ver amigos: 280×88, ambos com fonte 30.
- Música: 400×224 em duas linhas; capa e título em cima, três controles de 104×104 abaixo.
  O painel mantém espaço para o personagem e todas as funções de transporte.
- Capa da Biblioteca: altura 440 (antes 236), título 50 e ação de explorar com altura 80.
  As imagens mantêm o enquadramento do componente CinematicBanner, sem distorção.

A rodada focada passou 72 verificações nas quatro resoluções e densidade simulada 3.
Para reproduzir só esta revisão, acrescente `--lobby-library` ao comando de captura.
Biblioteca: 128 verificações; sessão/música: 15 verificações, ambas sem falhas.
Os testes de captura e sessão/música ainda emitem avisos de ObjectDB ao sair; os logs
estão incluídos. Não se trata de validação no navegador ou em aparelho físico.

## Preparação da publicação aprovada

O proprietário aprovou o visual da segunda rodada e autorizou a publicação na main.
O teste de navegação real da Biblioteca passou a rolar até a coleção antes do clique:
a capa mais alta pode colocar esse cartão abaixo da área visível. Nenhuma verificação
foi removida ou relaxada. Resultado: 66 verificações aprovadas; o aviso de ObjectDB ao
sair está registrado em `library_navigation.log`. As demais 12 suítes da etapa T21 do CI
foram executadas localmente e concluíram com código zero, sem erro de script.
