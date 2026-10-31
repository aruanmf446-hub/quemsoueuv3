# T18A — composição fiel à referência de autenticação

A tela não usa uma imagem inteira com botões falsos.

**Camadas ilustradas (WebP de alta qualidade, arquivos binários confirmados no GitHub):**
- `assets/auth/login_heroes.webp` (1060×900): loira, corvo, Cowboy, feneco e cenografia à esquerda, com transparência à direita.
- `assets/auth/login_guards.webp` (470×900): fortaleza, cartaz de El Fuego, lua, bandeiras, soldados Cactus à direita; área do painel original mascarada para evitar botões duplicados.
- `assets/desert/night_city/citadel.png`: castelo fallback do jogo, visível apenas entre as faixas ilustradas.
- `assets/processed/logos/logo_quem_sou_eu_retangular.png`: logo oficial acima do painel como nó independente.
- `assets/auth/{google,apple,steam,discord}.svg`: ícones.
- `scripts/ui/screens/account_screen.gd`: painel nativo com StyleBoxFlat, controles Button reais, estados desabilitados e formulário de e-mail; não modifica lógica de Auth.
- `tests/t18_auth/capture.gd` e workflow `godot-smoke.yml`: screenshots reais de 1920×1080, 844×390 e 640×360.

**Critérios para aprovação:** conferência humana com capturas reais, sem voltar para um Cowboy 3D isolado e sem simular login social. Nenhum merge até autorização.
