# R2 — manifesto e distribuição propostos

Nenhum bucket, objeto, upload ou configuração remota foi criado. O [manifesto local](../../data/planning/asset_manifest.local.json) inventaria 130 arquivos-fonte reais e contém apenas caminhos locais, tamanhos, hashes e **chaves propostas**. `publication_status=not_uploaded` e `runtime_ready=false` em todos os itens.

Contrato: [asset_manifest.schema.json](../../data/contracts/asset_manifest.schema.json). O arquivo gerado é uma base de planejamento, não uma lista de URLs públicas nem autorização para publicar originais.

## Organização e identidade

- `asset_id` deriva do caminho-fonte original: `source:assets/...`. Alterar bytes mantém esse ID lógico, mas gera novo hash/versão de conteúdo.
- `source_path` conserva nome, acentos, espaços e capitalização originais. Não renomear os assets do projeto para atender ao armazenamento remoto.
- Chaves propostas para fontes: `sources/v1/realms/<desert|shared>/characters/<id>/<sha256>/<arquivo-normalizado>`; arte da interface fica em `sources/v1/shared/ui/<sha256>/...`.
- El Fuego, Cactus e Malagueta pertencem ao Deserto neste planejamento. Os outros personagens ficam em `shared`, sem inventar reinos para eles.
- GLBs de acessórios continuam ligados ao dono indicado pelo diretório. Um arquivo novo não vira personagem automaticamente.

Essa organização distingue fontes de futuras versões prontas para o motor. Renomear um MTL/arquivo no armazenamento não reescreve suas referências internas: as fontes são destinadas a arquivo/pipeline, não a carregamento direto pelo jogo.

## Formato de manifesto

Cada item inclui `asset_id`, `source_path`, `character_id`, `realm_id`, `variant`, formato, bytes, SHA-256, chave proposta e estado de publicação. O manifesto possui versão de schema, `release_id` e commit da auditoria. IDs e chaves duplicados, falta de arquivo ou divergência de tamanho/hash são erros estáticos.

Uma release futura para clientes precisará de um manifesto **separado** para os derivados aprovados, com versão mínima do aplicativo/motor, dependências entre arquivos e variante por plataforma. O identificador `offline-audit-957fce5` desta entrega não representa release publicada.

## Importação Godot e derivados

O carregador atual usa `load(path) as PackedScene`. O Godot transforma FBX/OBJ/GLB em recursos importados antes da exportação; o cache `.godot/` é gerado e não foi criado nesta tarefa. Um FBX baixado do R2 durante o jogo não se torna um `PackedScene` só por estar no disco.

Antes de integrar downloads, escolher e testar uma estratégia:

- Pacotes de recursos `.pck` produzidos pelo pipeline Godot compatível com a versão/plataforma; ou
- Derivados GLB e um carregador de runtime apropriado, a ser validado com `GLTFDocument`, materiais, texturas, rig e animações reais.

Não definir essas duas alternativas como intercambiáveis sem teste. Separar o arquivo-fonte de publicação e o derivado utilizado pelo cliente. Compressão de geometria/textura e formatos como KTX2 precisam de suporte confirmado no pipeline e nas plataformas escolhidas. Não há conversão, otimização ou promessa de desempenho nesta entrega.

## Integridade e cadeia de confiança

1. Obter o identificador e o digest do manifesto por uma origem confiável do aplicativo/servidor, ou por uma assinatura verificada com chave pública do aplicativo. O hash recebido no mesmo manifesto não autentica o próprio manifesto.
2. Resolver as dependências da release e verificar versão compatível antes de baixar.
3. Baixar cada objeto para arquivo temporário; conferir tamanho e SHA-256 contra o manifesto confiável.
4. Só após validação, promover por troca atômica ao cache final. Um arquivo parcial, de hash errado ou formato incompatível não deve substituir o válido anterior.
5. Ativar a release apenas quando todos os arquivos necessários estiverem prontos. Manter a release anterior para recuperação.

ETag é útil para revalidação, mas não substitui o SHA-256 nem a autenticação do manifesto. CORS, URLs assinadas ou acesso por um serviço intermediário são decisões futuras; permissões de escrita devem ficar restritas ao pipeline/servidor.

## Cache

- Conteúdo endereçado pelo hash, imutável; o manifesto aponta para versões, sem sobrescrever objetos aprovados.
- Manifesto de release revalidado por versão/ETag; conteúdo já verificado é reutilizado pelo hash.
- Persistência local no diretório de dados do aplicativo, com índice de versões e referência aos objetos usados; não inserir arquivos baixados em caminhos `res://` fixos por suposição.
- Evicção por uso e tamanho, preservando objetos referenciados pela release ativa e a recuperação escolhida. O orçamento final depende dos dispositivos-alvo; nenhum limite arbitrário foi inventado.
- Interrupção de download deixa apenas temporário; retentativas idempotentes e remoção segura de temporários não afetam o conteúdo ativo.

## Próximas verificações offline

Comparar manifestos entre commits, detectar arquivo alterado/renomeado, medir duplicação de bytes e documentar licenças. Os originais permanecem intactos. Importação dos derivados e desempenho precisam de uma etapa posterior no motor.
