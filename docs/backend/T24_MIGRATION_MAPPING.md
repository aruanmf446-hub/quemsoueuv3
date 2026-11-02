# T24 — reconciliação das migrations versionadas

Os bancos GAME e CATALOG já haviam recebido a T24 por migrations incrementais no Supabase. O PR #50 inicialmente usava versões `20261101000x` anteriores à T20/T21, o que impediria a reconstrução de um banco novo.

Por isso, os SQLs consolidados da T24 foram movidos para versões `2026110200xxxx`, **após a T20/T21/T22** e correspondentes ao histórico real dos dois bancos. A migração `20261102003754` do GAME contém toda a implementação consolidada da Comunidade (itens 3a–3e). As entradas 3b–3e no repositório são intencionalmente vazias: representam passos que já foram aplicados no banco oficial e estão cobertos pelo SQL consolidado ao instalar do zero. O índice de denúncias da etapa 6 também já é criado na migration consolidada.

O mesmo vale para CATALOG: `20261102003349` contém adição, preenchimento e `NOT NULL` de `published_at`; `20261102003402` registra o segundo passo remoto já incluído na consolidação.

**Não reaplique manualmente migrations já registradas no histórico Supabase.** Essas mudanças não acessam nem modificam dados existentes nos projetos ao fazer merge no GitHub.

Ao instalar um ambiente novo, aplicar os arquivos em ordem crescente por projeto. As migrations de capa/zoom/destaques do PR #53 aparecem depois da Comunidade e usam as versões originais do deploy.

Teste positivo de Comunidade com quatro contas dedicadas (um autor e três denunciantes) e testes de sincronização HTTP reais ainda não foram realizados. **A Comunidade permanece desligada no cliente até homologação**, independentemente deste merge.
