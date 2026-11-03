# Diva Pop · coleção oficial gratuita

**ID imutável:** `diva_pop`  
**Cartas:** 10 (retrato vertical)  
**Público:** todos os jogadores; gratuito; equipe Quem Sou Eu.

## Importação de imagens pelo celular — um único ZIP

Os nomes, descrições e IDs já estão salvos no `deck.json`. O arquivo das dez artes é `UPLOAD_DIVA_POP.zip`, entregue na conversa do ChatGPT.

1. Entre nesta pasta no GitHub, na branch `main`.
2. Selecione **Add file → Upload files**.
3. Escolha **UPLOAD_DIVA_POP.zip** (não é necessário descompactar) e confirme o commit na `main`.
4. O workflow **Importar pacote Diva Pop** verifica os dez PNGs e inclui `carta_01.png` até `carta_10.png` nesta pasta. Em seguida, solicita os workflows **Godot real headless smoke** e **Publish Web preview**.

O ZIP deve conter dez PNGs de 512 a 4096 px de largura, de 768 a 8192 px de altura, mais opcionalmente `deck.json`. A importação recusa nomes extras, duplicatas e formatos inválidos.

**Correspondência das imagens** (mantida na ordem de recebimento):

| Arquivo | Carta |
|---|---|
| carta_01.png | Selina Chartpenter |
| carta_02.png | Millie Eyelash |
| carta_03.png | Luna Loopa |
| carta_04.png | Livvy Rockdrigo |
| carta_05.png | BLUSHPUNK |
| carta_06.png | BEAT7 |
| carta_07.png | Mr. Weekday |
| carta_08.png | Benny Starz |
| carta_09.png | Ariella Big |
| carta_10.png | Lola Glow |

**Não confundir cartas do deck com skins 3D jogáveis.** Estas imagens são retratos das cartas do Mata-Mata; não desbloqueiam personagens em Skins.

## Supabase

- `CATALOG`: `supabase/catalog/seeds/20261103_t30_diva_pop.sql`
- `GAME`: `supabase/game/migrations/20261103043000_t30_diva_pop_official_reward.sql`
- Nova campanha `diva_pop_2026` independente do pacote anterior, com anúncio único por conta e resgate gratuito associado ao usuário.
- **Ativar a campanha somente depois que as imagens estiverem na main e a versão Web estiver publicada**, para não anunciar cartas com arte ausente.

A Biblioteca exige dez imagens válidas. Antes do upload, mantém os quatro decks anteriores sem mostrar cartões quebrados.
