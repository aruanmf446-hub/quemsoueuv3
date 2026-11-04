# Imagens da história antes de cada fase

Coloque aqui as imagens dos cartões de história (os que aparecem com "Próximo" e
"Pular história" antes de cada fase do Modo História).

Nome do arquivo: `faseNN_MM.webp` (ou .png / .jpg)
- NN = número da fase (01 a 09)
- MM = número do cartão dentro da fase (01, 02…)

Exemplos: `fase01_01.webp` = fase 01, primeiro cartão; `fase01_02.webp` = fase 01, segundo cartão.

Tamanho: 1920 × 1080 (16:9, deitada). Deixe o mais importante no centro e no alto:
a faixa de texto cobre a parte de baixo. Até ~400 KB por imagem.

Sem imagem com o nome certo, o cartão usa a imagem padrão. Os textos ficam em
data/ui/phase_stories.json.

## Abertura da fase 01 — conjunto aprovado de oito imagens

A nova abertura usa `fase01_01.webp` a `fase01_08.webp`, **na ordem fornecida**.
As imagens têm 1536 × 864 (16:9), sem legendas impressas nos pixels.
Todos os títulos, diálogos e legendas são elementos separados, preparados para tradução pelo jogo.
O roteiro cena a cena está em `docs/story/ABERTURA_EL_FUEGO_FASE01.md`.

Para importar o ZIP recebido na conversa do usuário, execute:

```bash
python3 tools/story/import_fase01_images.py /caminho/el_fuego_abertura_fase01_8_cenas.zip
```

O script verifica as oito imagens, substitui apenas as três antigas da fase 01,
cria as cinco faltantes e remove a pasta temporária após a cópia verificada.
O projeto mantém imagens padrão caso o pacote ainda não tenha sido importado.
