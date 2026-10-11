"""Compare authored greeting with the high-five layer on all seven actual VRMs."""
import json, threading
from pathlib import Path
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, unquote
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/verification';OUT.mkdir(parents=True,exist_ok=True)
VERIFY='''window.verifyGreetingFrames=async()=>{
 const clip=await loadClip(ANIMATIONS.greeting),root=currentVrm.humanoid.normalizedHumanBonesRoot;
 const sampler=window.HighFive.createPoseSampler(THREE,currentVrm,clip),mixer=new THREE.AnimationMixer(currentVrm.scene);
 const action=mixer.clipAction(clip);action.setLoop(THREE.LoopOnce,1);action.clampWhenFinished=true;action.play();
 let maxRotationError=0,maxPositionError=0;
 for(let t=.95;t<4.66;t+=.05){
   mixer.setTime(t);
   const original=clip.tracks.map(track=>{
     const m=/^(.*)\\.(quaternion|position)$/.exec(track.name);
     const b=m&&root.getObjectByName(m[1]);return b?{bone:b,key:m[2],value:b[m[2]].clone()}:null;
   }).filter(Boolean);
   sampler.sample(t,1);
   for(const c of original){
     if(c.key==='quaternion')maxRotationError=Math.max(maxRotationError,c.value.angleTo(c.bone.quaternion));
     else maxPositionError=Math.max(maxPositionError,c.value.distanceTo(c.bone.position));
   }
   sampler.restore();
 }
 mixer.stopAllAction();
 return {maxRotationError,maxPositionError,tracks:clip.tracks.length};
};'''
class Handler(SimpleHTTPRequestHandler):
 def do_GET(self):
  if urlparse(self.path).path=='/viewer.html':
   html=(ROOT/'assets/web/vrm_viewer.html').read_text(encoding='utf-8').replace('window.playAnimation = playAnimation;',VERIFY+'\nwindow.playAnimation = playAnimation;')
   self.send_response(200);self.send_header('Content-Type','text/html; charset=utf-8');self.end_headers();self.wfile.write(html.encode());return
  return super().do_GET()
 def translate_path(self,path):
  p=unquote(urlparse(path).path).lstrip('/')
  if p.startswith('js/'):return str(ROOT/'assets/web'/p)
  if p.startswith('animations/'):return str(ROOT/'assets'/p)
  if p.endswith('.vrm'):return str(ROOT/'assets/models'/Path(p).name)
  return str(OUT/'missing')
 def log_message(self,*args):pass
server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
 with sync_playwright() as p:
  browser=p.chromium.launch(headless=True);page=browser.new_page()
  base=f'http://127.0.0.1:{server.server_port}'
  page.goto(base+'/viewer.html',wait_until='networkidle')
  results={}
  for model in ['senpai','genki','tsundere','oneesan','iyashi','ram','rem']:
   page.evaluate('(url)=>window.loadModel(url)',base+'/'+model+'.vrm')
   result=page.evaluate('window.verifyGreetingFrames()')
   assert result['maxRotationError']<.002 and result['maxPositionError']<1e-6,(model,result)
   results[model]=result;print(model,result,flush=True)
  (OUT/'greeting-frame-comparison.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
  browser.close()
finally:server.shutdown()
