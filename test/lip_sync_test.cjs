const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const modulePath = path.join(__dirname, '../assets/web/js/lip-sync.js');
const implementationExists = fs.existsSync(modulePath);
const lipSync = implementationExists ? require(modulePath) : {};
const names = ['aa', 'ih', 'oh', 'ou', 'ee'];
const total = weights => names.reduce((sum, key) => sum + weights[key], 0);
const pcm = rms => Float32Array.from({ length: 1024 }, (_, i) => (i % 2 ? -rms : rms));
function spectrum(frequency = 1400) {
  const data = new Float32Array(512).fill(-Infinity);
  data[Math.round(frequency / (48000 / 1024))] = -20;
  return data;
}
function advance(driver, rms, seconds = 0.5, fps = 60, frequency = 1400) {
  let weights;
  for (let i = 0; i < Math.round(seconds * fps); i++) {
    weights = driver.update(pcm(rms), spectrum(frequency), 48000, 1 / fps);
  }
  return { ...weights };
}

test('lip sync engine is available to both the viewer and regression tests', () => {
  assert.equal(typeof lipSync.createDriver, 'function');
});

function playbackHarness({ failPlay = false, failResume = false, playGate } = {}) {
  const html = fs.readFileSync(path.join(__dirname, '../assets/web/vrm_viewer.html'), 'utf8');
  const section = html.slice(html.indexOf('<!-- LIP-SYNC SYSTEM'));
  const code = section.match(/<script>([\s\S]*?)<\/script>/)[1];
  const intervals = [];
  const media = [];
  const nodes = [];
  const applied = {};
  const events = [];
  const analyser = {
    fftSize: 1024, frequencyBinCount: 512, disconnect() {}, connect() {},
    getFloatTimeDomainData(data) { data.set(pcm(0.1)); },
    getFloatFrequencyData(data) { data.set(spectrum()); },
  };
  class Audio {
    constructor() { this.paused = true; this.ended = false; this.readyState = 4; media.push(this); }
    async play() {
      if (failPlay) throw new Error('playback rejected');
      if (playGate) await playGate;
      this.paused = false;
    }
    pause() { this.paused = true; }
  }
  class AudioContext {
    constructor() { this.state = 'suspended'; this.sampleRate = 48000; this.destination = {}; }
    async resume() { if (failResume) throw new Error('resume rejected'); this.state = 'running'; }
    createAnalyser() { return analyser; }
    createMediaElementSource() {
      const node = { disconnected: false, connect() {}, disconnect() { this.disconnected = true; } };
      nodes.push(node);
      return node;
    }
  }
  const context = {
    Audio, AudioContext, Float32Array, Uint8Array, Math, console: { warn() {} },
    LipSync: lipSync,
    chrome: {webview: {postMessage(message) { events.push(message); }}},
    currentVrm: { expressionManager: { setValue(key, value) { applied[key] = value; } } },
    refreshExpressionWeights() {},
    setInterval(callback, ms) { intervals.push({ callback, ms }); return intervals.length; },
    clearInterval() {},
  };
  context.window = context;
  vm.runInNewContext(code, context);
  return {
    context, media, nodes, applied, intervals, events,
    async play(name = 'test.wav') {
      context.__pendingAudioUrl = name;
      intervals.find(item => item.ms === 100).callback();
      await new Promise(resolve => setImmediate(resolve));
    },
  };
}

test('viewer exposes a frame-driven mouth update instead of a mouth timer', () => {
  const h = playbackHarness();
  assert.equal(typeof h.context.updateLipSync, 'function');
  assert.ok(h.intervals.every(item => item.ms === 100));
});

test('playback failure leaves no speaking state or connected source', async () => {
  const h = playbackHarness({ failPlay: true });
  await h.play();
  assert.equal(h.context._isLipSyncPlaying, false);
  assert.ok(h.nodes.every(node => node.disconnected));
  assert.equal(total(h.applied), 0);
});

test('audio context failure stops playback and closes the mouth', async () => {
  const h = playbackHarness({ failResume: true });
  await h.play();
  assert.equal(h.context._isLipSyncPlaying, false);
  assert.equal(total(h.applied), 0);
});

test('interruption disconnects the old source and ignores stale completion', async () => {
  const h = playbackHarness();
  await h.play();
  const oldEnd = h.media[0].onended;
  await h.play('next.wav');
  assert.equal(h.media.length, 2);
  assert.ok(h.nodes[0].disconnected);
  if (oldEnd) oldEnd();
  assert.equal(h.context._isLipSyncPlaying, true);
  h.context.updateLipSync(1 / 60);
  assert.ok(total(h.applied) > 0);
  h.context.stopCurrentAudio();
  assert.equal(total(h.applied), 0);
  assert.ok(h.nodes.every(node => node.disconnected));
});

test('audio end releases smoothly and then yields mouth control back to animation', async () => {
  const h = playbackHarness();
  await h.play();
  for (let i = 0; i < 20; i++) h.context.updateLipSync(1 / 60);
  const beforeEnd = total(h.applied);
  h.media[0].ended = true;
  h.media[0].onended();
  h.context.updateLipSync(1 / 60);
  assert.ok(total(h.applied) > 0 && total(h.applied) < beforeEnd);
  for (let i = 0; i < 40; i++) h.context.updateLipSync(1 / 60);
  assert.equal(total(h.applied), 0);
  h.applied.aa = 0.3;
  h.context.updateLipSync(1 / 60);
  assert.equal(h.applied.aa, 0.3);
});

