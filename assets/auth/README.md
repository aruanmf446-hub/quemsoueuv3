# T18A — Login cinematográfico

## Camadas independentes

A composição original aprovada foi preparada como uma imagem ilustrada sem os botões incorporados:

- `assets/auth/login_heroes.webp` (1060×900, 257 KB): personagens e cenário do lado esquerdo (loira, feneco, cowboy e corvo), com transparência progressiva sobre a parte direita. Arquivo binário **versionado** na branch T18A.
- `assets/desert/night_city/citadel.png`: cenário do próprio jogo como camada inferior.
- `assets/processed/logos/logo_quem_sou_eu_retangular.png`: logo oficial do jogo, em `TextureRect` independente.
- `assets/auth/google.svg`, `apple.svg`, `steam.svg`, `discord.svg`: ícones SVG independentes.
- `scripts/ui/screens/account_screen.gd`: botões nativos, painel ornamentado, formulário e layouts responsivos.

As imagens funcionam como decoração; **não existem áreas clicáveis disfarçadas dentro do fundo**. Só os nós Button realmente executam ações. Provedores não habilitados mostram EM BREVE, seguem desabilitados e não geram chamadas de OAuth.

## Critérios de revisão

1. Capturas reais do Godot 4.7.2 em 1920×1080, 844×390 e 640×360, produzidas pelo workflow `.github/workflows/godot-smoke.yml`.
2. Conferir fidelidade de cores, hierarquia de logo/painel e enquadramento da ilustração; deixar o PR em draft até revisão do proprietário.
3. Preservados os serviços de Auth do GAME, convites da T17 e código funcional da T18; Supabase GAME/CHAT/CATALOG não foram alterados.
4. O recorte ilustra o conjunto completo de personagens. Não há nova instância Cowboy 3D nessa tela; o modelo 3D permanece intacto nas demais.
