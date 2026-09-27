(function(root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.EmotionDriver = api;
})(typeof window !== 'undefined' ? window : globalThis, function() {
  'use strict';
  // Visible, partial blends: bundled VRM0 presets deform the whole face.
  const PROFILES = {
    neutral: {},
    happy: {happy: .42},
    shy: {happy: .26, relaxed: .06, shy: .24, blush: .20},
    angry: {angry: .42},
    sad: {sad: .40},
    surprised: {surprised: .40},
    refuse: {angry: .30},
    thankful: {happy: .34, relaxed: .06},
  };
  const ALIASES = {
    happy: ['happy', 'joy'], sad: ['sad', 'sorrow'], angry: ['angry'],
    relaxed: ['relaxed', 'fun'], surprised: ['surprised', 'surprise'],
    shy: ['shy'], blush: ['blush'],
  };
  const SPEAKING = {happy: .70, relaxed: .70, sad: .80, angry: .80,
    surprised: .70, shy: .75, blush: 1};
  function normalize(value) {
    const name = String(value || '').trim().toLowerCase();
    return Object.prototype.hasOwnProperty.call(PROFILES, name) ? name : 'neutral';
  }
  function createDriver(options = {}) {
    const now = options.now;
    let startedAt = now ? now() : 0;
    let mood = 'neutral', age = 0, manager = null, channels = {}, weights = {};
    let pendingReply = null;
    function restart() { age=0; startedAt=now ? now() : 0; }
    return {
      setEmotion(value, replyId) {
        mood=normalize(value); pendingReply=replyId || null; restart();
      },
      startSpeech(replyId) {
        // Synthesis can take tens of seconds. Renew once at real playback start,
        // never on buffering, replay, cancelled requests or a different reply.
        if (!replyId || replyId !== pendingReply) return false;
        pendingReply=null; restart(); return true;
      },
      update(em, dt, speaking) {
        if (!em) return;
        if (manager !== em) {
          manager = em; channels = {}; weights = {};
          const names = Object.keys(em.expressionMap || {});
          for (const [semantic, aliases] of Object.entries(ALIASES)) {
            const actual = names.find(n => aliases.includes(n.toLowerCase()));
            if (actual) { channels[semantic] = actual; weights[actual] = 0; }
          }
        }
        dt = Number.isFinite(dt) ? Math.max(0, Math.min(.1, dt)) : 0;
        age = now ? Math.max(0, now() - startedAt) : age + dt;
        const alpha = 1 - Math.exp(-5 * dt);
        const profile = PROFILES[mood];
        // A brief reaction, then ease back to a truly neutral face, even in speech.
        const fade = Math.max(0, Math.min(1, (age - 1.5) / 1.8));
        const envelope = mood === 'neutral' ? 0 : 1 - fade * fade * (3 - 2 * fade);
        for (const [semantic, actual] of Object.entries(channels)) {
          let target = profile[semantic] || 0;
          // Missing custom surprise: retain a subtle alert/concerned face.
          if (mood === 'surprised' && !channels.surprised && semantic === 'sad') target=.12;
          target *= envelope * (speaking ? SPEAKING[semantic] : 1);
          weights[actual] += (target - weights[actual]) * alpha;
          if (target === 0 && (weights[actual] < .0008 || age >= 4)) weights[actual] = 0;
          // Own only mood channels. Never reset mouth, blink or gaze channels.
          // Keep internal weights so animation tracks cannot fight the blend.
          em.setValue(actual, weights[actual]);
        }
      },
    };
  }
  return {PROFILES, normalize, createDriver};
});
