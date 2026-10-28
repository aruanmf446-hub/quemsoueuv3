# Roteiro posterior — Claude + MCP Godot

**Não executado nesta entrega.** Usar Godot 4.7.2, GDScript e Compatibility. Não confundir análise por gdtoolkit com compilação do motor. Preservar modelos e gameplay ao corrigir eventuais erros de importação/API.

## Importação e inicialização

1. Conferir branch e árvore limpa. Consultar `godot_status` e `godot_project_info` conforme `AGENTS.md`. Confirmar a cena principal original `scenes/menu/main_menu.tscn`, renderer e orientação landscape.
2. Importar os FBX/GLB existentes. Abrir as oito rotas e a moldura herdada no editor; verificar scripts/classes, tipos e NodePaths. Salvar recursos pelo MCP, sem versionar `.godot/`.
3. Executar com `godot_run_start` e ler `godot_run_output` em nível error. Corrigir erros reais de tipos, APIs e importação antes de avaliar aparência. Capturar evidência, sem declarar sucesso só porque a análise textual passou.

## Menu, navegação e layout

4. Sem chave pública, confirmar “Demonstração local”, saldos `—`, perfil vazio, ausência de jogadores fictícios e El Fuego bloqueado. Preservar fundo/logo/botões e iluminação original do palco.
5. Abrir Perfil, Conta, Configurações, Amizades, Carteira, Skins, História e Perfil público quando autenticado. Testar mouse, toque, Tab/setas/Enter, Esc, Voltar e Android Back. Abrir repetidamente a mesma rota: apenas uma instância deve existir. Conferir histórico, foco restaurado e transição.
6. Verificar 1920×1080, 1280×720 e uma Web mobile horizontal como 844×390. Procurar sobreposição, texto cortado, botões pequenos, rolagem inacessível e teclado virtual cobrindo campos. Em retrato, o aviso de rotação deve bloquear interação e desaparecer ao girar.
7. Testar prévias com arraste, roda/pinça e troca rápida. Verificar geração/cache das oito miniaturas e consumo de GPU/memória ao reabrir telas. Listas de amigos não devem gerar uma cena 3D por linha.

## Preferências locais

8. Alterar Master/Music/SFX, reiniciar e conferir persistência em `device_preferences_v1.cfg`. Usar fontes de áudio atribuídas aos buses correspondentes. Com áudio ausente, não declarar a mixagem validada.
9. Alterar Baixa/Média/Alta; conferir MSAA, resolução e sombras nos palcos de prévia, sem modificar materiais ou modelos. Testar tela cheia Web por clique real, saída pelo navegador e retorno à tela.
10. Remapear confirmar/voltar, impedir teclas duplicadas e reiniciar. Confirmar que `move_left`, `move_right`, `jump` e `attack` permanecem intactos. Testar PT-BR, English parcial e formatação `1.234`/`1,234`; artes com textos desenhados e narrativas continuam PT-BR.

## Backend autorizado e duas contas de teste

11. Fazer o preflight e revisão descritos em [BACKEND.md](BACKEND.md), preferindo um ambiente de teste. Não aplicar `bootstrap_local.sql` ao projeto remoto e não criar contas de pessoas reais.
12. Configurar chave **publicável**, confirmação de e-mail e Auth. Testar cadastro pendente, login válido/inválido, token expirado, refresh, sair online e sair offline. Durante requisição lenta, sair e entrar em outra conta: nenhuma resposta antiga pode repor dados da conta anterior. Inspecionar `user://`: nenhum token/e-mail deve ser persistido.
13. Editar nickname válido/inválido. Conferir ID estável, avatar e skin equipada no lobby, perfil e perfil público. Nível/XP/estatísticas ausentes precisam continuar vazios. Desabilitar descoberta e verificar busca/perfil de não amigo.
14. Entre contas A e B: buscar por nickname/ID, enviar, cancelar, recusar e aceitar. Tentar autoamizade, aceitar pedido enviado por si, reenvio/duplo toque e mesma chave com outro conteúdo. Conferir que C não lê pedidos, carteiras ou progresso de A/B.
15. Abrir presença em duas sessões. Confirmar online, última sessão desconectada, reconexão, token renovado e remoção de amizade. Tentar publicar no tópico do outro usuário e ler tópico de não amigo. Testar autorização WebSocket real, além das políticas SQL já testadas.
16. Carteira: confirmar saldo real e histórico paginado sem duplicações, atualização após operação **de teste no servidor**, precisão de números grandes e estados offline/erro. Não colocar botões de crédito nem usar valores econômicos como recompensas da campanha.

## Progressão, skins e compatibilidade

17. Criar cópias de saves antigos para teste; anotar hashes. Flags antigas/canônicas locais e uma única fase concluída nunca podem liberar El Fuego. Confirmar que arquivos originais não foram modificados e que o modo demo só salva equipamento inicial em `player_demo_v2.cfg`.
18. Em banco descartável com provas controladas por servidor: concluir 1–9, tentar pular fase, checkpoint inválido, prova de outro dono/expirada, conclusão 10 com/sem Malagueta, repetição e revisão concorrente. Antes das dez, equipar El Fuego deve ser negado; depois, conceder exatamente uma conquista e um desbloqueio. Os testes locais automatizados já cobrem as regras SQL, não o percurso visual.
19. Skins: inicial, bloqueada, equipada, descrição, miniatura, prévia e Voltar. Desconectar durante equipamento e provocar conflito entre dispositivos; não mostrar confirmação otimista. Cactus/Malagueta não aparecem como skins.
20. História: quatro reinos, dez nomes e estados derivados do snapshot. Só a fase 1 tem botão para seu protótipo real. Abrir e voltar por toque/Esc sem perder a conta. El Fuego é protagonista mesmo bloqueado no lobby. Sair/vencer o protótipo não concede progresso ou recompensa.

## Exportação

21. Revisar [presets](../../export_presets.cfg), instalar templates/SDK e definir assinatura Android fora do Git. Verificar JSONs incluídos, permissão de internet, Compatibility, landscape e HTTPS/WSS. Testar Web com sua configuração pública antes do bootstrap; testar pausa/retomada Android.
22. Anexar erros, capturas, resoluções, contagens de nós/modelos e resultados por item. Só então classificar renderização, acessibilidade, desempenho e fluxo completo como validados no motor. Esta entrega não possui build ou teste de gameplay aprovado.
