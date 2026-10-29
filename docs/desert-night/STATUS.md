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
