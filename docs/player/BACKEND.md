# Conexão real com Supabase

Destino configurado: `https://xgmlphejalzakucllsmw.supabase.co`. Não havia conector autenticado nem variáveis Supabase neste ambiente. A conexão real **não foi realizada**; não há credenciais no repositório. Os adaptadores usam HTTPRequest/PostgREST, GoTrue Auth e WebSocketPeer/Realtime de verdade, sem mocks de produção.

## Antes da aplicação

Executar [preflight.sql](../../supabase/preflight.sql) por uma conexão administrativa autorizada e revisar namespace `qse_v3`, funções `public.qse_*`, `auth.users`, permissões e políticas em `realtime.messages`. Não executar [bootstrap_local.sql](../../supabase/tests/bootstrap_local.sql) em Supabase: esse arquivo cria apenas a superfície SQL de Auth/Realtime no cluster descartável dos testes.

As migrations usam um namespace novo e `CREATE`, sem `CREATE OR REPLACE`, remoção de tabelas ou backfill automático. Colisões interrompem a aplicação e devem ser revistas. Aplicar na ordem:

1. [0001 — tabelas, catálogo e RLS](../../supabase/migrations/202610280001_player_foundation.sql).
2. [0002 — RPCs e ledger](../../supabase/migrations/202610280002_player_api.sql).
3. [0003 — presença privada](../../supabase/migrations/202610280003_private_presence.sql), após confirmar Realtime com RLS habilitado e canais privados autorizados.

A aplicação remota depende dessa revisão; nenhum comando de deploy automático foi incluído no cliente ou executado nesta tarefa.

Se o projeto já possuir perfis, carteiras ou progresso em outro schema, definir seu mapeamento e migração antes de ativar estas RPCs para jogadores existentes. A inicialização de uma carteira nova em `qse_v3` não migra saldos anteriores e não deve substituir uma fonte existente sem essa reconciliação.

## Configuração do cliente

[client.json](../../data/backend/client.json) contém somente URL e chave vazia. Chaves `sb_secret_*` e JWTs com papel administrativo são recusados. Não fornecer service_role ao jogo.

Em uma execução nativa autorizada, definir `QSE_SUPABASE_PUBLISHABLE_KEY` no ambiente que inicia o Godot ou criar **fora do Git**, no `user://backend.cfg`:

```ini
[supabase]
publishable_key="SUA_CHAVE_PUBLICAVEL"
```

Na Web, o shell de exportação pode definir este objeto **antes** de iniciar o jogo:

```html
<script>
globalThis.QSE_PUBLIC_CONFIG = Object.freeze({
  publishable_key: "SUA_CHAVE_PUBLICAVEL"
});
</script>
```

Uma chave publicável é necessariamente visível ao navegador. Ela não substitui login, RLS ou validação de servidor. A configuração versionada continua vazia. Confirmar domínio/CORS, confirmação de e-mail, limites de Auth e suporte HTTPS/WSS no deployment escolhido.

Para distribuir um APK, o pipeline também pode preencher a chave publicável na cópia de `client.json` usada para exportar, mantendo o arquivo do Git vazio. Nunca usar uma chave administrativa nessa etapa.

Tokens de acesso e refresh permanecem em memória, sem logs ou saves. Ao sair, os dados locais da conta são limpos imediatamente e tenta-se revogar apenas a sessão atual (`scope=local`). Se o dispositivo estiver offline, a revogação remota não pode ser confirmada. Recarregar o jogo exige novo login. Preferências do dispositivo e a demonstração não guardam informações de conta.

## Contratos de RPC

[api.json](../../data/ui/api.json) relaciona os onze endpoints e nomes exatos de parâmetros. [services.schema.json](../../data/ui/services.schema.json) define perfil, fragmento público, listas, carteira e histórico. Progresso usa integralmente o [contrato v2 anterior](../../data/progression/contract.v2.schema.json).

