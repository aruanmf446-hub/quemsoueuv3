# Verificações estáticas e limitações

Ferramentas em Python 3.10+; única dependência externa de validação: `jsonschema==4.26.0`, declarada em `tools/offline/requirements.txt`. O inventário binário usa apenas a biblioteca padrão. Nenhum comando desta página executa Godot ou Blender.

## Comandos

```sh
# Conferir propostas, contratos, referências, hashes e preservação da base.
PYTHONDONTWRITEBYTECODE=1 python3 tools/offline/validate.py

# Executar os casos adversariais do próprio verificador.
PYTHONDONTWRITEBYTECODE=1 python3 tools/offline/test_validation.py

# Salvar um relatório legível por máquina, sem alterar o jogo.
PYTHONDONTWRITEBYTECODE=1 python3 tools/offline/validate.py --report /tmp/v3-validation.json

# Reprovar também a regra legada que ainda não foi migrada no runtime.
PYTHONDONTWRITEBYTECODE=1 python3 tools/offline/validate.py --strict-runtime

# Reproduzir a auditoria em pasta separada, sem converter os originais.
PYTHONDONTWRITEBYTECODE=1 python3 tools/offline/audit_project.py --out /tmp/v3-audit
```

Código de saída de `validate.py`: `0` para propostas consistentes/base preservada; `1` para erros. Os avisos permanecem visíveis. O modo **`--strict-runtime` deve retornar `1` nesta entrega**, com `runtime_unlock_contradiction`, porque `desert_stage_completed` continua na regra ativa. Não tratar esse resultado conhecido como migração concluída nem remover o aviso para fazer o relatório ficar verde.

## Cobertura

- Leitura JSON estrita: chaves repetidas, `NaN`, tipos errados, campos obrigatórios ausentes e campos desconhecidos.
- Dez JSON Schemas Draft 2020-12: catálogo, campanha, fase, recursos, dependências, estado de jogador, operação, tentativa, serviço proposto e manifesto.
- IDs duplicados em personagens, catálogo ativo, fases, checkpoints, recursos, dependências, conquistas, conclusões, desbloqueios e objetos do manifesto.
- Referências `res://` a arquivos/diretórios existentes; rejeição de `..`, escape de diretório e separadores incompatíveis. Os recursos ainda não produzidos são pendências com IDs, sem caminhos fictícios declarados existentes.
- Preservação dos IDs, nomes, grupos e modelos do catálogo ativo; inimigos/chefes não equipáveis.
- El Fuego bloqueado inicialmente no lobby e disponível como protagonista na campanha; Cactus como inimigo; Malagueta somente na conclusão da fase 10.
- Dez IDs em ordem, pré-requisito da fase anterior, checkpoints distintos, ausência de conclusão por checkpoint e proibição de conquista/desbloqueio antecipados.
- Conquista com dez conclusões verificadas, conjunto de desbloqueios coerente e equipamento pertencente ao jogador. Essas regras são simulações de contrato, não autorização de um servidor implantado.
- Tamanho/SHA-256 dos 130 assets do manifesto; IDs, donos, reinos, chaves imutáveis e estados locais de não publicação.
- Hashes dos 408 arquivos originais e comparação com o commit Git auditado. O gerador se recusa a regravar o snapshot como base intacta se um arquivo original mudou.
- FBX binário 7700 observado nos originais: modelos, vértices, polígonos, ossos, parentesco, deformadores Skin/Cluster, pilhas/curvas de animação, intervalos de chaves, eixos/unidades e referências de textura.
- OBJ: contagem e referências de materiais, com distinção explícita de malha estática. GLB: cabeçalho/chunks, metadados de skins, acessórios, texturas embutidas e extensões requeridas.

O extrator de dependências reconhece referências literais e nomes de classes; não compila GDScript. Exemplos e caminhos opcionais do addon são registrados separadamente. A inexistência de referências literais ausentes não prova que todas as dependências dinâmicas estejam corretas.

## Resultado desta entrega

- Validação das propostas: **zero erros e dois avisos explícitos** — regra legada e ausência de execução do motor.
- Testes adversariais: **37 testes aprovados**. Cobrem troca de protagonista, IDs repetidos, Cactus/Malagueta equipáveis, falta de pré-requisito, conquista após só a fase 1 ou só a fase 10, alteração da flag legada por suposição, recompensa monetária não prevista, UUID inválido, arquivo ausente/corrompido e mudança de fonte protegida.
- Auditoria: oito cenas, 16 scripts do jogo, 49 scripts do addon e 130 assets-fonte, incluindo 45 FBXs, dez OBJs e dois GLBs de acessórios.
- Nenhuma referência literal ausente nos arquivos do jogo examinados. Os dois GLBs são `espada.glb` de Lorena e `arco.glb` de Michelly, estáticos, com textura embutida.
- Malagueta: `ataque de baixo pra cima.fbx` contém malha/skin e 65 ossos; os outros quatro FBXs são animação/esqueleto sem malha. Isso foi confirmado estruturalmente, sem teste de reprodução.
- Nenhuma tabela, bucket, credencial ou upload criado; cenas e código de gameplay preservados.

[Relatório da validação](generated/validation_report.json) · [Snapshot e pendências](generated/audit_snapshot.json) · [Inventário completo](generated/asset_inventory.json).

## O que não foi possível validar

Importação real em Godot 4.7, compilação GDScript, hierarquia final de nós/ossos, vinculação de trilhas, retarget, aparência e textura renderizada, deformação, sockets, root motion, colisões, câmera, controles, alcance dos saltos, persistência durante o jogo, IA, chefe, completabilidade das fases, desempenho e exportação para Web/celular. Também não foram testadas políticas, funções, downloads, cache ou permissões de serviços remotos, porque não foram implantados.

Não alterar a versão jogável nem converter a existência de um arquivo de planejamento em evidência de implementação.
