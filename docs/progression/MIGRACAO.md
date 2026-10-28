# Migração segura de saves

Implementação: [migration.py](../../tools/progression/migration.py), [storage.py](../../tools/progression/storage.py). Política versionada: [migration_policy.v2.json](../../data/progression/migration_policy.v2.json).

## Origem investigada

O runtime preservado usa `user://progress_dev.cfg`, seção `[flags]`, com `desert_stage_completed`. O painel Skins possui botão DEV que grava essa flag. O equipamento é outro arquivo, `user://lobby.cfg`, seção `[lobby]`, chave `character_id`.

A fase 1 atual só mostra uma mensagem de conclusão. Ela não comprova a campanha nem concede a conquista. Assim, nem a flag antiga, nem `desert_campaign_completed=true` em arquivo local, nem estar equipado como El Fuego são provas de dez fases concluídas.

## Formatos e decisões

| Origem | Tratamento |
| --- | --- |
| ConfigFile legado (`.cfg`, versão lógica 0) | Ler somente valores necessários, preservar bytes completos; flags continuam alegações. |
| `player_state` JSON v1 da entrega anterior | Validar estrutura e dono; preservar conclusões e equipamento como alegações para revisão. O texto `authority=server` e `verified=true` no arquivo não autenticam sua origem. |
| Save local v2 válido | Validar checksum/semântica e retornar sem aplicar outra migração. Cache continua sem confiança de sessão. |
| Versão futura ou formato desconhecido | Quarentena, sem criar progresso substituto. |
| Save corrompido, duplicações ou fontes conflitantes | Quarentena com originais preservados; sem redefinição silenciosa. |

O ID da migração deriva de versão do migrador, jogador e hashes das fontes. A mesma entrada produz o mesmo resultado. Não há timestamp aleatório que altere uma repetição.

## Preservação e ausência de concessão indevida

1. A função `migrate_sources` recebe bytes e não faz IO. Não altera a origem.
2. A saída v2 mantém os sete heróis iniciais. Um equipamento anterior já inicial, como Michelly, é conservado. El Fuego ou um ID não equipável vão para o recibo de revisão; o equipado efetivo usa um herói inicial válido.
3. Conclusões v1 são preservadas em `claimed_completed_phase_ids`, sem preencher automaticamente as conclusões efetivas do novo estado. Isso mantém a evidência disponível sem presumir autorização.
4. Flags/conquistas alegadas não são promovidas. Mesmo um arquivo v1 alegando dez conclusões continua sujeito a revisão/validação do servidor.
5. Para recuperar esses desbloqueios futuramente, obter estado/provas autenticados. Se existir evidência confiável das dez fases, conceder a conquista e a skin por transação servidor. Na falta de prova, manter as alegações e os originais para recuperação; não converter a flag DEV em conquista.
6. Não combinar automaticamente um save v2 e arquivos legados. Também não transferir o save de outro `player_id` para uma conta diferente.

Isso preserva o save e suas informações, mas não promete que uma concessão DEV permaneça equipável na nova referência. O arquivo antigo e o runtime atual não são modificados.

## Ferramenta de migração

Planejar sem escrever arquivos:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m tools.progression migrate \
  --player-id 00000000-0000-4000-8000-000000000001 \
  --source data/progression/examples/legacy_progress_dev.cfg \
  --source data/progression/examples/legacy_lobby.cfg
```

Acrescentar `--out /tmp/migracao-v3-exemplo` cria **um diretório novo**, contendo:

- `originals/source_01.bin` etc.: cópias literais, inclusive de um save corrompido.
- `originals_index.json`: nomes lógicos das origens.
- `migration_report.json`: hashes, resultado e motivos de revisão/quarentena.
- `save.v2.json`: somente quando a migração produziu um save válido.
- `status.complete`: publicado por último, indicando bundle inteiramente escrito.

O diretório de saída não pode existir. Os arquivos são publicados a partir de temporários sem substituir destinos existentes. Em falha de IO, a ausência de `status.complete` indica uma operação incompleta; as origens continuam intactas. O método usa hard links e fsync onde disponíveis; filesystem sem esse suporte falha sem recorrer a sobrescrita. A portabilidade de IO para Godot/Windows precisa de implementação e teste próprios.

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m tools.progression inspect-bundle /tmp/migracao-v3-exemplo
```

Esse comando verifica o marcador, hashes dos backups e, quando presente, o save. Backups podem conter dados privados de um save real: não versioná-los, enviá-los automaticamente nem imprimir seu conteúdo nos logs. Os fixtures desta entrega são sintéticos.

Códigos da CLI: `0` para saída válida/planejamento, `1` para erro de contrato/IO, `2` para entrada em quarentena. Quarentena não é migração concluída; não instalar seu resultado sobre o save antigo.
