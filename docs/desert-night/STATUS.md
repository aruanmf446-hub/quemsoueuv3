# Cidade noturna — publicação intermediária

Continuação de `1ed2f12` na branch `codex/gameplay-t15d`. Publicação antecipada
solicitada pelo usuário, sem merge na main. A validação completa continua.

Implementado nas fases 01–09:

- Cidade no meio do deserto à noite; três panorâmicas originais, arquitetura 3D,
  iluminação lunar, janelas/lanternas, materiais e HUD próprios.
- Mapas determinísticos de 1.200m, oito distritos, 14–20 buracos por fase,
  Cactus e reposições de ataque/defesa; carregamento por trechos reversível.
- Vida 3/3; ataque e defesa 1/1 consumíveis por fase; reposições não somem
  quando o inventário está cheio. Somente ataque derrota Cactus; contato causa dano.
- Morte reinicia a fase inteira. Conclusão salva progresso local e libera a próxima.
- Navegação de fases, pausa e retorno; pulo duplo, coyote time e agachar preservados.

A fase 10, o controlador compartilhado antigo, lobby, Personagens, Configurações,
Músicas, Supabase e serviços sociais não foram alterados. O launcher de História
agora aceita as fases locais desbloqueadas, inclusive a fase10 original após09.

Evidências até esta publicação: 144 verificações estruturais dos nove mapas,
29 de progresso local, 42 de regras/controles em janela, percurso completo da
fase01 com modelos e inimigos em 210,55 segundos físicos, sem mortes. A prova
física isolada de geometria completou ida/volta das nove fases em mais de201s
por sentido. Essas provas isoladas não substituem as jornadas gráficas.

Pendente: rodada final de percursos completos das nove fases, revisão integrada
final dos materiais/HUD, navegação mouse/toque, capturas e consolidação dos logs.
O piloto automático inicial das fases02–09 parava diante de certos degraus;
o harness está sendo corrigido e as nove não são declaradas validadas ainda.

As imagens em `evidence/desert-night-wip/` são capturas reais da primeira
integração no Godot4.7.2, não as capturas finais dos materiais refinados.
Android físico e navegador Web ainda não foram validados.

## Revisão concluída nesta continuação

Godot oficial 4.7.2, Compatibility, foi executado em display Xorg virtual com
Mesa/llvmpipe. As fases 01–09 foram percorridas integralmente por entradas de
movimento, salto e ataque, sem teleporte depois do spawn. Todas chegaram à meta
sem morte ou erro de script, em 210–214 segundos de física cada. O arquivo
`evidence/desert-night-final/routes.json` registra os resultados individuais.
Esse tempo é do percurso automatizado e não prevê a duração de cada jogador.

As regras foram exercitadas também com janela em 1920×1080 e 844×390: vida 3/3,
ataque e defesa 1/1, dano ao tocar Cactus, invulnerabilidade curta, reposições,
queda em buraco, reinício integral, controle nos dois sentidos, multitoque,
pausa e liberação da fase seguinte. O teste de retorno cruzou um limite de
streaming e voltou ao início sem morte. A fase 10 original passou no teste de
isolamento e não foi modificada.

As capturas em `evidence/desert-night-final/` vêm do framebuffer do Godot e
mostram o começo das fases 01, 05 e 09 em 1920×1080, 1280×720 e 844×390, além da fase 02
liberada no menu. Essa captura do menu vem da fixture de navegação, que aciona
o callback de vitória para isolar a transição; as nove travessias físicas são
registradas separadamente em `routes.json`. A revisão das imagens levou a fachadas mais estreitas,
separadas e quentes, para manter El Fuego legível diante da cidade iluminada.
O teste de percurso longo foi rodado com passo físico fixo em modo headless;
capturas e testes de interface vieram de janelas gráficas. Ainda falta ensaio
de desempenho e toque em Android físico e navegador Web.
