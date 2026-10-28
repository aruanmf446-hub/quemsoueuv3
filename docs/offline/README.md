# Quem Sou Eu V3 — preparação offline

Base: `957fce5`. Branch de trabalho: `codex/preparacao-offline-deserto`.

Esta entrega acrescenta documentação, propostas de dados e ferramentas estáticas. Os 408 arquivos originais — incluindo cenas, scripts, modelos, catálogo e regras ativas — foram preservados. Não foram executados Godot ou Blender; não houve alterações em Supabase/R2.

## Documentos

1. [Auditoria da estrutura e sistemas existentes](AUDITORIA.md).
2. [Catálogo e regras de disponibilidade](CATALOGO.md).
3. [Dez fases do Reino do Deserto](CAMPANHA_DESERTO.md).
4. [Inventário por personagem](generated/assets.md) e [evidências estruturais completas](generated/asset_inventory.json).
5. [Proposta Supabase](ARQUITETURA_SUPABASE.md) e [proposta R2](ARQUITETURA_R2.md).
6. [Verificações, comandos e limitações](VALIDACAO.md).
7. [Próximas tarefas sem Godot](PROXIMAS_TAREFAS.md).

## Dados preparados

- `data/planning/character_registry.json`: dez identidades; sete liberadas, El Fuego desbloqueável/protagonista, Cactus inimigo e Malagueta chefe.
- `data/planning/desert_campaign.json` e `data/planning/desert/phase_01.json` a `phase_10.json`: sequência, narrativa, ambientação, dificuldade, obstáculos, inimigos, checkpoints, conclusão, recompensas não monetárias e dependências.
- `data/planning/resource_requirements.json` e `implementation_dependencies.json`: recursos existentes/não verificados e pendências declaradas.
- `data/planning/asset_manifest.local.json`: 130 arquivos-fonte, tamanhos, hashes e organização proposta; nenhum upload.
- `data/contracts/`: dez JSON Schemas, proposta de serviço e dois estados sintéticos de jogador.
- `tools/offline/`: auditoria, inspeção FBX/OBJ/GLB, validação e testes adversariais.

Os novos dados não são carregados automaticamente pelo jogo. `data/characters.json` continua no formato e conteúdo originais.

## Pendência crítica de migração

A regra preparada libera El Fuego no lobby após as dez fases, com `desert_campaign_completed`. O runtime preservado ainda usa `desert_stage_completed`. A fase 1 apenas exibe sua mensagem de conclusão; não concede a conquista. A migração e a persistência remota continuam futuras, documentadas e detectáveis por `--strict-runtime`.

```sh
python3 -m pip install -r tools/offline/requirements.txt
PYTHONDONTWRITEBYTECODE=1 python3 tools/offline/validate.py
PYTHONDONTWRITEBYTECODE=1 python3 tools/offline/test_validation.py
```

Esses comandos não iniciam o motor e não usam serviços remotos. A instalação da dependência de ferramentas pode exigir rede ou um wheel local; no ambiente desta entrega `jsonschema==4.26.0` já estava disponível e não foi necessário instalar pacotes. Aprovação estática não equivale a aprovação da versão jogável.
