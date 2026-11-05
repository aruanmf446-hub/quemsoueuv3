# Pendências de backend — 05/11/2026

Pedido do dono: publicar as melhorias do Mata-Mata e exigir nickname único e
imutável para contas cadastradas. **O modo local sem conta continua disponível.**

O Codex não acessou o Supabase nem alterou migrations/Edge Functions. O estado
real dos projetos precisa ser inspecionado pelo responsável com o plugin.
As migrations do repositório são referência histórica, não prova da versão implantada.

## Cliente pronto

- Cadastro inicial obrigatório após autenticação Google/Discord/e-mail, incluindo
  perfil com nickname `null`, vazio, `Sem nickname` ou `Jogador local`.
- Perfil ainda carregando/indisponível mantém o bloqueio, com Atualizar e Sair da conta.
- Não registra automaticamente nome OAuth, e-mail ou um nome aleatório: exige confirmação.
- Editor de troca removido de Perfil/Ajustes; o serviço do cliente recusa outra gravação
  quando o perfil da conta já tem nickname válido.
- A confirmação aguarda a resposta e a releitura do perfil; não aceita resultado de outra sessão.
- Erros `nickname_taken`, `nickname_locked`, `nickname_required` têm mensagens próprias;
  `23505` durante o cadastro é apresentado como nickname ocupado.
- Convidados offline continuam identificados como Jogador local. Isso não é conta global.

**A unicidade global e a trava contra chamadas diretas dependem do backend.**
Não há como comprová-las no banco a partir de um teste com respostas simuladas.

## Prompt para o ChatGPT com plugin Supabase

Projeto Quem Sou Eu V3 (`aruanmf446-hub/quemsoueuv3`), Godot 4.7.2 / Web-PWA.
GAME: `shuzporktifgiotvnpbz`; CHAT: `wurkpjgnbqklivjhcvxk`.
Inspecione as funções, tabelas, grants, constraints e RLS realmente implantados
antes de propor/aplicar mudanças. Preserve os contratos já usados pelo jogo.
Não substitua projetos, autenticação, contas, inventário, economia, música ou progresso.
Não coloque service_role no cliente nem crie contas paralelas no CHAT.

### 1. Nickname inicial obrigatório, único e definitivo (prioridade)

- Contas novas precisam escolher nickname próprio; nunca preencher o perfil
  automaticamente com `Jogador local`, `Sem nickname` ou metadados OAuth.
  Convidado sem conta continua jogando localmente e não precisa reservar nome global.
- Usar `qse_v3.player_profiles.nickname`, identidade por `auth.uid()` e RPCs
  existentes `qse_profile_self` / `qse_profile_update(p_nickname text)`.
- Validar 3–24 caracteres após trim; rejeitar controles e caracteres invisíveis
  (cliente rejeita U+0000–001F, 007F, 200B–200F, 202A–202E, 2066–2069, FEFF),
  vazios e nomes reservados `Jogador local`, `Sem nickname`, `Você`, `<null>` e `null`.
- Definir uma chave canônica consistente com trim e comparação sem diferença
  de caixa; `Lucas`, `lucas` e ` Lucas ` não podem pertencer a contas diferentes.
  Documentar a normalização Unicode. Preservar a grafia de exibição escolhida.
- Garantir a unicidade atomicamente no PostgreSQL, com constraint/índice único
  ou mecanismo equivalente que suporte concorrência. Não usar somente SELECT
  de disponibilidade seguido de UPDATE sem proteção transacional.
- A primeira atribuição deve ser transacional. Depois disso, impedir mudanças
  por RPC, REST direto e alterações de metadata/provedor. Repetição idempotente
  da mesma atribuição deve devolver o perfil já gravado, sem renomeá-lo.
- Auditar nulos, placeholders e duplicados existentes. Apresentar tratamento
  dos conflitos legados antes de aplicar a restrição; não apagar contas,
  progresso, inventário nem escolher nomes aleatórios para resolver colisões.
- Para perfis próprios ainda não configurados, devolver `nickname: null`, sem
  coalesce para placeholder que pareça um nickname válido. Não listar perfis
  sem nickname nas buscas públicas nem permitir sua entrada em salas online.
  RPCs de sala/partida devem devolver `nickname_required` quando necessário.
