# Verificações da Tarefa 03

Base `d90dcb57e253a95e5ef13f05ea2b8c0f6024660f`. Motor alvo 4.7.2/Compatibility; Godot e Blender não foram iniciados.

| Verificação | Resultado |
| --- | --- |
| Testes estáticos de cenas, rotas, catálogo, contratos, exportação e migração | 21 testes passaram. |
| Migrations e políticas em PostgreSQL 17 descartável local | 34 testes passaram. |
| Regressão da biblioteca v2: redutor, migração e sincronização | 80 testes passaram. |
| Total | **135 testes passaram**, sem falhas. |
| Análise de scripts/cenas | 42 scripts GDScript analisados; 16 cenas percorridas, incluindo oito novas e heranças/NodePaths. |
| Preservação | 490 arquivos anteriores conferidos; apenas nove mudanças justificadas de UI/configuração; 82 arquivos das tarefas 01/02 intactos. |
| Banco remoto, GoTrue HTTP, Realtime WebSocket e cliente Godot | Não executados. |
| Renderização, gameplay, exportação e desempenho | Não executados. |

Os testes SQL executam as migrations reais, com funções, constraints, transações, RLS e papéis distintos. Auth e Realtime têm apenas a superfície SQL mínima no cluster local; isso não simula um serviço Supabase conectado. Os testes também validam as respostas reais do banco com JSON Schema e snapshots com o redutor v2 anterior.

Casos incluem isolamento, leitura pública restrita, alterações diretas recusadas, solicitações cruzadas/duplicadas, preferências de descoberta, paginação, ledger idempotente e concorrente, fases sequenciais, checkpoints, provas de outro dono/expiradas, Malagueta, fase 9 versus 10, equipamento e revisão concorrente. Guardas de presença foram testadas também diante de políticas permissivas adicionais.

O parser gdtoolkit 4.5 verifica sintaxe GDScript, não tipos, APIs ou compatibilidade visual com Godot 4.7.2. pglast verifica SQL e o PostgreSQL verifica sua execução. Nenhuma dessas verificações substitui o [roteiro no motor](TESTES_GODOT.md).

## Reproduzir sem Godot

```bash
python3 -m venv /tmp/qse-ui-tests
/tmp/qse-ui-tests/bin/pip install -r tools/player_ui/requirements.txt
/tmp/qse-ui-tests/bin/python -m tools.player_ui.check
```

Com PostgreSQL 17 instalado, apontar `QSE_PG_BIN` ao diretório que contém `initdb`, `pg_ctl` e `psql`:

```bash
QSE_PG_BIN=/caminho/postgresql/17/bin /tmp/qse-ui-tests/bin/python -B -m unittest \
  tools.player_ui.test_static tools.player_ui.test_database \
  tools.progression.tests.test_engine tools.progression.tests.test_migration \
  tools.progression.tests.test_sync -v
```

O runner SQL cria um cluster em `/tmp`, sem TCP, e o encerra/remove ao terminar. Sem `QSE_PG_BIN`, a suíte SQL registra skip; não trocar por uma URL remota para obter um resultado verde. Nesta entrega, os 34 testes SQL foram efetivamente executados com PostgreSQL 17 extraído temporariamente, sem instalar servidor no projeto.

As antigas verificações `tools/offline/validate.py` e `tools.progression check` protegiam a imutabilidade integral das tarefas de preparação. Continuam preservadas como registros daquela etapa; sua barreira de imutabilidade não se aplica às nove alterações de interface agora autorizadas. Não foram alteradas para ocultar diferenças. O novo `tools.player_ui.check` verifica esses nove caminhos explicitamente e continua rejeitando mudanças em gameplay, assets e nos 82 arquivos offline.

O [resultado estruturado](VALIDACAO.json) registra limites e contagens; [ARQUIVOS.md](ARQUIVOS.md) relaciona a entrega. Logs locais de execução não contêm credenciais nem são tratados como testes de gameplay.
