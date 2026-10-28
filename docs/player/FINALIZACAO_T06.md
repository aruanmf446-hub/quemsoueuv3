# Tarefa 06 — finalização técnica das telas

Base: `work/backend-supabase-05`, commit `529ab72`, que contém a Tarefa 03 e o relatório `IMPLANTACAO_T05.md`. Branch: `codex/finalizacao-telas-06`. Nenhuma migration, cadastro ou conexão ao Supabase foi executada.

## Correções

- NavigationManager: Android Back só atua quando o menu está visível, evitando consumir retorno no protótipo. Instâncias de rota incompatível são liberadas e exibem erro.
- PlayerScreen: parâmetros de navegação são copiados, sem compartilhar mutações do chamador.
- Perfil Público: respostas pendentes são invalidadas ao ocultar a tela, evitando criar prévias 3D depois de sair.
- Configurações: ao fechar, cancela a captura de remapeamento de teclas.
- ThumbnailCache: interrompe a captura quando Skins está oculta, verifica validade dos nós após awaits e ignora imagens vazias.
- DevicePreferences: mantém leitura/gravação no mesmo `user://device_preferences_v1.cfg`; em falha de gravação, restaura o valor anterior antes de aplicar áudio/teclas/gráficos. Reinício e persistência por plataforma ainda exigem motor.

Os estados offline, não autenticado, carregamento e erro continuam compartilhados. As telas mantêm dados ausentes vazios, carteira sem saldo fictício e nenhuma amizade simulada. Catálogo, IDs e onze RPCs permanecem compatíveis com a T05. Não foram alteradas interfaces dos serviços nem SQL de backend.

## Arquivos alterados

`scripts/ui/navigation_manager.gd`, `scripts/ui/player_screen.gd`, `scripts/ui/screens/public_profile_screen.gd`, `scripts/ui/screens/settings_screen.gd`, `scripts/skins/thumbnail_cache.gd`, `scripts/services/device_preferences.gd`, `tools/player_ui/check.py`.

Novos: `tools/player_ui/test_t06.py` e este documento. O gate agora usa a base T05, protegendo as migrations e demais arquivos existentes contra alterações fora da lista de UI.

## Testes efetivamente executados

106 aprovados: 21 estáticos anteriores, cinco regressões estáticas T06 e 80 da biblioteca de progressão. Análise sintática de 42 scripts, referências das 16 cenas/heranças, oito rotas, onze RPCs e JSON Schema. Conferência de hashes dos arquivos da base fora do escopo. `git diff --check` aprovado.

```bash
python -B -m unittest tools.player_ui.test_static tools.player_ui.test_t06 tools.progression.tests.test_engine tools.progression.tests.test_migration tools.progression.tests.test_sync -v
```

Usar as dependências de `tools/player_ui/requirements.txt`. Testes de proteção textual não executam GDScript: não comprovam eventos, tipos/APIs do motor, armazenamento real ou renderização. Nenhum teste visual foi realizado. Os testes SQL/HTTP da T05 não foram repetidos.

## Claude Code — validação curta no Godot

1. Abrir esta branch no Godot 4.7.2 Compatibility e seguir AGENTS.md: status, project_info, importar recursos e executar **o projeto pelo MainMenu**, não cenas isoladas sem PlayerServices. Ler erros antes da revisão visual.
2. Sem chave e sem login, abrir Perfil, Conta, Configurações, Amizades, Carteira, Skins e História pelos botões. Para Perfil Público, usar a rota existente `Navigation.open("public_profile", {})` pelo harness de teste do editor: deve mostrar acesso não autorizado/offline, sem inventar jogador.
3. Repetir abrir/voltar com mouse, Tab/Enter/Esc, toque e Android Back. Verificar que nenhuma rota duplica nós e que Back no protótipo retorna aos reinos. Fechar Perfil Público/Skins durante carregamento e observar ausência de erros de nós liberados.
4. Conferir landscape 1920×1080, 1280×720 e Web mobile 844×390; em retrato testar aviso de rotação. Ajustar espaçamento, escala de toque e texto cortado usando as cenas/arte atuais, preservando lobby e gameplay.
5. Alterar volume, qualidade, idioma e teclas; fechar/reabrir e reiniciar. Confirmar os valores no arquivo de preferências. Simular erro de escrita em ambiente de teste: não mostrar preferência como salva. Verificar cancelamento de captura de tecla ao sair.
6. Confirmar moedas/gemas/XP sem valores reais ausentes representados por `—`/vazio, amizades vazias, El Fuego bloqueado e apenas fase 1 com protótipo. Não cadastrar contas nem ativar presença para testar estas telas.
7. Registrar erros, capturas e resultados reais. Auth, sessão persistente e fluxos autenticados continuam sujeitos aos bloqueios da T05; a produção não foi declarada conectada. Não redirecionar o cliente silenciosamente ao projeto isolado.