| RPC | Autoridade e retorno |
| --- | --- |
| `qse_profile_self`, `qse_profile_update` | Dono obtido de `auth.uid()`. Edição só do nickname, 3–24 caracteres sem controles. Nível, XP e estatísticas são opcionais e somente servidor. |
| `qse_account_preferences` | Preferência de descoberta da própria conta. Áudio/teclas/idioma não vão nessa tabela. |
| `qse_find_players`, `qse_profile_public` | Somente ID, nickname, nível público e skin equipada. Busca limitada, sem e-mail, carteira, XP ou campanha. Perfil não descobrível só fica acessível ao dono/amigos. Perfil indisponível retorna `{}`. |
| `qse_friends`, `qse_friend_action` | Relações e pedidos próprios; apenas destinatário aceita/recusa e apenas remetente cancela. Autoamizade e aceitação implícita de pedidos cruzados são negadas. UUID de idempotência vinculado a dono e conteúdo. |
| `qse_wallet`, `qse_wallet_history` | Somente leitura da carteira própria. Valores inteiros são strings para evitar perda de precisão em Web; histórico de 20 itens, cursor por sequência estável. |
| `qse_progression_snapshot`, `qse_progression_command` | Snapshot v2, revisão esperada e requisição idempotente. Cliente não escolhe dono, conquistas, desbloqueios ou valores econômicos. |

Todas as funções públicas exigem `authenticated`; `anon` não recebe execução. Tabelas privadas têm RLS de dono/participante e nenhuma escrita direta para o cliente. Funções `SECURITY DEFINER` usam `search_path=''` e filtros explícitos por identidade. Exceções e respostas incompatíveis viram estados de erro, sem exibir SQL ou tokens.

`qse_v3.post_wallet_entry` é uma operação **privada de servidor**, sem RPC no schema exposto e sem permissão para o cliente. Ela bloqueia a carteira, valida moeda/valor/saldo, grava ledger e saldo na mesma transação e compara conteúdo em reenvios. Nenhuma compra ou recompensa de fase chama essa operação nesta tarefa.

## Progressão, migração e conflitos

O comando mantém `protocol_version=2` e `rules_version=desert_progression_2.0.0`, com operações `start_phase`, `record_checkpoint`, `complete_phase`, `equip_character`. Nesta UI o adaptador envia apenas equipamento; o protótipo não envia vitórias.

Conclusões exigem prova previamente registrada por serviço confiável: dono, tentativa, fase, saída, expiração e Malagueta na fase 10. O cliente não lê nem insere provas. Checkpoint não conclui fase. Conclusões duplicadas são no-op. Conquista e El Fuego são concedidos na mesma transação da décima conclusão, sem moedas/XP inventados.

Revisão divergente devolve `revision_conflict` e snapshot. O cliente não faz união de desbloqueios nem rollback e não repete automaticamente uma mutação com conteúdo diferente. Após revisar o snapshot, uma nova intenção usa outro UUID. Reenvio idêntico no servidor recupera a resposta anterior.

Arquivos antigos `progress_dev.cfg`, `lobby.cfg` e saves v2 não são sobrescritos. Apenas uma seleção inicial válida pode ser lida do lobby antigo para a demonstração. Flags, inclusive `desert_stage_completed`, nunca viram autorização. A [migração isolada anterior](../progression/MIGRACAO.md) continua disponível, preservando originais e claims para análise; não há upload/backfill automático de saves locais.

## Presença e atualização

Cada jogador publica presença apenas em `friend-presence:<seu UUID>`. Amigos podem ler esse tópico privado; metadados enviados pelo cliente não determinam a identidade. Guardas restritivas protegem o namespace contra políticas permissivas anteriores e deixam outros tópicos sob suas políticas existentes. Validar a versão/configuração Realtime real antes de habilitar.

O adaptador implementa join, track, heartbeat, state/diff por sessão e reconexão. Queda de conexão mostra presença indisponível, sem confundi-la com offline confirmado. Remover amigos reconcilia inscrições. Autorizações Realtime podem ser armazenadas em cache pelo servidor; verificar revogação e renovação JWT em duas sessões reais.

Carteira, relações e progressão são consultadas a cada 30 segundos quando autenticado, além dos botões de atualização. Miniaturas vêm do cache local; a lista de amigos não instancia modelos 3D. Perfil público instancia somente a prévia selecionada. O teste SQL não substitui testes de WebSocket, CORS ou concorrência da UI no Godot.
