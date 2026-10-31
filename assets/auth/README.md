# T18A — reconstrução da autenticação com referência aprovada

**O fundo não contém nenhum botão ou logo incorporado.** A versão panorâmica da referência teve o antigo painel/logo ilustrados substituídos por textura do cenário (região depois coberta pelo painel nativo), preservando personagens, fortaleza e soldados.

## Arte e interface reais
- `assets/auth/login_cinematic_bg.webp` — 1600×900, fundo contínuo de alta resolução: loira, corvo, Cowboy, feneco, fortaleza, lua, El Fuego procurado e soldados Cactus. Fundo puramente decorativo.
- `assets/auth/login_logo.webp` — logo oficial empilhado extraído da referência e isolado com transparência. Não há imagem de botão ou hitbox embutida.
- `assets/auth/{google,apple,steam,discord}.svg` — ícones independentes.
- `scripts/ui/screens/account_screen.gd` — painel StyleBoxFlat com contorno cobre, botões reais Godot, divisor ornamental, formulário e fluxos do Auth GAME já existentes.
- `assets/auth/login_heroes.webp` e `login_guards.webp` — recortes ilustrados preservados para edição artística futura; a UI final usa a versão panorâmica limpa, não sobrepõe as faixas.
- O modelo 3D do Cowboy não é montado na tela de autenticação (preservado nas demais).
- Google, Apple, Steam e Discord continuam desabilitados se não configurados. Um aviso discreto informa indisponibilidade; não simulam login.

## Critério de aprovação
Comparar **capturas reais do Godot 4.7.2**, obtidas em 1920×1080, 844×390 e 640×360, à imagem oficial. Revisão visual humana obrigatória e sem merge até autorização. T17 convites e T18 backend/clientes preservados. Supabase GAME/CHAT/CATALOG não modificados.
