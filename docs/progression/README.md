# Tarefa Offline 02 — progressão e desbloqueios

Branch-base: `codex/preparacao-offline-deserto` (`943c890`). Branch de trabalho: `codex/progressao-offline-02`. Implementação nova e isolada; nenhum dos 457 arquivos anteriores foi alterado.

## Entregas

- [Contrato normativo v2](CONTRATO_V2.md): sequência, personagens, checkpoints, conquistas, equipamento, versões e integridade.
- [Migração e recuperação](MIGRACAO.md): flags legadas, saves v1/v2, backups literais, quarentena e ausência de concessões automáticas.
- [Sincronização](SINCRONIZACAO.md): autoridade servidor, revisões, idempotência, conflitos e limites dos adaptadores.
- [Roteiro para o Claude integrar ao Godot](INTEGRACAO_CLAUDE.md).
- [Validação executada e limites](VALIDACAO.md): 88 testes novos e 37 anteriores aprovados.
- [Regras](../../data/progression/rules.v2.json), [política de migração](../../data/progression/migration_policy.v2.json), [JSON Schema](../../data/progression/contract.v2.schema.json) e [fixtures sintéticos](../../data/progression/examples).
- Biblioteca Python em `tools/progression/`: redutor puro, envelopes, migrador, IO seguro de saída nova, servidor de referência e cliente de referência.

## Executar offline

Python 3.10+ e `jsonschema==4.26.0`, já disponível neste ambiente e declarado na entrega anterior em `tools/offline/requirements.txt`. Não foi necessário instalar pacotes nem acessar rede nesta tarefa.

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m tools.progression check
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tools/progression/tests -v
PYTHONDONTWRITEBYTECODE=1 python3 -m tools.progression demo
PYTHONDONTWRITEBYTECODE=1 python3 -m tools.progression inspect data/progression/examples/offline_complete.save.json
```

`demo` é uma simulação de regras. Só a décima conclusão gera a conquista/skin provisória; o relatório declara que não concedeu desbloqueio online definitivo.

Migração somente de inspeção, sem escrever:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m tools.progression migrate \
  --player-id 00000000-0000-4000-8000-000000000001 \
  --source data/progression/examples/legacy_progress_dev.cfg \
  --source data/progression/examples/legacy_lobby.cfg
```

Acrescentar `--out` com um diretório inexistente produz backups e resultado novos. Nunca usar um caminho de saída existente ou instalar automaticamente um resultado em quarentena.

## Resultado e limites

Os testes cobrem jogador novo, parcial, fases 9/10, salto de fases, checkpoints, legado/corrupção, duplicação, El Fuego bloqueado no lobby e protagonista na campanha, concorrência, reinício do journal, rebase, cache não confiável e evidência reutilizada.

O runtime continua usando a flag legada porque não foi conectado a esta biblioteca. O verificador antigo continuará emitindo o aviso dessa migração pendente. A referência v2 implementa as novas regras sem afirmar que elas já estão ativas no jogo.

Nenhum teste de gameplay, importação ou execução do Godot/Blender foi realizado. Nenhum serviço remoto foi acessado. O servidor de referência não é um backend implantado: sem adaptador/verificador confiável, conclusões online são negadas.
