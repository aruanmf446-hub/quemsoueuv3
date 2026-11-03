/* T32 — Browser-only bridge for Godot 4.7.2 JavaScriptBridge.
 * Voice starts ONLY on player action. Neither token nor mic audio is persisted.
 * LiveKit SDK is pinned to a version; only downloaded when voice is requested.
 */
(() => {
  "use strict";
  if (window.QSEVoice) return;
  const SDK_URL = "https://cdn.jsdelivr.net/npm/livekit-client@2.23.0/dist/livekit-client.umd.min.js";
  let sdkPromise = null;
  let room = null;
  let generation = 0;
  let roster = new Map();
  const audioElements = new Set();
  const volumes = new Map();
  const state = { status: "off", connected: false, mic: false, audioMuted: false, error: "" };

  function loadSDK() {
    if (window.LivekitClient) return Promise.resolve(window.LivekitClient);
    if (sdkPromise) return sdkPromise;
    sdkPromise = new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = SDK_URL;
      script.crossOrigin = "anonymous";
      script.onload = () => window.LivekitClient
        ? resolve(window.LivekitClient) : reject(new Error("sdk_unavailable"));
      script.onerror = () => reject(new Error("sdk_load_failed"));
      document.head.appendChild(script);
    }).catch((error) => { sdkPromise = null; throw error; });
    return sdkPromise;
  }

  function clearAudio() {
    for (const element of audioElements) {
      try { element.pause(); element.srcObject = null; element.remove(); } catch { /* ignore */ }
    }
    audioElements.clear();
  }

  function detachTrack(track) {
    if (!track || typeof track.detach !== "function") return;
    for (const element of track.detach()) {
      audioElements.delete(element);
      element.remove();
    }
  }

  function attachTrack(track, participant) {
    if (!track || track.kind !== "audio") return;
    const element = track.attach();
    element.autoplay = true;
    element.playsInline = true;
    element.muted = state.audioMuted;
    element.dataset.qseVoice = "1";
    element.dataset.participant = participant?.identity || "";
    element.style.display = "none";
    document.body.appendChild(element);
    audioElements.add(element);
    if (participant && volumes.has(participant.identity)) {
      participant.setVolume(volumes.get(participant.identity));
    }
  }

  async function leave() {
    generation++;
    const oldRoom = room;
    room = null;
    clearAudio();
    state.status = "off";
    state.connected = false;
    state.mic = false;
    state.audioMuted = false;
    state.error = "";
    roster.clear();
    volumes.clear();
    if (oldRoom) {
      try { await oldRoom.disconnect(); } catch { /* already disconnected */ }
    }
  }

  function setRoster(members) {
    if (!Array.isArray(members)) return;
    roster = new Map(members
      .filter((member) => member && typeof member.tag === "string")
      .map((member) => [member.tag, String(member.nickname || "").slice(0, 80)]));
  }

  async function join(url, token, members = []) {
    await leave();
    const operation = ++generation;
    state.status = "connecting";
    state.error = "";
    setRoster(members);
    let nextRoom = null;
    try {
      if (typeof url !== "string" || !url.startsWith("wss://") ||
          typeof token !== "string" || token.length < 20) {
        throw new Error("invalid_join");
      }
      const sdk = await loadSDK();
      if (operation !== generation) return;
      nextRoom = new sdk.Room({ adaptiveStream: true, dynacast: false });
      const localRoom = nextRoom;
      localRoom.on(sdk.RoomEvent.TrackSubscribed, (track, _pub, participant) => {
        if (room === localRoom) attachTrack(track, participant);
      });
      localRoom.on(sdk.RoomEvent.TrackUnsubscribed, (track) => detachTrack(track));
      localRoom.on(sdk.RoomEvent.Reconnecting, () => {
        if (room === localRoom) state.status = "reconnecting";
      });
      localRoom.on(sdk.RoomEvent.Reconnected, () => {
        if (room === localRoom) state.status = "connected";
      });
      localRoom.on(sdk.RoomEvent.Disconnected, () => {
        if (room === localRoom) {
          state.status = "error";
          state.connected = false;
          state.mic = false;
          state.error = "connection_lost";
          clearAudio();
        }
      });
      room = localRoom;
      await localRoom.connect(url, token, { autoSubscribe: true });
      if (operation !== generation) {
        await localRoom.disconnect();
        return;
      }
      state.connected = true;
      state.status = "connected";
      state.mic = false; // no automatic getUserMedia; permission only by button
      // Autoplay may be blocked since the token request was asynchronous.
      // The visible "Liberar áudio" button retries in a real user gesture.
      try { await localRoom.startAudio(); } catch { /* needs gesture */ }
    } catch {
      if (nextRoom) {
        try { await nextRoom.disconnect(); } catch { /* ignore */ }
      }
      if (operation === generation) {
        room = null;
        clearAudio();
        state.connected = false;
        state.status = "error";
        state.error = "voice_connect_failed";
      }
    }
  }

  async function setMic(enabled) {
    if (!room || !state.connected) return;
    try {
      await room.localParticipant.setMicrophoneEnabled(!!enabled);
      state.mic = !!enabled;
      state.error = "";
    } catch {
      state.mic = false;
      state.error = "microphone_denied";
    }
  }

  function setAudioMuted(muted) {
    state.audioMuted = !!muted;
    for (const element of audioElements) element.muted = state.audioMuted;
  }

  async function unlockAudio() {
    if (!room) return;
    try {
      await room.startAudio();
      for (const element of audioElements) {
        try { await element.play(); } catch { /* blocked by browser policy */ }
      }
      state.error = "";
    } catch {
      state.error = "audio_permission_required";
    }
  }

  function setPlayerVolume(identity, value) {
    if (typeof identity !== "string" || !/^[a-f0-9]{64}$/.test(identity)) return;
    const volume = Math.max(0, Math.min(1, Number(value) || 0));
    volumes.set(identity, volume);
    const player = room?.remoteParticipants.get(identity);
    if (player) player.setVolume(volume);
  }

  function snapshot() {
    const participants = room && state.connected
      ? Array.from(room.remoteParticipants.values()).map((participant) => ({
          id: participant.identity,
          name: roster.get(participant.identity) || "",
          speaking: !!participant.isSpeaking,
          volume: volumes.get(participant.identity) ?? 1,
        }))
      : [];
    return { ...state, participants };
  }

  window.QSEVoice = Object.freeze({
    join, leave, setMic, setAudioMuted, unlockAudio, setPlayerVolume, setRoster, snapshot,
  });
})();
