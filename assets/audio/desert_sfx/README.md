# Efeitos da campanha

Impactos e passos: **Kenney — Impact Sounds**, **CC0 1.0**.
Origem: https://kenney.nl/assets/impact-sounds
A cópia fixada do mirror e os hashes estão em `sources.json`; os arquivos foram
comparados byte a byte com o ZIP oficial, cuja hash também está registrada.
Texto integral: `LICENSE-CC0.txt`.

Conversão: PCM mono a 44,1kHz, filtro para remover subgraves e agudos ásperos,
entrada curta sem clique e limite de pico. Areia/vento são camadas originais,
combinadas com os passos CC0. Os sons de coleta e checkpoint usam a ressonância
do sino do pack. Não há assobio/cartoon na queda nem voz sintetizada no dano.

Reprodução das camadas: `python3 tools/audio/build_desert_sfx.py /caminho/kenney.zip`
Requer NumPy e FFmpeg. Os WAV finais são distribuídos prontos: o jogo não os gera.
O player alterna variações, respeita o barramento SFX e prioriza impactos importantes
para não cortar defesa/dano com passos de fundo.
