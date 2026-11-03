import { Room, RoomEvent, Track } from "livekit-client";

// Bundled by GitHub Actions. No API credentials or auth tokens are embedded here.
(() => {
  let room = null;
  let generation = 0;
  const state = { status: "idle", mic: false, muted: false, error: "", participants: [], audioBlocked: false };
  const audioRoot = document.createElement("div");
  audioRoot.id = "qse-voice-audio";
  audioRoot.style.display = "none";
  document.body.appendChild(audioRoot);
  const playbackButton = document.createElement("button");
  playbackButton.textContent = "ATIVAR ÁUDIO DA SALA";
  playbackButton.type = "button";
  playbackButton.setAttribute("aria-label", "Ativar som dos outros jogadores");
  Object.assign(playbackButton.style, {
    display: "none", position: "fixed", zIndex: "90", bottom: "12px",
    right: "12px", border: "1px solid #dfbd77", background: "#172438",
    color: "#fff2ca", padding: "10px 16px", borderRadius: "10px", font: "600 13px system-ui",
  });
  playbackButton.onclick = async () => {
    if (!room) return;
    try { await room.startAudio(); state.audioBlocked = false; playbackButton.style.display = "none"; }
    catch { state.audioBlocked = true; }
  };
  document.body.appendChild(playbackButton);

  const update = () => {
    state.participants = room
      ? [...room.remoteParticipants.values()].map(p => ({
          id: p.identity,
          speaking: !!p.isSpeaking,
          mic: !!p.isMicrophoneEnabled,
        }))
      : [];
    if (room) {
      state.mic = !!room.localParticipant.isMicrophoneEnabled;
      state.audioBlocked = !room.canPlaybackAudio;
      playbackButton.style.display = state.audioBlocked ? "block" : "none";
    }
  };
  const disconnect = async () => {
    generation++;
    const old = room;
    room = null;
    if (old) await old.disconnect(true);
    audioRoot.replaceChildren();
    playbackButton.style.display = "none";
    Object.assign(state, { status: "idle", mic: false, muted: false, error: "", participants: [], audioBlocked: false });
  };

  window.QSEVoice = {
    status: () => ({ ...state, participants: state.participants.map(p => ({ ...p })) }),
    async connect(url, token) {
      await disconnect();
      const myGeneration = generation;
      if (typeof url !== "string" || !url.startsWith("wss://") || typeof token !== "string") {
        state.error = "invalid_connection"; state.status = "error"; return;
      }
      state.status = "connecting";
      const current = new Room({ adaptiveStream: false, dynacast: false });
      room = current;
      current.on(RoomEvent.TrackSubscribed, (track) => {
        if (track.kind === Track.Kind.Audio) {
          const element = track.attach();
          element.autoplay = true;
          audioRoot.appendChild(element);
          if (state.muted) element.muted = true;
        }
        update();
      });
      current.on(RoomEvent.TrackUnsubscribed, (track) => { track.detach().forEach(el => el.remove()); update(); });
      current.on(RoomEvent.ParticipantConnected, update);
      current.on(RoomEvent.ParticipantDisconnected, update);
      current.on(RoomEvent.ActiveSpeakersChanged, update);
      current.on(RoomEvent.TrackMuted, update);
      current.on(RoomEvent.TrackUnmuted, update);
      current.on(RoomEvent.AudioPlaybackStatusChanged, update);
      current.on(RoomEvent.Reconnecting, () => { state.status = "reconnecting"; update(); });
      current.on(RoomEvent.Reconnected, () => { state.status = "connected"; update(); });
      current.on(RoomEvent.Disconnected, () => {
        if (room === current) { state.status = "disconnected"; state.mic = false; update(); }
      });
      try {
        await current.connect(url, token, { autoSubscribe: true });
        if (myGeneration !== generation) { await current.disconnect(true); return; }
        state.status = "connected"; state.mic = false;
        update();
      } catch (error) {
        if (myGeneration !== generation) return;
        state.status = "error";
        state.error = error?.name === "ConnectionError" ? "connection_failed" : "voice_unavailable";
        await current.disconnect(true);
        room = null;
      }
    },
    disconnect,
    async microphone(enabled) {
      if (!room || state.status !== "connected") return;
      try {
        await room.localParticipant.setMicrophoneEnabled(!!enabled);
        state.error = "";
      } catch (error) {
        state.error = error?.name === "NotAllowedError" ? "microphone_denied" : "microphone_unavailable";
      }
      update();
    },
    muteReceived(muted) {
      state.muted = !!muted;
      audioRoot.querySelectorAll("audio").forEach(el => { el.muted = state.muted; });
    },
    volume(identity, volume) {
      if (!room) return;
      const participant = room.remoteParticipants.get(identity);
      if (participant) participant.setVolume(Math.max(0, Math.min(1, Number(volume) || 0)));
    },
  };
})();
