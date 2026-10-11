// Installed before the music page's scripts. No network or private player APIs.
(() => {
  'use strict';
  if (window.__studyMusicBridge) return;
  const handlers = new Map();
  const session = window.navigator.mediaSession;
  let lastMedia = null, preferredVolume = null;
  let writingVolume = false;
  const controlledMedia = new WeakMap();
  function mediaIdentity(media) {
    return JSON.stringify([session?.metadata?.title || '', session?.metadata?.artist || '', media.src || '']);
  }
  function observeVolume(media) {
    const tracked = controlledMedia.get(media);
    if (writingVolume || !tracked || media !== lastMedia || tracked.track !== mediaIdentity(media)) return;
    if (tracked.volume !== media.volume) {
      tracked.volume = media.volume;
      rememberVolume(media.volume);
    }
  }
  const volumeKey = '__companion_music_volume_v1';
  try {
    const saved = window.sessionStorage?.getItem(volumeKey);
    if (saved !== null && saved !== undefined && Number.isFinite(Number(saved))) preferredVolume = Math.min(1, Math.max(0, Number(saved)));
  } catch (_) {}
  function rememberVolume(value) {
    preferredVolume = value;
    try { window.sessionStorage?.setItem(volumeKey, String(value)); } catch (_) {}
  }
  function volumeControl(node) {
    if (!node || !(node.type === 'range' || node.getAttribute?.('role') === 'slider')) return false;
    let current = node;
    for (let i = 0; current && i < 4; i++, current = current.parentElement) {
      if (['aria-label', 'title', 'name', 'id'].some(key => /volume|音量/i.test(current.getAttribute?.(key) || ''))) return true;
    }
    return false;
  }
  function syncVolumeControl(value) {
    // Send the page's own range input through its normal state/save handlers.
    const input = [...window.document.querySelectorAll('input[type="range"]')].find(volumeControl);
    if (!input) return;
    const min = input.min === '' ? 0 : Number(input.min), max = input.max === '' ? 100 : Number(input.max);
    if (!Number.isFinite(min) || !Number.isFinite(max) || max <= min) return;
    const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement?.prototype || {}, 'value')?.set;
    if (!setter) return;
    setter.call(input, String(min + value * (max - min)));
    input.dispatchEvent(new window.Event('input', {bubbles: true}));
    input.dispatchEvent(new window.Event('change', {bubbles: true}));
  }
  if (session) {
    const original = session.setActionHandler;
    session.setActionHandler = function(action, handler) {
      const result = original.call(this, action, handler);
      if (handler) handlers.set(action, handler); else handlers.delete(action);
      return result;
    };
  }
  // Many web players use new Audio() without attaching it to the DOM.
  const mediaPrototype = window.HTMLMediaElement?.prototype;
  if (mediaPrototype) {
    const volume = Object.getOwnPropertyDescriptor(mediaPrototype, 'volume');
    if (volume?.configurable && volume.set && volume.get) {
      Object.defineProperty(mediaPrototype, 'volume', {...volume, set(value) {
        // Observe successful page writes; never substitute or reject the value.
        // Custom sliders and asynchronous handlers must remain fully functional.
        volume.set.call(this, value);
        observeVolume(this);
      }});
    }
    const original = mediaPrototype.play;
    mediaPrototype.play = function(...args) {
      observeVolume(this);
      const track = mediaIdentity(this), tracked = controlledMedia.get(this);
      if ((!tracked || tracked.track !== track) && preferredVolume !== null) {
        // Restore once at track initialization, through the page's own control
        // where available. Later page writes are authoritative, not locked out.
        writingVolume = true;
        try {
          try { syncVolumeControl(preferredVolume); } catch (_) {}
          this.volume = preferredVolume;
        } finally { writingVolume = false; }
      }
      controlledMedia.set(this, {track, volume: this.volume});
      lastMedia = this;
      return original.apply(this, args);
    };
  }
  const text = value => typeof value === 'string' ? value.trim().slice(0, 240) : '';
  function currentMedia() {
    const media = [...window.document.querySelectorAll('audio,video')];
    if (lastMedia && !media.includes(lastMedia)) media.push(lastMedia);
    const loaded = media.filter(m => m.currentSrc || m.src);
    return loaded.find(m => !m.paused && !m.ended) ||
      (loaded.includes(lastMedia) ? lastMedia : loaded[0]) || null;
  }
  const labels = {
    previous: /^(上一首|上一曲|previous(?:\s+track)?)(?:\s|[（(]|$)/i,
    next: /^(下一首|下一曲|next(?:\s+track)?)(?:\s|[（(]|$)/i,
    play: /^(播放|play)(?:\s|[（(]|$)/i,
    pause: /^(暂停|pause)(?:\s|[（(]|$)/i,
  };
  function button(action) {
    return [...window.document.querySelectorAll('button,[role="button"],a[title],[aria-label],[title]')].find(node => {
      if (node.disabled || node.getAttribute('aria-disabled') === 'true' || !node.getClientRects().length) return false;
      const style = window.getComputedStyle(node);
      if (style.display === 'none' || style.visibility === 'hidden') return false;
      return ['aria-label', 'title'].some(key => labels[action].test(text(node.getAttribute(key)))) ||
        labels[action].test(text(node.textContent));
    }) || null;
  }
  function localSnapshot() {
    const media = currentMedia(), metadata = session?.metadata;
    if (media) observeVolume(media);
    const playing = media ? !media.paused && !media.ended : session?.playbackState === 'playing';
    const volume = media ? (media.muted ? 0 : media.volume) : null;
    const duration = media && Number.isFinite(media.duration) && media.duration > 0 ? media.duration : 0;
    const position = media && Number.isFinite(media.currentTime) ? Math.max(0, Math.min(media.currentTime, duration)) : 0;
    const source = `${media?.currentSrc || ''}|${media?.src || ''}`;
    let sourceHash = 2166136261;
    for (let i = 0; i < source.length; i++) sourceHash = Math.imul(sourceHash ^ source.charCodeAt(i), 16777619);
    const trackId = JSON.stringify([text(metadata?.title), text(metadata?.artist), sourceHash >>> 0]);
    return {
      title: text(metadata?.title) || text(media?.getAttribute('title')),
      artist: text(metadata?.artist), playing, volume,
      trackId, duration, position,
      canSeek: duration > 0 && (handlers.has('seekto') || (media?.seekable?.length > 0)),
      canPrevious: handlers.has('previoustrack') || !!button('previous'),
      canNext: handlers.has('nexttrack') || !!button('next'),
      canToggle: !!media || handlers.has(playing ? 'pause' : 'play') || !!button(playing ? 'pause' : 'play'),
      canVolume: !!media,
    };
  }
  async function localCommand(action, value) {
    try {
      const state = localSnapshot(), media = currentMedia();
      if (action === 'volume') {
        if (!media || typeof value !== 'number' || !Number.isFinite(value)) return {ok: false};
        rememberVolume(Math.min(1, Math.max(0, value)));
        controlledMedia.set(media, {track: mediaIdentity(media), volume: preferredVolume});
        writingVolume = true;
        try {
          syncVolumeControl(preferredVolume);
          media.volume = preferredVolume;
          if (preferredVolume > 0) media.muted = false;
        } finally { writingVolume = false; }
        return {ok: Math.abs(media.volume - preferredVolume) < .001};
      }
      if (action === 'seek') {
        if (!state.canSeek || !value || value.trackId !== state.trackId ||
            typeof value.seconds !== 'number' || !Number.isFinite(value.seconds)) return {ok: false};
        let target = Math.max(0, Math.min(state.duration, value.seconds));
        if (handlers.has('seekto')) await handlers.get('seekto')({action: 'seekto', seekTime: target, fastSeek: false});
        else {
          const ranges = media.seekable;
          let closest = null;
          for (let i = 0; i < ranges.length; i++) {
            const bounded = Math.max(ranges.start(i), Math.min(ranges.end(i), target));
            if (closest === null || Math.abs(bounded - target) < Math.abs(closest - target)) closest = bounded;
          }
          if (closest === null) return {ok: false};
          media.currentTime = closest;
        }
        return {ok: true};
      }
      const key = action === 'toggle' ? (state.playing ? 'pause' : 'play') : action;
      const mediaAction = {previous: 'previoustrack', next: 'nexttrack', play: 'play', pause: 'pause'}[key];
      if (!mediaAction) return {ok: false};
      const handler = handlers.get(mediaAction);
      if (handler) await handler({action: mediaAction});
      else if (media && key === 'play') await media.play();
      else if (media && key === 'pause') media.pause();
      else {
        const control = button(key);
        if (control) control.click();
        else return {ok: false};
      }
      return {ok: true};
    } catch (_) { return {ok: false}; }
  }
  function selectPlayer() {
    const candidates = [{bridge: window.__studyMusicBridge, state: localSnapshot()}];
    function visit(parent, depth) {
      if (depth > 3) return;
      for (let i = 0; i < Math.min(parent.frames.length, 16); i++) {
        try {
          const frame = parent.frames[i], bridge = frame.__studyMusicBridge;
          if (bridge) candidates.push({bridge, state: bridge.localSnapshot()});
          visit(frame, depth + 1);
        } catch (_) { /* Cross-origin frames are intentionally inaccessible. */ }
      }
    }
    visit(window, 0);
    const score = s => (s.playing ? 100 : 0) + (s.canVolume ? 20 : 0) + (s.title ? 10 : 0) + (s.canNext ? 1 : 0);
    candidates.sort((a, b) => score(b.state) - score(a.state));
    return candidates[0];
  }
  window.__studyMusicBridge = {
    localSnapshot, localCommand,
    snapshot: () => selectPlayer().state,
    command: (action, value) => selectPlayer().bridge.localCommand(action, value),
  };
})();
