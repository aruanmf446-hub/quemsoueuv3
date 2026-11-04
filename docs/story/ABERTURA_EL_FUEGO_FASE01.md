# Abertura de El Fuego — oito quadros 16:9 (Fase 01)

**Estado:** sequência e importador preparados na branch; os oito binários WebP precisam ser enviados a `assets/story/` a partir do pacote fornecido no chat. **Não integrar na `main` antes de importar e validar os oito arquivos.**

## Ordem obrigatória das oito artes enviadas (1536 × 864)

| Ordem | Destino definitivo | Ação representada |
| --- | --- | --- |
| 01 | `assets/story/fase01_01.webp` | Na mina, jovem El Fuego empurra vagoneta de cristais sob vigilância de Malagueta e guardas Cactus. |
| 02 | `assets/story/fase01_02.webp` | El Fuego encontra o cristal brilhante; energia dourada se manifesta nas mãos. |
| 03 | `assets/story/fase01_03.webp` | Seus familiares tentam protegê-lo do cerco dos guardas Cactus. |
| 04 | `assets/story/fase01_04.webp` | Exausto, El Fuego chega ao deserto diante da cidade; o cristal agora está no peito. |
| 05 | `assets/story/fase01_05.webp` | Um cavaleiro Cactus em vestimenta de viajante, montado num feneco aproximadamente do tamanho de um cavalo, oferece um cantil ao menino. |
| 06 | `assets/story/fase01_06.webp` | Memória/flashback da vida familiar na padaria, antes da transformação. |
| 07 | `assets/story/fase01_07.webp` | À noite, El Fuego aparece já mascarado, de roupa escura e capa vermelha, manifestando os poderes dourados. |
| 08 | `assets/story/fase01_08.webp` | El Fuego corre **sozinho** pelas ruas noturnas, fugindo de vários guardas Cactus. Nenhum feneco acompanha a fuga. |

A posição **06** representa uma lembrança e deve continuar depois do encontro no deserto, exatamente na ordem fornecida pelo usuário. Não reordenar por cronologia.

## Instruções de integração para Codex

1. Receber o ZIP `el_fuego_abertura_fase01_8_cenas.zip` disponibilizado na conversa. Os arquivos internos são `fase01_01.webp` até `fase01_08.webp`, mais `manifest.json` e `INSTRUCOES_IMPORTACAO.md`. NÃO fazer referência a imagens do chat por URL como se fossem assets persistentes.
2. No clone do repositório, executar `python3 tools/story/import_fase01_images.py /caminho/para/el_fuego_abertura_fase01_8_cenas.zip`. O importador verifica os SHA-256, transfere para **`assets/story/`**, verifica novamente e remove automaticamente a pasta **temporária exclusiva** criada na importação. NÃO apagar o ZIP original da pessoa nem outras pastas.
3. Os três arquivos `fase01_01.webp`, `fase01_02.webp`, `fase01_03.webp` antigos serão **substituídos**, não duplicados. Os cinco seguintes serão criados. Não remover outras imagens do diretório. Godot regenerará metadados de importação se necessário.
4. O `data/ui/phase_stories.json` desta branch define **oito** entradas da fase `01` em ordem. `scripts/ui/phase_story.gd` já resolve as imagens pela convenção `faseNN_MM.webp`.
5. **Não há textos sobrepostos nos pixels das imagens.** Todo texto/legenda deve permanecer em camada de UI, separado e localizável. Quando implementar traduções, usar chaves `tr()` e catálogos por idioma; não assar português nas imagens. Os textos de `phase_stories.json` são conteúdo editorial provisório.
6. Validar o modo história da fase 01 no Godot 4.7, incluindo `Próximo`, `Anterior`, `Pular história`, `Começar fase`, proporção 16:9 e ausência de referências a arquivos não importados. Verificar mobile 844×390 e desktop. Sem alterar gameplay, IA, perseguição, física ou personagens.
7. Apenas após integração dos oito arquivos e testes, preparar PR para `main`. Apagar qualquer diretório temporário de importação **depois da verificação**, sem deixar cópias redundantes na árvore versionada.

## Integridade do conjunto de oito imagens

| Arquivo | Bytes | SHA-256 |
| --- | ---: | --- |
| fase01_01.webp | 312150 | `daaf4a22aee7` (prefixo) |
| fase01_02.webp | 236534 | `862e4c68b3d3` |
| fase01_03.webp | 301118 | `19d99b762be2` |
| fase01_04.webp | 266052 | `20e34bd5c9c1` |
| fase01_05.webp | 286460 | `fbadb6cbc974` |
| fase01_06.webp | 302974 | `be486ebdc1b3` |
| fase01_07.webp | 313576 | `a5b336da8455` |
| fase01_08.webp | 275688 | `df53dd28dc54` |

Os hashes completos constam do `manifest.json` do ZIP e do importador.
