"""Local Chromium smoke test of the actual viewer, models and audio events."""
import json
import threading
from pathlib import Path
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote, urlparse
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build' / 'verification'
OUT.mkdir(parents=True, exist_ok=True)

class Handler(SimpleHTTPRequestHandler):
    def translate_path(self, path):
        name = unquote(urlparse(path).path).lstrip('/')
        if name == 'viewer.html': return str(ROOT / 'assets/web/vrm_viewer.html')
        if name.startswith('js/'): return str(ROOT / 'assets/web' / name)
        if name.startswith('animations/'): return str(ROOT / 'assets' / name)
        if name.endswith('.vrm'): return str(ROOT / 'assets/models' / Path(name).name)
        if name.endswith('.wav'): return str(OUT / Path(name).name)
        return str(OUT / 'not-found')
    def log_message(self, *args): pass

server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
base = f'http://127.0.0.1:{server.server_port}'
results = []
face_query = """() => Object.fromEntries(Object.keys(currentVrm.expressionManager.expressionMap)
    .filter(k=>['happy','sad','angry','relaxed','surprised'].includes(k.toLowerCase()))
    .map(k=>[k,currentVrm.expressionManager.getValue(k)]))"""
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, args=['--autoplay-policy=no-user-gesture-required'])
        page = browser.new_page(viewport={'width': 900, 'height': 900})
        errors = []
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.add_init_script("window.events=[];window.chrome=window.chrome||{};window.chrome.webview={postMessage:m=>window.events.push(m)}")
        page.goto(base + '/viewer.html', wait_until='networkidle')
        page.wait_for_function("typeof window.loadModel==='function'")
        for model in ['senpai', 'genki', 'tsundere', 'oneesan', 'iyashi', 'ram', 'rem']:
            page.evaluate('() => { window.events=[]; }')
            page.evaluate('(url)=>window.loadModel(url)', base + '/' + model + '.vrm')
            page.wait_for_function("window.events.includes('vrm_loaded')", timeout=60000)
            startup = page.evaluate(face_query)
            assert all(v == 0 for v in startup.values()), (model, 'startup is not neutral', startup)
            if model == 'senpai': page.evaluate('() => { for(let i=0;i<3;i++) window.zoomModelByWheel(-240); }')
            for mood in ['neutral', 'happy', 'shy', 'angry', 'sad', 'surprised', 'refuse', 'thankful']:
                page.evaluate('(m)=>window.setExpression("_emotion",m)', mood)
                page.wait_for_timeout(750)
                weights = page.evaluate("() => Object.fromEntries(Object.keys(currentVrm.expressionManager.expressionMap).filter(k=>['happy','sad','angry','relaxed','surprised'].includes(k.toLowerCase())).map(k=>[k,currentVrm.expressionManager.getValue(k)]))")
                if mood != 'neutral': assert max(weights.values()) > .09, (model, mood, weights)
                results.append({'model': model, 'mood': mood, 'weights': weights})
                if model in ['senpai', 'rem']:
                    page.screenshot(path=str(OUT / f'{model}_{mood}.png'))
                page.evaluate('() => { window._isLipSyncPlaying=true; }')
                page.wait_for_timeout(300)
                speaking = page.evaluate(face_query)
                if mood != 'neutral': assert max(speaking.values()) > .15, (model, mood, 'speaking', speaking)
                results[-1]['speakingWeights'] = speaking
                if model in ['senpai', 'rem']:
                    page.screenshot(path=str(OUT / f'{model}_{mood}_speaking.png'))
                page.evaluate('() => { window._isLipSyncPlaying=false; }')
            page.wait_for_timeout(3600)
            settled = page.evaluate("() => Object.fromEntries(Object.keys(currentVrm.expressionManager.expressionMap).filter(k=>['happy','sad','angry','relaxed','surprised'].includes(k.toLowerCase())).map(k=>[k,currentVrm.expressionManager.getValue(k)]))")
            assert all(v == 0 for v in settled.values()), (model, 'did not return neutral', settled)
            print(f'{model}: all 8 moods rendered and returned to neutral', flush=True)
        # Real delayed audio, not a timer or synthesis-completed callback.
        for delay in [8,30]:
            reply = f'delayed-{delay}'
            page.evaluate('(id)=>window.triggerAction("talk","happy",id)', reply)
            page.wait_for_timeout(delay*1000)
            assert max(page.evaluate(face_query).values()) == 0
            page.evaluate('([url,id])=>window.playSpeech(url,id,id)', [base+'/tts_clone.wav',reply])
            page.wait_for_function('(id)=>window.events.includes("audio_started:"+id)', arg=reply, timeout=10000)
            page.wait_for_timeout(750)
            peak = page.evaluate(face_query)
            assert peak['happy'] > .20, (delay, peak)
            page.screenshot(path=str(OUT / f'rem_audio_after_{delay}s.png'))
            page.wait_for_timeout(3500)
            assert max(page.evaluate(face_query).values()) == 0
            page.wait_for_function('(id)=>window.events.includes("audio_ended:"+id)', arg=reply, timeout=20000)
            page.evaluate('([url,id])=>window.playSpeech(url,"replay-"+id,id)', [base+'/tts_clone.wav',reply])
            page.wait_for_timeout(750)
            assert max(page.evaluate(face_query).values()) == 0, 'Replay revived a stale face'
            page.evaluate('()=>window.stopCurrentAudio()')
            print(f'{delay}s synthesis delay: actual audio renewed once and faded during speech', flush=True)
        page.evaluate('(url)=>window.playSpeech(url,"smoke")', base + '/tts_clone.wav')
        page.wait_for_function("window.events.includes('audio_started:smoke')", timeout=10000)
        page.wait_for_function("window.events.includes('audio_ended:smoke')", timeout=20000)
        page.evaluate('(url)=>window.playSpeech(url,"bad")', base + '/missing.wav')
        page.wait_for_function("window.events.some(e=>e.startsWith('audio_error:bad:'))", timeout=10000)
        assert not errors, errors
        (OUT / 'viewer-results.json').write_text(json.dumps({'faces':results, 'audio':page.evaluate('window.events.filter(e=>e.startsWith("audio_"))'), 'errors':errors}, indent=2), encoding='utf-8')
        print('Real audio start/end/error events passed; no page errors.', flush=True)
        browser.close()
finally:
    server.shutdown()
