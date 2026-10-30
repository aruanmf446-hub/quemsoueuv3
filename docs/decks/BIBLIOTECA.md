# Biblioteca de Decks — consulta local

A Biblioteca é uma rota própria (`deck_library`) no lobby. Usa o `PlayerScreen`, o `PlayerUI`, a fonte MSDF, as superfícies, os botões, o fundo e as transições da direção limpa aprovada no PR #28. A branch do PR #29 incorpora a `main`, incluindo o Duelo local do PR #30. Biblioteca e Duelo continuam separados.

Funciona nesta etapa:

- Descoberta dos decks locais públicos, pesquisa por nome do deck ou criador, sem diferenciar caixa ou acentos; limpar busca e estado sem resultados.
- Destaque oficial de **Lendas Urbanas**, com a atribuição já existente no catálogo, nove cartas reais em ordem alfabética e selo OFICIAL. Nenhum deck fictício foi cadastrado.
- Galeria responsiva; toque/clique abre a imagem original inteira no leitor, sem deformação. Anterior/próxima, setas do teclado, retorno à galeria, preservação da rolagem e foco. Voltar, Esc e o evento de retorno do Android consomem leitor → galeria → Biblioteca → rota anterior.
- Metadados opcionais aparecem somente quando válidos. O JSON atual não fornece descrições, categoria, etiquetas, classificação ou datas: a interface informa a ausência de descrição e categorias, sem inventar esses dados.
- As abas Populares, Recentes, Favoritos e Meus Decks têm estados honestos de indisponibilidade. Categorias virão dos metadados; não foram inferidas a partir das imagens.

As nove fontes PNG continuam em **600×840**, com os bytes originais preservados. Só a geração de mipmaps de importação foi habilitada para reduzir serrilhado ao diminuir as miniaturas; não se reduziu resolução, compressão ou qualidade de gráficos. O leitor usa `KEEP_ASPECT_CENTERED` e filtragem linear com mipmaps.

## Limites de produto

Esta entrega não implementa Supabase, contas, publicação, edição, denúncias, moderação, avaliações, favoritos persistentes, compartilhamento externo/entre amigos, traduções automáticas ou seleção de deck para criar salas. Não há botões que simulem essas operações. Consulta pública local funciona sem autenticação; isso não é uma implementação de autorização remota.

O catálogo aceita apenas conjuntos completos de **5 a 30 cartas**, com nome e imagem existentes, e ordena por nome automaticamente. Para compatibilidade com Lendas Urbanas, ainda aceita o formato legado sem descrição; ele não deve ser usado como validador de publicação. Publicação futura deverá exigir imagem, nome e descrição por carta.

A descoberta lista apenas decks públicos. O resolvedor local aceita IDs exatos de decks públicos ou não listados e rejeita privados e caminhos arbitrários. Isso prepara consulta por parâmetros internos; **não cria links externos compartilháveis**. A marca oficial usa uma lista controlada no código, não um campo arbitrário do JSON.

Continuam aprovados para as próximas etapas: uma categoria oficial e até três etiquetas livres; visibilidade pública/não listada/privada; favoritos por deck; avaliações de 1–5 estrelas; compartilhamento por link e amigos; leitura pública sem login; login para favoritar, avaliar, denunciar e Duelo online; moderação automática com revisão humana dos casos incertos; classificação, avisos e filtros; traduções separadas do idioma original. Avisos e classificação informados podem ser apresentados, mas não há motor de moderação, tradução ou filtros nesta entrega. As regras existentes do Duelo local da `main` foram preservadas.

## Evidências e reprodução

Veja [capturas reais e relatório de validação](../../evidence/deck-library/README.md).

```sh
godot --headless --editor --path . --import --quit
python3 tools/player_ui/check_design.py
# Precisa de um display para capturar o framebuffer real.
godot --audio-driver Dummy --path . -s tests/decks/library_flow.gd -- 1672x941 res://evidence/deck-library/desktop
godot --audio-driver Dummy --path . -s tests/decks/library_flow.gd -- 844x390 res://evidence/deck-library/mobile
godot --audio-driver Dummy --path . -s tests/decks/library_flow.gd -- 640x360 res://evidence/deck-library/small
godot --headless --path . -s tools/godot/menu_flow.gd
godot --headless --path . -s tests/duel_local/flow_test.gd
```

O teste da Biblioteca injeta eventos reais no viewport para abrir o botão do lobby, pesquisar, trocar abas, abrir cartas e voltar. Também verifica metadados ausentes, imagens originais, ordenação, visibilidade, isolamento da navegação e limites dos controles. Os casos de metadados são dicionários em memória; nenhum catálogo fictício é publicado.

A integração com o Duelo atualizado inclui correções restritas ao ciclo de vida da interface ao sair da sala: estado `room` só é renderizado enquanto há sala, o seletor local oculto pertence à árvore de nós e a prévia destacada é liberada na saída. Nenhuma regra de jogabilidade ou serviço remoto foi alterado.
