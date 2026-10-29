# Música exclusiva do menu — integração T15B

Autoload `MenuMusic` (`MenuMusicPlayer`), Godot 4.7.2. A integração T15B reaproveita a T14A e conecta a tela Músicas às Configurações T14B da main `e3de674`. O catálogo contém 14 metadados pendentes; nenhum MP3 é versionado. Serviços online, Personagens, economia e gameplay foram preservados.

## Catálogo e licenciamento

Edite `data/music/catalog.json`, versão 1. `fade_seconds` aceita 0.05 a 5 segundos.
Adicione cada faixa somente depois de receber áudio, capa e autorização correspondentes.
Campos obrigatórios por entrada (descrição de formato, não uma faixa fictícia):

| Campo | Valor |
| --- | --- |
| id | Identificador único e estável, string não vazia |
| title | Título real, string não vazia |
| artist | String; vazia enquanto os metadados estão pendentes, sem artista inventado |
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


## Seleção e acesso (T14A integrada na T15B)

No menu principal: **Configurações → Áudio → Gerenciar músicas**. A navegação registra a rota `music` e volta ao painel Áudio ao pressionar Voltar. O arquivo atual de Configurações recebeu apenas o botão de acesso; os quatro grupos, escalonamento, estilos, mudo e preferências da T14B foram mantidos.

Categorias: Alternative (3), Funk (1), K-pop (3), Pop (3), Trap (4). O catálogo da T14A foi preservado byte a byte: 14 faixas, todas `enabled=false`, `license.status=pending`, sem artista/capa inventados. Sem autorização de distribuição registrada, a playlist normal fica silenciosa.

“Tocar no menu”, “Ocultar” e “Reexibir” trabalham num rascunho. “Salvar” persiste `user://menu_music_selection.cfg`; “Descartar” e reabrir a tela restauram o último estado salvo. A API de transporte, atalhos e barramentos de volume existentes continuam em uso. Nenhuma música toca fora da cena do menu principal.

## Teste local autorizado, separado de distribuição

Para usar arquivos locais que você tem autorização para testar, importe-os nos caminhos de `audio` registrados no catálogo e inicie o executável **do editor** com:

```sh
Godot_v4.7.2-stable_linux.x86_64 --path /workspace/quemsoueuv3 -- --local-music-test
```

Abra Gerenciar músicas e marque **“Tenho autorização para teste local nesta sessão”**. A opção aparece apenas nesse modo explícito do editor; builds exportadas não podem habilitá-la. Desmarcar interrompe a reprodução de teste. Nada é salvo como autorização: nem `license.*` nem `enabled` são alterados. As faixas continuam identificadas como pendentes para distribuição. A capa não é exigida para teste local, mas permanece exigida no caminho normal de licenciamento. A escolha de faixas/ocultação continua valendo nesse modo.

MP3s locais são ignorados pelo Git. Isso não fornece licença nem permissão para incluí-los em um pacote exportado. Não há MP3 nesta entrega. Os testes de reprodução usam somente PCM inteiramente zerado gerado temporariamente, sem faixas reais nem autorizações comerciais fictícias.

## Evidências T15B

Ver `tests/music_t15b/README.md`. O teste de captura usa o botão real de Configurações no menu e um clique de mouse em Gerenciar músicas; não instancia a tela Músicas diretamente. As verificações cobrem seleção, persistência, descarte, categorias, autorização local, transporte, volume, saída/retorno ao menu e regressão das Configurações T14B.
