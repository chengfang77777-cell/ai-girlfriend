"""Exercise actual seven-model hand poses and canvas gestures in Chromium."""
import json, threading, sys, math
from pathlib import Path
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, unquote
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/verification';OUT.mkdir(parents=True,exist_ok=True)
class Handler(SimpleHTTPRequestHandler):
    def translate_path(self,path):
        p=unquote(urlparse(path).path).lstrip('/')
        if p=='viewer.html':return str(ROOT/'assets/web/vrm_viewer.html')
        if p.startswith('js/'):return str(ROOT/'assets/web'/p)
        if p.startswith('animations/'):return str(ROOT/'assets'/p)
        if p.endswith('.vrm'):return str(ROOT/'assets/models'/Path(p).name)
        return str(OUT/'missing')
    def log_message(self,*args):pass
server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
results=[]
try:
  with sync_playwright() as p:
    browser=p.chromium.launch(headless=True,args=['--autoplay-policy=no-user-gesture-required'])
    page=browser.new_page(viewport={'width':900,'height':900})
    errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
    page.add_init_script('window.events=[];window.chrome=window.chrome||{};window.chrome.webview={postMessage:m=>window.events.push(m)}')
    base=f'http://127.0.0.1:{server.server_port}'
    page.goto(base+'/viewer.html',wait_until='networkidle')
    selected=next((arg.split('=',1)[1] for arg in sys.argv if arg.startswith('--model=')),'senpai')
    for model in ([selected] if '--motion' in sys.argv else ['senpai','genki','tsundere','oneesan','iyashi','ram','rem']):
      page.evaluate('(url)=>window.loadModel(url)',base+'/'+model+'.vrm')
      page.wait_for_function('window.startHighFive?.()===true',timeout=60000)
      page.wait_for_function('window.highFiveStatus().state==="waiting"')
      page.wait_for_timeout(250)
      status=page.evaluate('window.highFiveStatus()');target=status['palm']
      assert target and target['visible'],(model,status)
      pose=page.evaluate('()=>Object.fromEntries(["rightUpperArm","rightLowerArm","rightHand","rightMiddleProximal"].map(n=>{const b=currentVrm.humanoid.getNormalizedBoneNode(n);return[n,b.getWorldPosition(b.position.clone()).toArray()]}))')
      page.mouse.click(20,800)
      assert page.evaluate('window.highFiveStatus().state')=='waiting'
      page.mouse.move(target['x'],target['y']);page.mouse.down()
      page.mouse.move(target['x']+30,target['y']);page.mouse.move(target['x'],target['y']);page.mouse.up()
      assert page.evaluate('window.highFiveStatus().state')=='waiting',(model,'After drag',page.evaluate('window.highFiveStatus()'))
      target=page.evaluate('window.highFiveStatus().palm')
      before=len(page.evaluate('window.events'))
      page.mouse.click(target['x'],target['y'])
      page.wait_for_function('(n)=>window.events.slice(n).includes("interaction:hit")',arg=before,timeout=3000)
      page.wait_for_function('window.highFiveStatus().state==="idle"')
      # Screenshot capture can take seconds with software rendering. Keep it
      # separate from the six-second gesture window being tested above.
      page.wait_for_function('window.startHighFive()===true')
      page.wait_for_function('window.highFiveStatus().state==="waiting"')
      page.screenshot(path=str(OUT/f'high-five-{model}.png'))
      page.wait_for_function('window.highFiveStatus().state==="idle"')
      results.append({'model':model,'target':target,'pose':pose})
      print(model+': palm target, miss, drag, hit and return passed',flush=True)
    if '--motion' in sys.argv:
      # Freeze only performance time while capturing each exact motion phase.
      # Browser frames keep rendering, so captures cannot consume the gesture.
      page.wait_for_function('(()=>{if(!window.startHighFive())return false;window._motionClock=performance.now();performance.now=()=>window._motionClock;return true;})()')
      origin=page.evaluate('window._motionClock')
      samples=[]
      for ms in list(range(0,1300,100))+list(range(7200,8300,100)):
        page.evaluate('(t)=>window._motionClock=t',origin+ms)
        page.evaluate('()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))')
        if ms in [400,500,600,1200,7600]:page.screenshot(path=str(OUT/f'high-five-motion-{selected}-{ms}.png'))
        bones=page.evaluate('''()=>Object.fromEntries(['rightUpperArm','rightLowerArm','rightHand'].map((name,i)=>{
          const b=currentVrm.humanoid.getNormalizedBoneNode(name),q=b.quaternion;
          const child=currentVrm.humanoid.getNormalizedBoneNode(['rightLowerArm','rightHand','rightMiddleProximal'][i]);
          const axis=child.position.clone().normalize();
          let twist=2*Math.atan2(q.x*axis.x+q.y*axis.y+q.z*axis.z,q.w)*180/Math.PI;
          twist=((twist+540)%360)-180;
          return [name,{q:q.toArray(),twist,position:b.getWorldPosition(b.position.clone()).toArray()}];
        }))''')
        samples.append({'ms':ms,'status':page.evaluate('window.highFiveStatus()'),'bones':bones})
      (OUT/f'high-five-motion-{selected}.json').write_text(json.dumps(samples,indent=2),encoding='utf-8')
      peak=0
      for a,b in zip(samples,samples[1:]):
        if b['ms']-a['ms']>100:continue
        for name in ['rightUpperArm','rightLowerArm','rightHand']:
          dot=abs(sum(x*y for x,y in zip(a['bones'][name]['q'],b['bones'][name]['q'])))
          angle=math.degrees(2*math.acos(min(1,dot)));peak=max(peak,angle)
          assert angle<60,(selected,name,a['ms'],b['ms'],'Joint flip',angle)
      assert not errors,errors
      print(f'{selected}: raise/return continuity passed; max joint step {peak:.1f} degrees per 100 ms',flush=True)
      browser.close()
      sys.exit(0)
    page.wait_for_function('window.startHighFive()===true')
    page.wait_for_function('window.highFiveStatus().state==="waiting"')
    page.evaluate('window.cancelHighFive()')
    page.wait_for_function('window.highFiveStatus().state==="idle"')
    page.wait_for_function('window.startHighFive()===true')
    page.evaluate('window.onUserSendMessage()')
    assert page.evaluate('window.highFiveStatus().state')=='idle'
    assert not errors,errors
    (OUT/'high-five-results.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
    print('Cancel and chat interruption passed; no page errors.',flush=True)
    browser.close()
finally:server.shutdown()
