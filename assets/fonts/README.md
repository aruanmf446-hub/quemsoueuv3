# Interface multilíngue

`qse-interface-fallback.otf` é um subconjunto de Noto Sans CJK SC Regular,
licença SIL OFL em `OFL-NotoSansCJK.txt`. Origem:
https://github.com/notofonts/noto-cjk/blob/main/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf

Mantém os caracteres dos catálogos `data/ui/*.json`, os nomes nativos dos
idiomas, ASCII e o bloco cirílico U+0400–04FF. Gerado com fontTools subset
4.61.1, preservando a tabela de nomes e licença. O arquivo tem cerca de 595 KiB,
em vez dos 16 MB da fonte completa. Ao adicionar traduções asiáticas, regenere
o subconjunto para incluir os novos caracteres. Não é uma fonte CJK completa
para todo texto arbitrário enviado por usuários.

A fonte principal existente permanece a mesma. PlayerUI acrescenta esta fonte
como fallback MSDF; estilos e tamanhos continuam centralizados em PlayerUI.
