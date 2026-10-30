# Tarefa 03 — telas e sistemas do jogador

Implementação na branch `codex/telas-sistemas-jogador-03`, baseada em `d90dcb5` (`codex/progressao-offline-02`). O menu de fantasia e o palco 3D existentes continuam sendo a entrada do projeto. Não foi executado Godot ou Blender, e nenhuma migration foi aplicada ao Supabase remoto.

## Telas implementadas

| Acesso no menu | Cena | Implementação |
| --- | --- | --- |
| Card do jogador | [Perfil](../../scenes/player/profile.tscn) | Avatar derivado da skin, prévia 3D, nickname editável, ID público, nível/XP/estatísticas opcionais, conquistas e reinos. |
| Perfil de um amigo | [Perfil público](../../scenes/player/public_profile.tscn) | Apenas campos públicos autorizados; um modelo carregado sob demanda. |
| Configurações | [Preferências](../../scenes/player/settings.tscn) | Áudio, perfis gráficos existentes, idioma, teclas dos menus, tela cheia Web, conta e descoberta do perfil. |
| Amizades / ícone de mensagens | [Amizades](../../scenes/player/friends.tscn) | Busca, recebidas, enviadas, aceitar/recusar/cancelar/remover, presença e perfil público. |
| Moedas / gemas | [Carteira](../../scenes/player/wallet.tscn) | Saldos, histórico paginado, atualização e estados de conexão. |
| Skins | [Painel existente aprimorado](../../scenes/skins/skins_panel.tscn) | Miniaturas em cache, prévia 3D, descrição, bloqueio, equipamento e retorno. |
| Modo História | [Reinos e fases](../../scenes/player/story.tscn) | Quatro reinos e dez fases do Deserto; somente a fase 1 oferece abrir sua cena de protótipo. |
| Entrar / conta | [Supabase Auth](../../scenes/player/account.tscn) | Login, cadastro sujeito a confirmação de e-mail e saída da sessão local. |

`NavigationManager` instancia cada rota uma única vez, mantém histórico com parâmetros, restaura foco, oferece Voltar/Esc/Android Back e anima a abertura. `StateBanner` compartilha carregamento, sucesso, vazio, offline, erro e acesso não autorizado. As telas usam superfícies escuras e discretas com filete dourado no item principal/selecionado, sobre o fundo do lobby, com containers e rolagem (modelo em [`docs/referencias/README.md`](../referencias/README.md)). O layout e sua aparência ainda precisam ser vistos no motor.

## Dados e comportamento entregue

`PlayerServices` compõe serviços únicos para sessão, perfil, inventário, progressão, amizades, presença, carteira e preferências. Menu, lobby e telas observam esses mesmos serviços. O equipamento online passa pela revisão v2 e pela autorização do servidor, sem atualização otimista de desbloqueios.

Sem chave pública/sessão, o menu identifica **Demonstração local**. Só as sete skins inicialmente liberadas podem ser equipadas, em um save próprio de demonstração. Saldos, XP, vitórias e amigos não são inventados; campos ausentes usam `—` ou estados vazios. Os zeros de uma carteira nova só aparecem quando retornados pela linha realmente criada no banco.

O catálogo conserva os oito IDs equipáveis. El Fuego exige `desert_campaign_completed`, concedida após dez conclusões sequenciais com provas do servidor e derrota de Malagueta na décima fase. Cactus e Malagueta não entram no inventário. O protagonista El Fuego da cena original da campanha continua independente desse bloqueio.

Abrir o protótipo não registra conclusão, não concede recompensa e não implementa combate. Um controle de retorno envolve a cena original sem modificar seu script, física, câmera ou conteúdo. Fases sem cena permanecem explicitamente em desenvolvimento. Floresta, Mar e Lunar não recebem campanhas fictícias.

## O que falta conectar ou validar

- **Backend:** revisar e aplicar as migrations em ambiente autorizado, fornecer apenas a chave publicável, configurar Auth e autorização de canais privados. Nenhuma conta ou tabela remota foi criada aqui. Ver [conexão e contratos](BACKEND.md).
- **Conclusões de campanha:** o futuro verificador autoritativo precisa produzir `completion_evidence`. Não existe produtor de provas no cliente nem no protótipo. Sem prova válida, o servidor rejeita a conclusão.
- **Godot:** compilação/tipos/APIs, importação FBX, renderização das telas, gestos, foco, desempenho, áudio e builds Android/Web. Ver [roteiro Claude + MCP](TESTES_GODOT.md).
- **Áudio:** os buses Master/Music/SFX e seus volumes estão implementados; novas fontes de música/efeitos precisam usar esses buses. Nenhuma faixa foi inventada.
- **Idioma:** PT-BR é a interface principal. English está identificado como parcial: rótulos textuais e formatação estão preparados, mas as artes existentes com texto desenhado, nomes e narrativas continuam em português.
- **Exportação:** presets incluem os JSONs lidos por `FileAccess`, Web sem threads e permissão de internet no Android. Templates, SDK, assinatura e builds não foram executados.

Os 82 arquivos adicionados nas tarefas 01/02 permanecem intactos, assim como modelos, animações, cenário e scripts do Deserto. Nove arquivos anteriores de interface/configuração foram alterados de forma justificada. Ver [inventário completo](ARQUIVOS.md) e [resultado das verificações](VALIDACAO.md).