- Preservar a resposta de `qse_profile_self` e da atualização com os 8 campos:
  `user_id`, `public_id`, `nickname`, `equipped_character_id`, `level`,
  `experience` (string), `statistics` (objeto), `discoverable` (bool).
  Não adicionar campos a esse objeto sem combinar uma versão do contrato.
- Erros de negócio compatíveis com o cliente: HTTP 200 com
  `{"error":"nickname_taken","error_code":"nickname_taken"}` (ou `nickname_locked`,
  `nickname_required`, `invalid_nickname` nos dois campos). Se usar HTTP de erro,
  preencher o campo `code`/`error_code` correspondente. Não expor SQL interno.
- Testar duas contas disputando o mesmo nome simultaneamente; variantes de caixa
  e espaços; duas atribuições concorrentes na mesma conta; tentativa de troca;
  REST direto; reinício/restauração de sessão; login dos três provedores.
  Confirmar que cada teste usa contas isoladas e preserva jogadores reais.

### 2. Ordem única antes do Mata-Mata online

- O cliente local já sorteia uma vez e apresenta cada participante com a animação 2.
  O cliente online só apresenta a ordem fornecida pelo servidor; não inventa outra.
- Inspecionar `qse_duel_start`, `qse_v3.duel_advance`, `qse_duel_pick`, heartbeat
  e snapshots. Sortear e persistir `turn_order` uma única vez por partida,
  retornando-o já na seleção/contagem. Não sortear novamente ao iniciar os turnos.
- Reservar uma contagem suficiente para a apresentação (cliente local usa mínimo
  5 s e 1,8 s por participante + margem). Só então iniciar o relógio do primeiro turno.
- Reproduzir o relato de turnos pulados com humanos e bots. Inspecionar os locks
  existentes, idempotência e transições de pick/polling/heartbeat/timeout/desconexão.
  Não presumir ausência de lock: a migration do repositório já usa FOR UPDATE na sala.
- Manter a sequência circular, pulando apenas eliminados. Dois clientes devem
  receber a mesma ordem e observar uma única transição por ação/prazo.
  Preservar cartas secretas e o suspense anterior à revelação.

### 3. Chat compartilhado dos bots online

- Personalidades já existem no chat local. O cliente não envia mensagens fingindo
  ser um bot nas partidas online.
- Reutilizar o contrato atual do chat de sala e o gateway GAME→CHAT; verificar
  `qse_duel_chat_access` e `docs/backend/DUEL_ROOM_CHAT_API_V1.md` antes de alterar.
- Gerar mensagens identificadas como BOT no servidor, a partir de eventos públicos,
  com personalidade estável por bot, cooldown, limite de tamanho e deduplicação
  por partida/evento/bot. Não ler/expor cartas privadas para escrever mensagens.
- Todos os membros autorizados devem receber a mesma mensagem uma vez só.
  Um usuário comum não pode publicar sob a identidade de outro jogador/bot.
- Testar com dois clientes reais e reconexão, sem inserir mensagens de teste em
  salas reais de jogadores.

### 4. Backlog histórico: auditar, sem presumir que continua pendente

Os arquivos abaixo contêm pedidos antigos; o cliente e o backend podem ter
avançado depois deles. Identificar o que já existe antes de criar novos recursos:

- `docs/contracts/T21_DECKS.md`: publicação/listagem/moderação de decks, favoritos
  sincronizados, preferências de playlist e Storage. `CreatorSync` já existe no
  cliente; conferir tabelas/RPCs/bucket atuais, não criar uma implementação paralela.
- `docs/contracts/T22_AMIZADES.md`: mensagem/data do convite de amizade, amigos em
  comum, convites de partida direcionados, presença/último visto, partidas recentes,
  sugestões e estatísticas entre amigos. Geração e envio de links já existem.
- Mesmo documento: MFA/TOTP é pedido histórico; não ativar exigência global nem
  alterar login dos jogadores como efeito colateral desta entrega.

Retorne: alterações realmente aplicadas, contratos mantidos, testes executados,
resultados de concorrência e o que ainda falta. Se uma pendência histórica já
estiver resolvida, registre a evidência e não a implemente de novo.
