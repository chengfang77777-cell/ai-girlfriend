const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const html = fs.readFileSync(path.join(__dirname, '../assets/web/vrm_viewer.html'), 'utf8');
const code = html.match(/\/\/ BEGIN WHEEL_ROUTING([\s\S]*?)\/\/ END WHEEL_ROUTING/)?.[1];
test('viewer installs explicit wheel routing', () => assert.ok(code));

class Vector {
  constructor(x = 0, y = 0, z = 0) { Object.assign(this, { x, y, z }); }
  clone() { return new Vector(this.x, this.y, this.z); }
  sub(v) { this.x -= v.x; this.y -= v.y; this.z -= v.z; return this; }
  add(v) { this.x += v.x; this.y += v.y; this.z += v.z; return this; }
  copy(v) { return Object.assign(this, v); }
  length() { return Math.hypot(this.x, this.y, this.z); }
  multiplyScalar(s) { this.x *= s; this.y *= s; this.z *= s; return this; }
}
function harness(flutter = true) {
  let listener;
  let options;
  const camera = { position: new Vector(0, 1.4, 2.5) };
  const controls = { target: new Vector(0, 1.4, 0), minDistance: 1, maxDistance: 4, update() {} };
  const context = {
    camera, controls, URLSearchParams,
    window: { location: { search: flutter ? '?wheelRouting=flutter' : '' } },
    renderer: { domElement: { addEventListener(name, callback, opts) {
      assert.equal(name, 'wheel'); listener = callback; options = opts;
    } } },
  };
  vm.runInNewContext(code, context);
  return { camera, controls, context, get options() { return options; },
    wheel(ctrlKey, deltaY = 120) {
      const event = { ctrlKey, deltaY, deltaMode: 0, prevented: false, stopped: false,
        preventDefault() { this.prevented = true; }, stopImmediatePropagation() { this.stopped = true; } };
      listener(event);
      return event;
    },
  };
}
if (code) {
  test('native WebView wheels are blocked to prevent duplicate or unmodified zoom', () => {
    const h = harness();
    for (const ctrl of [false, true]) {
      const event = h.wheel(ctrl);
      assert.ok(event.prevented && event.stopped);
      assert.equal(h.camera.position.z, 2.5);
    }
    assert.equal(h.options.capture, true);
    assert.equal(h.options.passive, false);
  });
  test('Flutter zoom command respects direction and camera distance limits', () => {
    const h = harness();
    h.context.window.zoomModelByWheel(-120);
    assert.ok(h.camera.position.z < 2.5);
    for (let i = 0; i < 50; i++) h.context.window.zoomModelByWheel(-120);
    assert.equal(h.camera.position.z, 1);
    for (let i = 0; i < 50; i++) h.context.window.zoomModelByWheel(120);
    assert.equal(h.camera.position.z, 4);
    h.context.window.zoomModelByWheel(NaN);
    assert.equal(h.camera.position.z, 4);
  });
  test('standalone viewer zooms only for Ctrl plus wheel', () => {
    const h = harness(false);
    h.wheel(false);
    assert.equal(h.camera.position.z, 2.5);
    h.wheel(true);
    assert.ok(h.camera.position.z > 2.5);
  });
}
