# Integração Supabase — etapa 04

Base: `codex/telas-sistemas-jogador-03`, commit `e7ac72d`. Branch de trabalho: `codex/auditoria-supabase-04`.

## Estado real

Não existe conector autenticado ou variável de conexão Supabase neste ambiente. Nenhuma consulta foi executada no projeto remoto. Não é possível afirmar compatibilidade das migrations com o banco atual, nem declarar perfil, carteira, amizades ou progresso conectados.

A consulta [audit_readonly.sql](../../tools/backend/audit_readonly.sql) prepara inspeção de schemas, colunas, constraints, RLS, funções, grants, privilégios padrão, triggers e publicações. Usa transação somente leitura e não consulta registros de jogadores. A visibilidade dos metadados depende das permissões da conexão; resultados parciais não provam ausência de objetos. Definições de funções podem conter informações sensíveis de sistemas legados: revisar o relatório local antes de compartilhá-lo ou versioná-lo.

## Critérios de compatibilidade antes de qualquer aplicação

- Comparar todos os objetos existentes com as migrations 0001–0003, especialmente funções `public.qse_*`, namespace `qse_v3` e políticas de `realtime.messages`.
- Identificar a fonte atual de saldo, equipamento, perfis e campanha. Não inicializar carteiras paralelas com zero para usuários existentes nem substituir a fonte atual sem reconciliação.
- Verificar triggers em `auth.users`, dependências, owners, funções SECURITY DEFINER e search_path.
- Conferir políticas permissivas/restritivas, grants diretos, privilégios padrão, papéis administrativos e acesso entre participantes de amizades.
- Preparar mudanças compatíveis e reversíveis após obter esses resultados; não executar automaticamente os arquivos anteriores.

## Sessão persistente

A entrega 03 mantém tokens apenas em memória. Portanto, **sessão persistente ainda não está implementada**. A implementação deverá definir armazenamento protegido no Android e política de sessão Web, refresh, expiração, saída e limpeza ao trocar de conta. Não persistir refresh tokens em ConfigFile simples nem tratar cache local como autorização.

## Testes remotos pendentes

Com duas contas de teste autorizadas, verificar login/refresh/reabertura, leitura e edição do perfil próprio, privacidade do outro perfil, carteira/ledger somente servidor, equipamento autorizado persistido, pedidos de amizade e presença, além da sequência das dez fases. Usar usuários separados, provas controladas de servidor e nenhuma concessão econômica pelo cliente.

Os testes PostgreSQL locais da etapa 03 não equivalem a esses testes remotos. Godot permanece necessário para validar APIs, HTTP/WSS, armazenamento por plataforma, UI, importação dos modelos e fluxo completo. Gameplay, modelos, menu e as três entregas anteriores não foram alterados nesta etapa.
