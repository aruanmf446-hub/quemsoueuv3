# T32 — LiveKit Cloud / chat de voz do Mata-Mata

## Estado atual

- **Web/PWA:** implementação inicial com cliente LiveKit JS, controles de voz no lobby e batalha, microfone desligado por padrão. Falta validar com duas contas e dois microfones reais.
- **Android APK e Windows EXE:** integração nativa ainda não implementada; não declarar funcional nessas plataformas sem plugin/SDK/GDExtension compatível com Godot 4.7.2 e testes.
- **Partida local:** não conecta ao LiveKit.
- **Supabase CHAT:** preservado; não transmite áudio bruto nem armazena gravações.

## Backend seguro

Projeto GAME: shuzporktifgiotvnpbz, Edge Function: qse-voice-token (verify_jwt=true).

Secrets privados esperados no Supabase GAME:
LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET.
Nunca enviar os valores para GitHub, arquivos Godot, frontend ou logs.

POST /functions/v1/qse-voice-token com JWT Supabase GAME e apikey publicável:

- action=join + room_id UUID -> server_url, participant_token, room, participants, expires_in
- action=leave + room_id UUID -> remoção/revogação da própria identidade, mesmo após sair da sala
- action=reconcile + room_id UUID -> reconcilia participantes LiveKit com GAME e remove não autorizados

Cada sala é qse-v3-<uuid-da-sala-game>. Identidade LiveKit é tag SHA-256 pseudônima de sala + user UUID, compatível com RPC qse_duel_chat_access. Somente essa RPC autoriza entrada em salas lobby/in_match para jogadores e espectadores não expulsos.

Token com TTL 2 minutos; só permite microfone e ouvir, sem publicação de vídeo, dados ou privilégios administrativos.
A expiração do token não desconecta alguém que já está conectado: a remoção ativa é realizada por removeParticipant.

O reconcile é disparado por membros conectados a cada 30 segundos e antecipado por mudanças de sala (~3 segundos). **Não é uma garantia de revogação instantânea**: por depender dos clientes conectados há uma janela até o próximo reconcile. Para kick síncrono mesmo quando nenhum outro cliente estiver ativo, será preciso evento autoritativo servidor→LiveKit. Ainda requer testes de integração com expulsões reais.

## Web/PWA

O pipeline deploy-web.yml copia web/voice/bridge.js ao build e injeta seu script no index.html antes de registrar o cache PWA. SDK UMD fixado na versão 2.23.0, carregado apenas após interação do usuário, de cdn.jsdelivr.net.

HTTPS e permissão de microfone são exigidos; se o navegador bloquear autoplay, clicar em Liberar áudio. Não usar câmera, IA, gravação ou transcrição.

Godot VoiceService via PlayerServices usa o SupabaseClient da sessão GAME. Conecta somente após o botão Entrar. Controles do battle_voice.gd: entrar/sair, ativar mic, som, liberar áudio, silenciar/ouvir participantes. O lobby e o Mata-Mata compartilham a conexão sem reiniciar durante a transição.

## Testes

Offline/CI: node tests/voice/bridge_test.cjs e Godot headless tests/voice/flow_test.gd. Esses testes não afirmam que existe uma conversa real funcionando.

Checklist manual pendente: 2 contas na mesma sala, 1 conta em outra sala, permissão negada, reprodução automática bloqueada, isolamento, expulsão, saída, reconexão, PWA iPhone, verificação de franquia do LiveKit Build, Android e Windows (quando existirem clientes nativos).

O endpoint responderá 503 voice_unavailable quando o LiveKit não estiver configurado corretamente. Não afirmar conclusão geral sem esses testes.

## Correção do token — 11/11/2026

`qse-voice-token` passava `canPublishSources: ["microphone"]` (texto). O
`livekit-server-sdk@2.19.2` espera o enum `TrackSource` e, ao assinar, lança
`TypeError: Cannot convert TrackSource microphone to string`: todo `join` falhava
antes de existir token. Reproduzido com o SDK real; corrigido para
`[TrackSource.MICROPHONE]` (o JWT continua com `"canPublishSources":["microphone"]`).
A assinatura agora responde `503 voice_unavailable` com log `TOKEN_SIGN_FAILED`
em vez de erro não tratado. **A função precisa ser publicada manualmente** no
projeto GAME; o merge no GitHub não a publica.

### Atualização — mesmo dia

O código publicado no Supabase já usava `TrackSource.MICROPHONE` e `can_speak`
(editado pelo painel). O arquivo do repositório foi alinhado a essa versão, com a
proteção extra na assinatura. Os logs mostram a função respondendo 200: a recusa
acontece na conexão com o LiveKit. `web/voice/bridge.js` passa a registrar no console
o motivo informado pelo SDK (`[QSEVoice] connect failed: ...`), sem token nem IDs.
