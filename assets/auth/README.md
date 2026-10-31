# T18A — Login cinematográfico (revisão visual pendente)

## Arquivos e fonte

A referência aprovada é a ilustração enviada pelo proprietário na Tarefa 18A. Não substituir o fundo por personagens 3D isolados.

- `assets/auth/login_heroes.webp` — recorte ilustrado **sem o painel de login**, com transição alpha à direita. Deve ser adicionado como recurso binário na branch (arquivo entregue à parte no pacote T18A).
- `assets/processed/logos/logo_quem_sou_eu_retangular.png` — logo oficial, separadamente do fundo.
- `assets/auth/{google,apple,steam,discord}.svg` — ícones decorativos; todos os botões são `Button` reais do Godot.
- `scripts/ui/screens/account_screen.gd` — constrói o painel direito, o logo e o formulário; nenhuma alteração na lógica do Auth.
- `assets/desert/night_city/citadel.png` — fallback técnico enquanto o recorte cinematográfico não foi versionado.

## Bloqueio explícito

O conector GitHub disponível aceita conteúdo UTF-8 e blobs de texto, mas este turno não anexou o **arquivo binário de 257 KB** à branch. O jogo usa o fundo do Deserto como fallback até o arquivo ser adicionado em `assets/auth/login_heroes.webp`. Sem esse arquivo, o visual da Tarefa 18A **não está aprovado**, mesmo com CI verde.

O pacote disponibilizado no chat contém o recorte pronto; depois de versioná-lo, reexecutar GitHub Actions e comparar de fato os três screenshots gerados pelo Godot com a referência, especialmente tamanho do feneco, personagem loira, corvo, cowboy, soldados e painel da direita.

## Critérios

1. A arte fica na área esquerda e não contém nenhum botão clicável.
2. O logo é `TextureRect` real; as opções sociais são `Button` nativos e desabilitam os provedores sem configuração.
3. O formulário de e-mail continua usando os serviços GAME da T18, sem modificar Supabase.
4. PC 1920×1080, Android 844×390, compacto 640×360: todos os botões acessíveis (scroll somente se conteúdo exceder a área).
5. Não fazer merge até **aprovação humana das capturas reais**.
