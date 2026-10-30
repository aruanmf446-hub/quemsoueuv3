# T16D — Chat de voz: avaliação, sem implementação

**Decisão:** **NÃO implementar voz agora.** Texto é prioridade, e o painel `Chat de voz: indisponível` deve continuar indicando indisponibilidade real.

## Opções para uma etapa posterior

**1. WebRTC P2P (mesh):** para teste com 2 participantes pode evitar servidor de mídia; requer signaling, ICE, STUN e, em redes restritas, TURN para retransmissão. Em grupos, cada participante envia vários fluxos, elevando uso de banda e bateria. **Não é adequado presumir P2P gratuito/estável em todas as redes móveis.**

**2. WebRTC com SFU (ex.: LiveKit open source):** um servidor encaminha áudio aos integrantes, geralmente mais adequado a múltiplos jogadores e espectadores do que mesh. Código do servidor pode ser livre, porém execução, tráfego, TURN, observabilidade e disponibilidade exigem infraestrutura e custos operacionais. Suporta implantações próprias. Alternativa é serviço gerenciado com franquia/limites.

**3. Supabase Realtime:** útil para sinalização, autorização e eventos de presença, **não** substitui transporte de mídia RTP/WebRTC. Limites de conexões, mensagens e operações podem impactar custo; não transmitir áudio bruto por mensagens Postgres/Realtime.

## Recomendação
Manter **texto via CHAT Supabase** com retenção de 24 horas. Quando houver demanda real por voz, experimentar **WebRTC P2P para duas pessoas** num protótipo isolado e **SFU para salas multiplayer**. Antes de implantar, medir minutos de áudio, concorrência, banda e acessibilidade no APK Android e na Web, além de definir quem paga a infraestrutura. Não contratar assinatura, não instalar TURN/SFU e não vincular o áudio às Edge Functions do CHAT nesta etapa.

Fontes consultadas em 30/10/2026:
- https://docs.livekit.io/reference/internals/livekit-sfu/
- https://docs.livekit.io/transport/self-hosting/
- https://livekit.com/pricing
- https://supabase.com/docs/guides/realtime/pricing
- https://supabase.com/docs/guides/realtime/limits

**Estado:** somente análise técnica. Não existe chat de voz implementado ou testado.
