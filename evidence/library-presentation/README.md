# Biblioteca — capas, banner e popularidade (08/11/2026)

Pedido do dono: remover a entrada Revisão manual da vitrine, baixar os filtros,
aumentar o banner dentro da tela e distinguir rankings reais da comunidade.

- Banner: largura integral e altura 500 na base de design; filtros horizontais abaixo.
- A ferramenta de revisão continua implementada; somente o atalho da vitrine saiu.
- Bombando usa o score existente: jogadores distintos em 30 dias × 2 + partidas
  em 30 dias + favoritos atuais × 3. É engajamento medido, não crescimento semanal.
- Mais salvos usa favoritos. Mais baixados conta contas distintas que adicionaram
  um deck da comunidade à biblioteca (claims), não downloads de imagens/prévias.
- A migração `20261108193000_library_download_stats.sql` está preparada, NÃO aplicada
  ao Supabase nesta entrega. Sem esse campo no servidor, Mais baixados fica oculto.
- Populares busca todas as páginas disponíveis de metadados; estatísticas são
  consultadas em lotes de até 100, com cache. Nunca baixa originais para ordenar.
- Capas das recompensas agora resolvem o catálogo real e o conteúdo editorial,
  sem a antiga lista fixa de cinco IDs. A galeria usa o recorte 5:7 do editor,
  preservando prévias manuais e o original no leitor.

Capturas Web reais com Godot 4.7.2 e Chromium/SwiftShader: desktop 1672×941/DPR1,
844×390/DPR3 e 640×360/DPR3 com UA iPhone. São fixtures offline identificadas
como [TESTE], com arte local existente; contadores de teste não são produção.
Não comprovam Safari ou aparelho físico. JSONs registram erros de console vazios.

Validação: design checker; biblioteca visual 128 verificações; popularidade 18;
fixture de ordenações, compatibilidade sem downloads e posição dos filtros.
Smoke geral executado: a rota wallet falhava por exigir uma carteira já desativada
na main. O smoke agora verifica o bloqueio e mantém a navegação pelas demais rotas;
o teste main_menu repetido passou. Compras continuam desativadas.