// Keep the first red run focused on the missing engine, rather than import errors.
if (implementationExists) {
  test('digital silence and DC offset keep the mouth closed', () => {
    const driver = lipSync.createDriver();
    assert.equal(total(advance(driver, 0)), 0);
    const weights = driver.update(new Float32Array(1024).fill(0.1), spectrum(), 48000, 1 / 60);
    assert.equal(total(weights), 0);
  });

  test('identical speech produces identical motion without random jitter', () => {
    const a = lipSync.createDriver();
    const b = lipSync.createDriver();
    for (const rms of [0, 0.02, 0.08, 0.2, 0.01, 0]) {
      assert.deepEqual(advance(a, rms), advance(b, rms));
    }
  });

  test('normal speech opens the mouth, louder speech increases amplitude', () => {
    const quiet = total(advance(lipSync.createDriver(), 0.025));
    const loud = total(advance(lipSync.createDriver(), 0.12));
    assert.ok(quiet > 0.04);
    assert.ok(loud > quiet * 1.5);
  });

  test('hysteresis keeps quiet trailing speech active without triggering from noise', () => {
    const driver = lipSync.createDriver();
    assert.equal(total(advance(driver, 0.009)), 0);
    advance(driver, 0.08);
    assert.ok(total(advance(driver, 0.009)) > 0.01);
    const beforeGap = total(advance(driver, 0.08));
    const afterGap = total(advance(driver, 0, 1 / 60));
    assert.ok(afterGap > 0 && afterGap < beforeGap);
    assert.equal(total(advance(driver, 0, 0.5)), 0);
  });

  test('equivalent speech at 30, 60 and 120 fps has the same envelope', () => {
    const totals = [30, 60, 120].map(fps => total(advance(lipSync.createDriver(), 0.1, 0.1, fps)));
    assert.ok(Math.max(...totals) - Math.min(...totals) < 0.002);
  });

  test('fast changes never exceed the combined mouth budget or per-shape caps', () => {
    const driver = lipSync.createDriver({ maxWeight: 0.6, caps: { aa: 0.25 } });
    for (let frame = 0; frame < 300; frame++) {
      const weights = driver.update(pcm(0.9), spectrum(frame % 2 ? 400 : 3200), 48000, 1 / 60);
      assert.ok(total(weights) <= 0.600001);
      assert.ok(weights.aa <= 0.250001);
      for (const value of Object.values(weights)) assert.ok(Number.isFinite(value) && value >= 0);
    }
  });

  test('silence closes promptly and reset clears the previous utterance', () => {
    const driver = lipSync.createDriver();
    advance(driver, 0.1);
    assert.ok(total(advance(driver, 0, 0.2)) < 0.015);
    driver.reset();
    assert.equal(total(driver.weights), 0);
    assert.equal(total(advance(driver, 0)), 0);
  });

  test('tone colour changes the shape without changing the loudness budget', () => {
    const low = advance(lipSync.createDriver(), 0.1, 0.5, 60, 400);
    const high = advance(lipSync.createDriver(), 0.1, 0.5, 60, 3200);
    assert.ok(low.ou > high.ou);
    assert.ok(high.ih + high.ee > low.ih + low.ee);
    assert.ok(Math.abs(total(low) - total(high)) < 0.002);
  });
}


test('direct playback sends correlated start, end and error events to Flutter', async () => {
  const h=playbackHarness();
  h.context.playSpeech('unique.wav','one');
  await new Promise(resolve=>setImmediate(resolve));
  assert.deepEqual(h.events,['audio_started:one']);
  h.media[0].onended();
  assert.deepEqual(h.events,['audio_started:one','audio_ended:one']);
  const bad=playbackHarness({failPlay:true});
  bad.context.playSpeech('bad.wav','bad');
  await new Promise(resolve=>setImmediate(resolve));
  assert.ok(bad.events.includes('audio_error:bad:playback'));
  assert.ok(!bad.events.includes('audio_started:bad'));
});

test('cleanup of an older request cannot stop a newer request', async () => {
  const h=playbackHarness();
  h.context.playSpeech('one.wav','one');
  await new Promise(resolve=>setImmediate(resolve));
  h.context.playSpeech('two.wav','two');
  await new Promise(resolve=>setImmediate(resolve));
  h.context.stopAudioRequest('one');
  assert.equal(h.media[1].paused,false);
  assert.ok(h.events.includes('audio_stopped:one'));
  h.context.stopAudioRequest('two');
  assert.equal(h.media[1].paused,true);
});

test('reply reaction waits for actual playback and ignores interrupted starts', async () => {
  let release;
  const gate=new Promise(resolve=>{release=resolve;});
  const h=playbackHarness({playGate:gate}), reactions=[];
  h.context.startSpeechReaction=id=>reactions.push(id);
  h.context.playSpeech('one.wav','audio-1','reply-1');
  await new Promise(resolve=>setImmediate(resolve));
  assert.deepEqual(reactions,[]);
  release(); await new Promise(resolve=>setImmediate(resolve));
  assert.deepEqual(reactions,['reply-1']);
  let releaseOld;
  const stale=playbackHarness({playGate:new Promise(resolve=>{releaseOld=resolve;})});
  stale.context.startSpeechReaction=id=>reactions.push(id);
  stale.context.playSpeech('old.wav','old','stale-reply');
  await new Promise(resolve=>setImmediate(resolve));
  stale.context.stopCurrentAudio(); releaseOld();
  await new Promise(resolve=>setImmediate(resolve));
  assert.deepEqual(reactions,['reply-1']);
});
