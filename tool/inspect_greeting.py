"""Read actual retargeted greeting hand motion, without modifying app assets."""
import json, threading
from pathlib import Path
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, unquote
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/verification';OUT.mkdir(parents=True,exist_ok=True)
INSPECT='''window.inspectGreeting=async()=>{
 const clip=await loadClip(ANIMATIONS.greeting);_animationMixer.stopAllAction();_fades.length=0;
 const a=_animationMixer.clipAction(clip);a.reset().setEffectiveWeight(1).setLoop(THREE.LoopOnce,1).play();a.clampWhenFinished=true;
 const samples=[];
 for(let t=0;t<=clip.duration;t+=.1){
  _animationMixer.setTime(t);currentVrm.scene.updateMatrixWorld(true);
  samples.push({t,...Object.fromEntries(['rightHand','leftHand','rightUpperArm','leftUpperArm'].map(n=>[n,currentVrm.humanoid.getNormalizedBoneNode(n).getWorldPosition(new THREE.Vector3()).toArray()]))});
 }
 return {duration:clip.duration,tracks:clip.tracks.slice(0,5).map(t=>t.name),samples};
};'''
class Handler(SimpleHTTPRequestHandler):
 def do_GET(self):
  if urlparse(self.path).path=='/viewer.html':
   html=(ROOT/'assets/web/vrm_viewer.html').read_text(encoding='utf-8').replace('window.playAnimation = playAnimation;',INSPECT+'\nwindow.playAnimation = playAnimation;')
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
  b=p.chromium.launch(headless=True);page=b.new_page()
  base=f'http://127.0.0.1:{server.server_port}'
  page.goto(base+'/viewer.html',wait_until='networkidle')
  page.evaluate('(url)=>window.loadModel(url)',base+'/senpai.vrm')
  result=page.evaluate('window.inspectGreeting()')
  (OUT/'greeting-motion.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
  print('duration',result['duration'],'tracks',result['tracks'])
  for s in result['samples'][::3]:print(round(s['t'],2),'R height above shoulder',round(s['rightHand'][1]-s['rightUpperArm'][1],3),'L',round(s['leftHand'][1]-s['leftUpperArm'][1],3))
  b.close()
finally:server.shutdown()
