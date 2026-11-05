# Compatibilidade do cliente com o PR #100

Godot 4.7.2 oficial. Fonte do backend lida por Git no commit `4f858b6` do PR #100.
Nenhum acesso ao Supabase, execução de SQL ou alteração de migrations.
Os testes nativos usam fixtures dos retornos registrados no PR. As imagens
coloridas são fixtures, não novos assets ou conteúdo publicado.

## Verificações executadas

| Verificação | Resultado |
|---|---|
| Revisão nativa, com nickname nulo, capa por carta, prévias nulas, cache por abertura/URL, permissões e retirada | 25 verificações em cada resolução; 0 falhas |
| Resoluções capturadas | 1672×941, 844×390 e 640×360 |
| Sync existente + correção de imagem no mesmo caminho/recorte + retomada sem upload repetido | 25 verificações; 0 falhas |
| Editor/rascunhos T21 | 47 verificações; 0 falhas |
| Comunidade T27 | 14 verificações; 0 falhas |
| Verificação PlayerUI | OK |
| Export Web release oficial 4.7.2 | HTML/PCK/WASM gerados; sem erros de script/exportação |
| Parser dos três SQLs do PR #100 | 3 erros confirmados; ver `sql-review.json` |

Somente perfis iPhone usam `--iphone`/1200×675. Os arquivos `*_acoes.png` mostram
os controles depois de rolar o conteúdo. Nenhuma captura comprova uso em aparelho
físico ou o comportamento real do cache HTTP no navegador.

| Estado | Desktop | iPhone 844×390 | iPhone 640×360 |
|---|---|---|---|
| Prévia e autor sem nickname | [imagem](1672x941_revisao.png) | [imagem](844x390_revisao.png) | [imagem](640x360_revisao.png) |
| Aprovar/reprovar | [imagem](1672x941_acoes.png) | [imagem](844x390_acoes.png) | [imagem](640x360_acoes.png) |
| Conta sem permissão | [imagem](1672x941_sem_permissao.png) | [imagem](844x390_sem_permissao.png) | [imagem](640x360_sem_permissao.png) |

O teste de cache confirma leitura nova, conteúdo substituído e mudança da URL
de download na nova abertura. Cache local só é reutilizado dentro da abertura;
o comportamento CDN/browser de produção requer teste real. Os testes de decisão
simulam erro de negócio/retirada sem sessões reais ou concorrência simultânea.

O parser `pglast v8.7` analisou textos obtidos do Git. A verificação de terminadores
ocorreu apenas em memória. Nenhum banco foi conectado, nenhum SQL executado e os
arquivos do PR não foram alterados nem incorporados à branch do cliente.

V-Sync indisponível em Xvfb/Mesa e o aviso conhecido de duas instâncias ObjectDB
na regressão antiga de comunidade foram observados. Não houve erro de script
nesses testes finais. Testes HTTP com contas reais, RLS, concorrência entre dois
clientes, PWA e iPhone físico permanecem pendentes.

Detalhes, solicitação de correção dos arquivos do PR e roteiro de teste real:
[REVISAO_CLIENTE_PR100.md](../../docs/backend/REVISAO_CLIENTE_PR100.md).
