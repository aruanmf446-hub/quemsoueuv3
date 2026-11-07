# Acessos visíveis a Moedas e Emotes

Causa identificada: lobby_composition.gd mantém TopBar invisível. O hero substituiu o lobby antigo sem transportar o acesso à carteira. O acesso aos emotes dependia de encontrar a aba dentro de Personagens.

Corrigido com dois controles nativos visíveis no hero: MOEDAS abre wallet com tab=coins; EMOTES abre skins com cosmetic_mode=shop e inicia a Samba aprovada. Personagens continua abrindo Skins. Dados do equipamento ainda carregando não deixam a prévia sem personagem: usa uma entrada real do catálogo para visualização, preservando as verificações de posse do servidor. Estilo existente de PlayerUI; nenhuma arte foi gerada.

Validação Godot 4.7.2: carrossel e rotas 76 verificações, zero falhas; comércio 14 verificações, zero falhas; Samba 23 verificações, zero falhas. check_design.py e git diff --check passaram.

Web real exportado, Chromium: 1672×941 desktop, 844×390 e 640×360 com user agent de iPhone/DPR 3. Clique/toque nos atalhos, abertura da carteira e dos emotes, AnimationPlayer tocando emote_samba, compras desabilitadas e nenhuma chamada de checkout. Capturas e resultados em web/. Fixtures identificadas e rede externa bloqueada; pacotes/preços nas capturas são respostas de teste, não auditoria do catálogo em produção.

Sem acesso ou alteração de backend, Stripe, saldos ou posse. Não foi testado em iPhone físico/Safari. O acesso direto ao domínio de produção está bloqueado pelo proxy deste ambiente (CONNECT 403); isso não indica erro do site. Publicação deve ser acompanhada pelo workflow, sem alegar conferência do qseBuild remoto quando o domínio não pode ser acessado.
