# Resgate de decks da Comunidade

Migrations e função implantadas após autorização do dono. Cliente preparado
para publicação no main/Pages; o resultado do workflow será registrado após
sua conclusão. `deployment.json` registra os hashes das migrations, a função
ACTIVE e os três testes HTTP sem gravação.

- Resgate confirmado pelo servidor, sem duplicar a coleção.
- Meus Decks mostra o deck e seu criador.
- Decks resgatados participam do Mata-Mata com o motor existente.
- Versões aprovadas distribuídas pelo CATALOG; identidade, posse e partidas no
  GAME. Originais e prévias continuam privados. Nenhum serviço CHAT foi alterado.

## Verificações executadas

| Verificação | Resultado |
| --- | --- |
| SQL no GAME, transação com rollback | 47 verificações, 0 falhas |
| SQL no CATALOG, transação com rollback | 6 verificações, 0 falhas |
| Gateway com transporte simulado | 14 testes, 0 falhas |
| Godot 4.7.2 — posse, UI, bots e seleção | 26 verificações, 0 falhas |
| Duelo local existente | 87 verificações aprovadas |
| Revelação existente | 2 revelações observadas, saída 0 |
| Comunidade T27 | 14 verificações, 0 falhas |
| Pesquisa e autoria | 16 verificações, 0 falhas |
| Acompanhamento de envios | 29 verificações, 0 falhas |
| Separação de conexões Supabase | 15 verificações aprovadas |
| Web Chromium 1672×941 | Mouse, resgate, confirmação e coleção aprovados |
| Web Chromium 844×390 e 640×360, perfil iPhone/DPR 3 | Toque, resgate, confirmação e coleção aprovados |
| Design e importação/exportação oficial | Aprovados |

Os testes SQL usam o esquema real e identidades temporárias revertidas. Cobrem
aprovação pelo fluxo atual, preparo/finalização da versão, idempotência,
inventário isolado, RLS sob `authenticated`, seleção autorizada, criação/início de sala e seleção pelas RPCs reais do duelo, permissão dos
oponentes da sala, retirada, acesso durante a partida e perda de acesso após
remoção do membro. As contagens reais foram conferidas após os rollbacks.

O gateway testa autenticação negada, cópia restrita a prévias, falha de upload,
retirada durante cópia, repetição, autorização de manifestos e separação entre
JWT do jogador e credenciais do CATALOG. Foi implantado após esses testes. As verificações HTTP de sessão ausente,
falsa e CORS passaram; o teste mutante com sessões reais foi bloqueado pela
revisão automática e não foi executado.

O teste Godot monta uma sala com bot, inicia a partida e seleciona cartas do
deck comunitário; confere nomes/texturas, cache, coleção, controles nativos,
restauração e troca de conta, além de respostas atrasadas após resgate/logout.
Não reimplementa o servidor de duelo.

## Capturas Web

`*_resgatar.png`, `*_resgatado.png` e `*_colecao.png` são capturas do **motor Web
exportado** no Chromium, com todas as requisições externas bloqueadas e serviços
simulados explicitamente. `*_results.json` contém os resultados de cada janela.
As cinco imagens repetidas são o asset existente `momo.png`, usado somente
como fixture. Nenhum asset artístico novo foi gerado nesta entrega.

A coleção tem a rolagem já existente. A captura de coleção mostra o conteúdo
após rolar; não foi criado um layout compacto para os demais aparelhos.

## Reproduzir

Use o Godot oficial 4.7.2:

```bash
"$GODOT" --headless --path . --audio-driver Dummy --script res://tests/community_claims/flow.gd
node tests/community_claims/gateway.test.mjs
python3 tools/player_ui/check_design.py
```

O teste Node é executado diretamente para exibir e contar os 14 testes.
`node --test` neste ambiente resumiu apenas o arquivo como um teste, portanto
não foi usado como prova da contagem dos casos internos.

Para o Web, prepare a cópia isolada com `tests/iphone_deck/export_fixture.py` e:

```bash
node tests/community_claims/web_probe.cjs <pasta-pai-do-build> <evidencias>
```

O build deve estar em `<pasta-pai-do-build>/quemsoueuv3/index.html`.

Os testes SQL de `tests/community_claims/backend.sql` e `catalog.sql` precisam
ser concatenados às respectivas migrations dentro da mesma transação, trocando
o `COMMIT` final por `ROLLBACK`. Não executar os testes como implantação.

## Limites

Migrations e função foram implantadas após autorização; as evidências de
rollback acima pertencem à etapa anterior à implantação. O teste completo
com contas temporárias em produção foi rejeitado pela revisão automática
por falta de comprovação suficiente da limpeza dos efeitos derivados.
Nenhuma conta foi criada por esse teste.
Partida online com duas contas reais, Storage físico das novas versões, downloads
com URLs reais e Safari/iPhone físico continuam pendentes da implantação.
O primeiro limite de 60 s encerrou prematuramente o teste de revelação, que roda
por cerca de 90 s; ele foi repetido até concluir, sem alterar seu código.
O T27 registra um aviso de duas instâncias ObjectDB no encerramento.

[Arquitetura e passos restantes](../../docs/backend/DECKS_GAME_CATALOG_INTEGRACAO.md).
