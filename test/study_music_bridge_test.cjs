const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('assets/web/js/study-music-bridge.js', 'utf8');

function fixture() {
  const nodes = [], media = [];
  const events = {};
  class Media {
    constructor() { this.src = 'fixture.wav'; this.paused = true; this.ended = false; this.volume = .6; this.muted = false;
      this.duration = 180; this.currentTime = 12; this.seekable = {length: 1, start: () => 0, end: () => 180}; }
    get volume() { return this._volume; }
    set volume(value) { this._volume = value; }
    play() { this.paused = false; return Promise.resolve(); }
    pause() { this.paused = true; }
    getAttribute(name) { return this[name] || null; }
  }
  const session = {metadata: null, playbackState: 'none', setActionHandler() {}};
  const win = {navigator: {mediaSession: session}, HTMLMediaElement: Media, frames: [],
    document: {querySelectorAll: selector => selector === 'audio,video' ? media : nodes,
      addEventListener: (name, handler) => events[name] = handler},
    getComputedStyle: () => ({display: 'block', visibility: 'visible'})};
  win.window = win;
  vm.runInNewContext(source, win);
  return {bridge: win.__studyMusicBridge, session, Media, media, nodes, win, events};
}

test('captures site media handlers and metadata without replacing their browser behavior', async () => {
  const f = fixture(); let index = 0;
  f.session.metadata = {title: '第一首', artist: '歌手'};
  f.session.setActionHandler('nexttrack', () => {index++; f.session.metadata = {title: '第二首', artist: '歌手'};});
  assert.equal(f.bridge.snapshot().title, '第一首');
  assert.equal(f.bridge.snapshot().canNext, true);
  assert.equal((await f.bridge.command('next')).ok, true);
  assert.equal(index, 1);
  assert.equal(f.bridge.snapshot().title, '第二首');
  f.session.setActionHandler('nexttrack', null);
  assert.equal(f.bridge.snapshot().canNext, false);
});

test('detached audio supports pause and volume, preserving volume on a new track', async () => {
  const f = fixture(); const audio = new f.Media();
  await audio.play();
  assert.equal(f.bridge.snapshot().playing, true);
  await f.bridge.command('volume', .25);
  assert.equal(audio.volume, .25);
  await f.bridge.command('toggle');
  assert.equal(audio.paused, true);
  const next = new f.Media(); await next.play();
  assert.equal(next.volume, .25);
  await f.bridge.command('volume', 3);
  assert.equal(next.volume, 1);
});

test('unsupported actions and handler failures are explicit; never pretend to skip', async () => {
  const f = fixture();
  assert.equal(f.bridge.snapshot().canNext, false);
  assert.equal((await f.bridge.command('next')).ok, false);
  f.session.setActionHandler('nexttrack', () => {throw new Error('queue unavailable');});
  assert.equal((await f.bridge.command('next')).ok, false);
  assert.equal((await f.bridge.command('volume', NaN)).ok, false);
});

test('semantic previous/next buttons are used only when visible and enabled', async () => {
  const f = fixture(); let clicks = 0;
  const button = {disabled: false, textContent: '', getClientRects: () => [1],
    getAttribute: name => name === 'aria-label' ? '下一首' : null,
    click: () => clicks++};
  f.nodes.push(button);
  assert.equal(f.bridge.snapshot().canNext, true);
  await f.bridge.command('next'); assert.equal(clicks, 1);
  button.disabled = true;
  assert.equal(f.bridge.snapshot().canNext, false);
});

test('same-origin child player is selected and opaque frames are ignored', async () => {
  const f = fixture(), child = fixture();
  child.session.metadata = {title: '子页面歌曲', artist: '演唱者'};
  const audio = new child.Media(); await audio.play();
  f.win.frames.push(new Proxy({}, {get() {throw new Error('cross origin');}}), child.win);
  assert.equal(f.bridge.snapshot().title, '子页面歌曲');
  await f.bridge.command('toggle'); assert.equal(audio.paused, true);
});

test('track initialization restores volume but later page writes remain usable', async () => {
  const f = fixture(), first = new f.Media(); await first.play();
  await f.bridge.command('volume', .25);
  first.src = 'next.wav'; first.volume = .8; await first.play();
  assert.equal(first.volume, .25, 'same-element track reset');
  f.bridge.snapshot();
  const second = new f.Media(); await second.play();
  assert.equal(second.volume, .25, 'replacement audio inherits volume');
  second.volume = .8;
  assert.equal(second.volume, .8, 'page can always adjust its own audio');
  assert.equal(f.bridge.snapshot().volume, .8);
});

test('seek reports time and bounds, refuses stale-track and unseekable requests', async () => {
  const f = fixture(), audio = new f.Media(); await audio.play();
  const state = f.bridge.snapshot();
  assert.equal(state.position, 12); assert.equal(state.duration, 180); assert.equal(state.canSeek, true);
  assert.equal((await f.bridge.command('seek', {seconds: 62, trackId: state.trackId})).ok, true);
  assert.equal(audio.currentTime, 62);
  audio.src = 'next.wav';
  assert.equal((await f.bridge.command('seek', {seconds: 100, trackId: state.trackId})).ok, false);
  audio.duration = Infinity;
  assert.equal(f.bridge.snapshot().canSeek, false);
});

test('a deliberate webpage volume adjustment updates the retained preference', async () => {
  const f = fixture(), audio = new f.Media(); await audio.play();
  await f.bridge.command('volume', .25);
  // Custom sliders, keyboard shortcuts and delayed handlers need no DOM label
  // or short trusted-input time window in order to control their own audio.
  audio.volume = .7;
  assert.equal(f.bridge.snapshot().volume, .7);
  const next = new f.Media(); await next.play();
  assert.equal(next.volume, .7);
});

test('alternating page and companion adjustments keep the latest value across pause/resume and tracks', async () => {
  const f = fixture(), audio = new f.Media(); await audio.play();
  await f.bridge.command('volume', .2);
  audio.volume = .8;
  audio.pause(); await audio.play();
  assert.equal(audio.volume, .8);
  await f.bridge.command('volume', .4);
  audio.volume = 0;
  assert.equal(f.bridge.snapshot().volume, 0);
  const next = new f.Media(); await next.play();
  assert.equal(next.volume, 0);
});
