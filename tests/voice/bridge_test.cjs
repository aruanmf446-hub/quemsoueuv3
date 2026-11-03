// T32: JS bridge contract with a fake LiveKit SDK (no server, microphone or secrets).
const fs = require("node:fs");
const vm = require("node:vm");
const assert = require("node:assert/strict");
class FakeRoom {
  constructor() {
    this.listeners = new Map();
    this.remoteParticipants = new Map();
    this.localParticipant = { setMicrophoneEnabled: async (value) => { this.mic = value; } };
    this.mic = false;
  }
  on(event, fn) { this.listeners.set(event, fn); return this; }
  async connect() { this.connected = true; }
  async disconnect() { this.connected = false; }
  async startAudio() { this.audioStarted = true; }
}
const window = {
  LivekitClient: {
    Room: FakeRoom,
    RoomEvent: {
      TrackSubscribed: "trackSubscribed",
      TrackUnsubscribed: "trackUnsubscribed",
      Reconnecting: "reconnecting",
      Reconnected: "reconnected",
      Disconnected: "disconnected",
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
  bridge.setAudioMuted(true);
  assert.equal(bridge.snapshot().audioMuted, true);
  await bridge.leave();
  assert.equal(bridge.snapshot().connected, false);
  assert.equal(bridge.snapshot().mic, false);
  console.log("PASS T32 Web LiveKit bridge contract");
}
run().catch((error) => { console.error(error); process.exitCode = 1; });
