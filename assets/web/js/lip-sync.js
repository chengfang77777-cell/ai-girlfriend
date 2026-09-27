// Phase-one audio heuristic: loudness controls amplitude, spectrum controls shape.
// The browser and Node regression tests intentionally use the same implementation.
(function(root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.LipSync = api;
})(typeof window !== 'undefined' ? window : globalThis, function() {
  'use strict';

  const NAMES = Object.freeze(['aa', 'ih', 'oh', 'ou', 'ee']);
  // Tune here for each voice/model. RMS is measured on normalized PCM, times in seconds.
  const DEFAULT_CONFIG = Object.freeze({
    gateOpenRms: 0.012,
    gateCloseRms: 0.006,
    gateHoldSeconds: 0.045,
    fullScaleRms: 0.16,
    loudnessExponent: 0.7,
    attackSeconds: 0.035,
    releaseSeconds: 0.085,
    silenceReleaseSeconds: 0.045,
    shapeSeconds: 0.055,
    maxWeight: 0.72,
    caps: Object.freeze({ aa: 0.65, ih: 0.55, oh: 0.6, ou: 0.5, ee: 0.5 }),
  });

  const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
  const approach = (value, target, dt, seconds) =>
    value + (target - value) * (1 - Math.exp(-dt / seconds));
  const emptyWeights = () => ({ aa: 0, ih: 0, oh: 0, ou: 0, ee: 0 });

  function createDriver(options = {}) {
    const config = { ...DEFAULT_CONFIG, ...options,
      caps: { ...DEFAULT_CONFIG.caps, ...options.caps } };
    const weights = emptyWeights();
    const shape = emptyWeights();
    const targetShape = emptyWeights();
    let envelope = 0;
    let gateOpen = false;
    let belowGateSeconds = 0;
    let shapeInitialized = false;

    function reset() {
      envelope = 0;
      gateOpen = false;
      belowGateSeconds = 0;
      shapeInitialized = false;
      for (const name of NAMES) weights[name] = shape[name] = targetShape[name] = 0;
    }

    function update(waveform, spectrumDb, sampleRate, deltaSeconds) {
      // Clamp only long stalls; normal 30/60/120 Hz updates follow identical time constants.
      const dt = clamp(Number.isFinite(deltaSeconds) ? deltaSeconds : 0, 0, 0.1);
      let mean = 0;
      let sumSquares = 0;
      for (const sample of waveform) mean += sample;
      mean = waveform.length ? mean / waveform.length : 0;
      for (const sample of waveform) sumSquares += (sample - mean) ** 2;
      const rms = waveform.length ? Math.sqrt(sumSquares / waveform.length) : 0;

      if (rms >= config.gateOpenRms) {
        gateOpen = true;
        belowGateSeconds = 0;
      } else if (rms < config.gateCloseRms) {
        belowGateSeconds += dt;
        if (belowGateSeconds >= config.gateHoldSeconds) gateOpen = false;
      } else {
        belowGateSeconds = 0;
      }

      const silent = !gateOpen || rms < config.gateCloseRms;
      const level = clamp((rms - config.gateCloseRms) /
        (config.fullScaleRms - config.gateCloseRms), 0, 1);
      const targetEnvelope = silent ? 0 : level ** config.loudnessExponent;
      const seconds = silent ? config.silenceReleaseSeconds :
        (targetEnvelope > envelope ? config.attackSeconds : config.releaseSeconds);
      envelope = approach(envelope, targetEnvelope, dt, seconds);
      if (silent && envelope < 0.0005) envelope = 0;

      if (!silent) {
        // Byte frequency values are log-scaled; convert dB to linear amplitude first.
        // Restrict analysis to speech frequencies so upper-band hiss has less influence.
        let weightedFrequency = 0;
        let amplitudeSum = 0;
        const binSize = sampleRate / (2 * spectrumDb.length);
        for (let i = 1; i < spectrumDb.length; i++) {
          const frequency = i * binSize;
          if (frequency < 120 || frequency > 4000 || !Number.isFinite(spectrumDb[i])) continue;
          const amplitude = 10 ** (spectrumDb[i] / 20);
          weightedFrequency += frequency * amplitude;
          amplitudeSum += amplitude;
        }
        const centroid = amplitudeSum > 0 ? weightedFrequency / amplitudeSum : 1500;
        const colour = clamp((centroid - 250) / 3000, 0, 1);
        targetShape.aa = Math.max(0, 1 - Math.abs(colour - 0.45) / 0.45);
        targetShape.oh = Math.max(0, 1 - Math.abs(colour - 0.2) / 0.28) * 0.8;
        targetShape.ou = Math.max(0, 1 - colour / 0.3) * 0.8;
        targetShape.ih = Math.max(0, (colour - 0.4) / 0.6);
        targetShape.ee = Math.max(0, (colour - 0.65) / 0.35) * 0.8;
        const shapeSum = NAMES.reduce((sum, name) => sum + targetShape[name], 0);
        for (const name of NAMES) {
          const target = targetShape[name] / shapeSum;
          shape[name] = shapeInitialized ? approach(shape[name], target, dt, config.shapeSeconds) : target;
        }
        shapeInitialized = true;
      }

      // Smooth the normalized shape independently from amplitude; this preserves the
      // combined budget even while moving between vowels. Caps may only reduce it.
      for (const name of NAMES) {
        weights[name] = Math.min(config.caps[name], shape[name] * envelope * config.maxWeight);
      }
      return weights;
    }

    return { update, reset, weights };
  }

  return { createDriver, DEFAULT_CONFIG, NAMES };
});
