# Revisão manual com Storage — 05/11/2026

Branch `work/decks-storage-revisao-manual`, baseada na main `51d2f18`.
Godot 4.7.2 oficial. Fixtures locais de JWT/usuários/Storage/RPC; nenhuma chamada
ao Supabase real. Os retângulos coloridos são prévias de teste, não assets novos.

## Testes executados

| Teste | Resultado |
|---|---|
| Revisão: RPC ausente, papéis, fila, paths, prévias, aprovação/reprovação, falha de rede, cliques repetidos e troca de conta | 17 verificações, 0 falhas por resolução |
| Capturas nativas em 1672×941, 844×390 e 640×360 | 3 execuções com 17 verificações, todas sem falhas |
| Editor T21, incluindo prompt e referência oficial | 47 verificações, 0 falhas |
| CreatorSync/Data API/Storage/favoritos existentes | 22 verificações, 0 falhas |
| Comunidade T27, incluindo envio duplo bloqueado | 14 verificações, 0 falhas |
| `python3 tools/player_ui/check_design.py` | OK |
| Importação oficial Godot 4.7.2 | Sem erros de scripts/importação |
| Export Web release oficial 4.7.2 | HTML, PCK e WASM gerados; sem erros de script/import/export |

Os logs estão nesta pasta. O backend da fixture implementa o contrato **proposto**,
não comprova a existência/permissão das RPCs no projeto real. A validação real
é pendência do responsável pelo Supabase. Capturas do motor não equivalem a
teste de navegador ou iPhone físico.

## Capturas do motor

| Estado | Desktop | iPhone 844×390 | iPhone 640×360 |
|---|---|---|---|
| Deck e prévias | [imagem](1672x941_revisao.png) | [imagem](844x390_revisao.png) | [imagem](640x360_revisao.png) |
| Aprovar/reprovar após rolar | [imagem](1672x941_acoes.png) | [imagem](844x390_acoes.png) | [imagem](640x360_acoes.png) |
| Conta sem papel de revisor | [imagem](1672x941_sem_permissao.png) | [imagem](844x390_sem_permissao.png) | [imagem](640x360_sem_permissao.png) |

Somente os perfis iPhone usam `--iphone` e base 1200×675. Desktop mantém a base
1672×941. Tema via PlayerUI e fundo interno opaco; nenhum tema paralelo.

## Reprodução

```bash
godot --headless --path . --script res://tests/deck_storage_review/flow.gd
xvfb-run -a godot --path . --script res://tests/deck_storage_review/flow.gd -- /tmp/deck-review 844x390 --iphone
godot --headless --path . --script res://tests/decks_t21/flow_test.gd
godot --headless --path . --script res://tests/decks_t21/sync_test.gd
godot --headless --path . --script res://tests/community_t27/flow_test.gd
```

Usar `XDG_DATA_HOME` isolado para não misturar rascunhos de desenvolvimento com
fixtures dos testes existentes. Não há código de Worker nesta branch.
V-Sync indisponível em Xvfb/Mesa é um aviso do ambiente; não houve erro de script
nas capturas finais. Aprovação real, RLS, Storage de produção, custos/quotas e
integração dos decks com o catálogo de partidas ainda precisam ser conferidos.
