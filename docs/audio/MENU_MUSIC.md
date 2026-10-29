# T11 — Música exclusiva do menu

Autoload `MenuMusic` (`MenuMusicPlayer`), Godot 4.7.2. A entrega inclui código funcional,
mas não inclui faixas: o catálogo inicial vazio fica silencioso.
Nenhuma tela, cena, serviço online, economia ou lógica de gameplay foi alterada.

## Catálogo e licenciamento

Edite `data/music/catalog.json`, versão 1. `fade_seconds` aceita 0.05 a 5 segundos.
Adicione cada faixa somente depois de receber áudio, capa e autorização correspondentes.
Campos obrigatórios por entrada (descrição de formato, não uma faixa fictícia):

| Campo | Valor |
| --- | --- |
| id | Identificador único e estável, string não vazia |
| title | Título real, string não vazia |
| artist | String; vazia enquanto os metadados estão pendentes (a tela mostra "metadados pendentes") |
| audio | Caminho `res://assets/music/` para AudioStream importado: OGG, MP3 ou WAV |
| cover | Caminho `res://assets/music/` para Texture2D importada |
| enabled | Booleano `true` para disponibilizar |
| license.status | `approved`; qualquer outro valor bloqueia |
| license.scope | `main_menu` |
| license.reference | Referência interna não vazia à autorização; não incluir contrato privado |
| license.starts_at | Unix UTC numérico, inclusivo, não negativo |
| license.ends_at | Unix UTC numérico, exclusivo, obrigatório e finito |

Todos os campos `license.*` ficam dentro do objeto `license`. Áudio e capa precisam
existir e ter os tipos corretos. Entradas inválidas, duplicadas, pendentes, revogadas,
desativadas, futuras, expiradas ou sem recursos são ignoradas. Falha na leitura do
catálogo interrompe a reprodução. Não há downloads ou chamadas de rede.

O controle é editorial local, dependente do relógio do dispositivo; não é DRM nem
validação jurídica. Para retirar autorização, desative/remova a entrada ou mude
`license.status`, então publique o catálogo atualizado. Arquivos já distribuídos
não são remotamente revogáveis por este sistema. Expiração por horário é verificada
durante a reprodução, inclusive no canal que está saindo da transição.

Importe áudio e capa no editor e reexporte o jogo após mudar o catálogo. Os presets
existentes exportam todos os recursos e incluem JSON. Sem arquivo autorizado, não
adicione uma entrada habilitada. Remover uma faixa não exige mudar o player.

## Transporte e integração

Disponível em `/root/MenuMusic`, sem elementos visuais novos:

- `next_track()` / F8; `previous_track()` / F6.
- `pause()` e `resume()` / F7 alterna.
- `set_volume(0.0 ... 1.0)`; `set_muted(bool)` / F9 alterna.
- `current_track()` retorna cópia dos metadados; `available_tracks()` retorna cópias
  das faixas elegíveis. `track_changed(track)` e `state_changed` permitem UI futura.
- `reload_catalog(path = CATALOG)` permite recarregar a configuração local.

Atalhos usam teclas físicas, somente no menu e apenas quando o evento não foi
consumido por uma tela. Controles touch/visuais podem chamar a mesma API futuramente;
a composição do lobby, Skins e Configurações foi preservada.

O barramento `Music` recebe o volume persistido pelo `DevicePreferences` existente,
incluindo o Master. Mudo usa volume zero; restaurar pelo transporte recupera o último
volume desta sessão. O slider de música existente continua sendo a fonte persistida.

Dois AudioStreamPlayers fazem crossfade, incluindo antecipação ao fim da faixa.
Próxima/anterior percorrem o catálogo circularmente e pulam entradas indisponíveis.
Trocas rápidas cancelam transições antigas. Flags de loop importadas são desligadas
somente na cópia do stream usada pelo player para permitir avançar na playlist.

Apenas `scenes/menu/main_menu.tscn` autoriza reprodução. Suas telas filhas mantêm a
música. `tree_exiting` para os dois canais imediatamente antes da saída do menu;
nenhuma música do menu acompanha gameplay ou outras cenas. Ao voltar, o autoload
restaura faixa/posição, respeitando pausa manual e licença ainda válida. Estado de
transporte não é salvo entre execuções do jogo. Nenhum arquivo de gameplay foi tocado.

## Validação

Execute `python3 tests/audio/run.py --godot /caminho/Godot_v4.7.2-stable_linux.x86_64`.
O runner cria um projeto temporário, áudio PCM inteiramente zerado e uma capa técnica.
Não gera música e não adiciona áudio ao repositório. Testa transporte real do motor,
licenças, volume, cancelamento de fades, sequência automática e isolamento por cena.
As fixtures são removidas automaticamente. Não depende de contas ou Supabase.

Também foram executados import completo e inicialização headless do menu real no
Godot `4.7.2.stable.official.ed1daf0bf`. A validação automatizada não substitui escuta
manual e conferência do material/licença quando as parcerias entregarem os arquivos.

## Organização e seleção das faixas (T14A)

O catálogo lista as 14 faixas de `assets/music/` por categoria (Alternative 3, Funk 1,
K-pop 3, Pop 3, Trap 4). Todas estão com `enabled: false` e `license.status: "pending"`,
sem artista registrado (metadados pendentes) e capas ainda inexistentes. Nenhuma toca até receber
autorização registrada. Os MP3 (73 MB) não são versionados nesta branch; importe-os no
editor antes de testar.

A tela Músicas (`scenes/player/music.tscn`, rota `music`) separa as faixas por categoria.
Cada faixa tem "Tocar no menu" (desmarcar tira da playlist) e "Ocultar" (some da lista e da
playlist; "Reexibir" desfaz). Salvar grava `user://menu_music_selection.cfg` e aplica na
hora. Descartar volta ao último estado salvo; sair da tela também descarta o rascunho.
Entrada prevista: Configurações → Áudio → Gerenciar músicas, chamando `navigation.open("music")`. Configurações não foi editada nesta branch.

Validação: `tools/godot/music_flow.gd` (35 verificações: catálogo pendente, seleção
persistida, próxima, anterior, pausa, volume, mudo, saída do menu e tela). As faixas de
teste usam áudio real importado com licença fictícia só em memória; nada disso vai ao
catálogo. Capturas: `tools/godot/capture_music.gd`.
