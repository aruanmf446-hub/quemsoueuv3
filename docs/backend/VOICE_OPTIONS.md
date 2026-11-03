# T32 — LiveKit voice chat: implementação inicial (Web/PWA)

**Estado em 03/11/2026:** código integrado na branch `work/livekit-voice-t32`; backend GAME implantado; testes reais de áudio entre dois aparelhos **não realizados**. Android APK e Windows EXE ainda não têm ponte nativa de voz e exibem aviso informativo. Não anunciar voz multiplataforma.

## Arquitetura
- GAME `shuzporktifgiotvnpbz`: Edge Function `qse-voice-token` **versão 5, ativa** (fonte: `supabase/game/functions/qse-voice-token/index.ts`). Exige JWT de usuário do GAME.
- Verificação de sala via RPC existente `qse_duel_chat_access(p_room)` (status lobby/in_match; usuário membro não expulso). Não confia em IDs/cargos do cliente.
- Uma sala LiveKit por UUID: `qse-voice-<uuid>`; `identity` = SHA-256 da etiqueta `qse-room-member-v1:<uuid>:<user-id>`. Sem IDs de conta públicos na sala.
- Tokens de **2 minutos**, permissão apenas microfone e subscribe. O cliente nunca recebe API secret.
- LiveKit Cloud Build é gerenciado, portanto não instala SFU próprio e não transmite áudio via Supabase.
- Um cliente de voz opt-in em `VoiceService` faz `POST /functions/v1/qse-voice-token` com sessão GAME; conecta via `web/voice/livekit_adapter.js`.
- O bundle JavaScript entra na exportação Web via `.github/workflows/deploy-web.yml` (livekit-client 2.15.6, esbuild 0.25.12); serviço PWA apenas cacheia arquivos da própria origem.
- Microfone começa desligado; áudio remoto pode exigir gesto de usuário. Um botão HTML próprio aparece se o navegador bloquear autoplay.
- O voice chat é independente do chat de texto do projeto CHAT. Nenhum token é salvo em disco.

## Segurança e limitações
- `action=sync` permite que usuários *atualmente autorizados* conciliem os participantes da sala LiveKit e removam participantes que já saíram/foram expulsos. O cliente ativo solicita reconciliação aproximadamente a cada 20 segundos e antecipa a verificação após mudanças relevantes da sala, limitado a uma verificação a cada 10 segundos.
- `action=disconnect` permite revogar a própria conexão ao sair.
- **Limitação conhecida:** em um encerramento com todos os jogadores offline, pode não haver cliente autorizado para solicitar `sync`. Antes de declarar expulsão/fechamento com revogação garantida em produção, integrar webhook confiável ou ação privilegiada do backend em mudanças de sala. Token curto não encerra conexões WebRTC existentes.
- Os controles de voz estão disponíveis somente no Web/PWA; APK e EXE permanecem sem voz.
- Silenciamento por participante e nickname fornecido pela RPC GAME foram integrados para até três participantes simultaneamente visíveis no painel compacto. Faltam a navegação da lista completa de 20, validação visual em dispositivos reais e controles finos de volume.
- O modo local não usa LiveKit.
- LiveKit Cloud tem limites de uso gratuitos; verificar limites vigentes no painel. A conexão só começa por ação do jogador.

## Configuração da função
Definir em GAME → Edge Functions → Secrets: `LIVEKIT_URL` (wss://...livekit.cloud), `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`. Nunca colocar segredo no GitHub ou Godot. A função mantém `verify_jwt=true`.

Payload (sessão GAME enviada em `Authorization: Bearer ...` e chave pública GAME em `apikey`):
```json
{"room_id":"<uuid-da-sala>","action":"token"}
```
Também aceita `action: "sync"` e `action: "disconnect"`; todos exigem JWT autenticado.
Responderá `server_url`, `room`, `participant_token` e lista de nicknames/tags pseudônimos somente em solicitação de token autorizada. A ação `sync` devolve o roster atualizado; não devolve token.

## Testes de aceite ainda necessários
1. Duas contas reais em navegadores Web/PWA e microfones, confirmar áudio bidirecional e isolamento entre salas.
2. Tentar token sem JWT, com JWT inválido, com usuário fora da sala e depois de expulsão.
3. Forçar revogação pelo segundo participante via `sync` e confirmar ausência de áudio.
4. Testar Safari/iPhone PWA com permissão de microfone e gesto de reprodução.
5. Testar expiração/reconexão, fechamento, rede perdida, logout/troca de conta, sem afetar chat de texto e cartas.
6. Testar orçamento Build com 10 e 20 participantes; monitorar custo.

**Não fazer merge automático.** CI headless testa importação/GDScript, não valida transmissão de voz de verdade.

## T32 — E2E real de autenticação e WebRTC (contas de teste)

O repositório já possui seis GitHub Actions Secrets (OWNER, READER e R1) usados pela CI de Comunidade. **Não copiar seus valores para arquivos, logs ou Supabase**. O teste de voz usa os nomes dos Secrets diretamente nas Actions e limpa as salas temporárias ao final.

- Script seguro: `tools/e2e/voice_livekit_e2e.py`: login das três contas no GAME, sala privada, autorização de participantes, bloqueio de não membros, dois `room_id` isolados, JWTs LiveKit somente microfone, `sync`, revogação após saída e limpeza de sala.
- Navegador: `tools/e2e/voice_browser_e2e.cjs`: dois contextos Chrome independentes, **microfone sintético** (sem gravação) e verificação de publicação/assinatura das trilhas WebRTC.
- CI: `.github/workflows/voice-live-e2e.yml` restringe a execução à branch `work/livekit-voice-t32` do próprio repositório (sem forks).
- Execução manual também disponível no workflow existente `Comunidade E2E (contas de teste)`: **Run workflow → Branch `work/livekit-voice-t32` → stage `voice`** (deixar `deck_id` vazio). Uma execução consome poucos minutos de participante do LiveKit Cloud Build.

**Estado:** os testes acima foram implementados e estão prontos para disparo; não declarar que foram executados ou que áudio real foi validado antes de ler o resultado do GitHub Actions. Um teste de Chrome com microfone sintético não substitui validação de aparelhos reais.
