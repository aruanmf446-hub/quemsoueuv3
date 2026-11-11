// T32: JS bridge contract with a fake LiveKit SDK (no server, microphone or secrets).
const fs = require("node:fs");
const vm = require("node:vm");
const assert = require("node:assert/strict");
let autoplayBlocked = false;
let connectFailure = null;
let lastRoom;
class FakeRoom {
  constructor() {
    lastRoom = this;
    this.listeners = new Map();
    this.remoteParticipants = new Map();
    this.localParticipant = { setMicrophoneEnabled: async (value) => { this.mic = value; } };
    this.mic = false;
  }
  on(event, fn) { this.listeners.set(event, fn); return this; }
  async connect() {
    if (connectFailure) throw connectFailure;
    this.connected = true;
  }
  async disconnect() { this.connected = false; }
  async startAudio() {
    if (autoplayBlocked) throw new Error("autoplay denied");
    this.audioStarted = true;
  }
}
const window = {
  LivekitClient: {
    Room: FakeRoom,
    ConnectionErrorReason: { NotAllowed: 0, WebSocket: 6 },
    DisconnectReason: { DUPLICATE_IDENTITY: 2 },
    RoomEvent: {
      TrackSubscribed: "trackSubscribed",
      TrackUnsubscribed: "trackUnsubscribed",
      Reconnecting: "reconnecting",
      Reconnected: "reconnected",
      Disconnected: "disconnected",
      AudioPlaybackStatusChanged: "audioPlaybackStatusChanged",
    },
  },
};
const document = { head: { appendChild() {} }, body: { appendChild() {} } };
vm.runInNewContext(fs.readFileSync("web/voice/bridge.js", "utf8"), { window, document, console });
async function run() {
  const bridge = window.QSEVoice;
  assert.ok(bridge, "bridge installed");
  assert.equal(bridge.snapshot().status, "off");
  assert.equal(bridge.snapshot().mic, false);
  const identity = "a".repeat(64);
  await bridge.join("wss://example.livekit.cloud", "t".repeat(80),
    [{ tag: identity, nickname: "Jogador 2" }]);
  assert.equal(bridge.snapshot().connected, true);
  assert.equal(bridge.snapshot().mic, false, "no implicit microphone consent");
  await bridge.setMic(true);
  assert.equal(bridge.snapshot().mic, true);
  await bridge.setMatchAccess(true, []);
  assert.equal(bridge.snapshot().mic, false, "elimination mutes an open microphone");
  await bridge.setMic(true);
  assert.equal(bridge.snapshot().mic, false, "spectator cannot unmute");
  await bridge.leave();
  await bridge.join("wss://example.livekit.cloud", "t".repeat(80));
  await bridge.setMic(true);
  assert.equal(bridge.snapshot().mic, false, "reconnecting preserves spectator lock");
  bridge.setMatchAccess(false, []);
  await bridge.setMic(true);
  assert.equal(bridge.snapshot().mic, true, "lobby restores microphone control");
  bridge.setAudioMuted(true);
  assert.equal(bridge.snapshot().audioMuted, true);
  await bridge.leave();
  assert.equal(bridge.snapshot().connected, false);
  assert.equal(bridge.snapshot().mic, false);
  connectFailure = new Error("connection rejected");
  await bridge.join("wss://example.livekit.cloud", "t".repeat(80));
  assert.equal(bridge.snapshot().error, "voice_connect_failed");
  connectFailure = { reason: 0 };
  await bridge.join("wss://example.livekit.cloud", "t".repeat(80));
  assert.equal(bridge.snapshot().error, "livekit_token_rejected");
  connectFailure = { reason: 6 };
  await bridge.join("wss://example.livekit.cloud", "t".repeat(80));
  assert.equal(bridge.snapshot().error, "livekit_signal_unreachable");
  connectFailure = null;
  autoplayBlocked = true;
  await bridge.join("wss://example.livekit.cloud", "t".repeat(80));
  assert.equal(bridge.snapshot().connected, true, "retry connects");
  assert.equal(bridge.snapshot().audioBlocked, true, "autoplay failure is surfaced");
  autoplayBlocked = false;
  await bridge.unlockAudio();
  assert.equal(bridge.snapshot().audioBlocked, false, "gesture unlocks audio");
  lastRoom.listeners.get("disconnected")(2);
  assert.equal(bridge.snapshot().error, "livekit_duplicate_identity");
  console.log("PASS T32 Web LiveKit bridge contract");
}
run().catch((error) => { console.error(error); process.exitCode = 1; });
