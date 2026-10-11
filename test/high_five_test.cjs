const {test}=require('node:test');
const assert=require('node:assert/strict');
const HighFive=require('../assets/web/js/high-five.js');
const fs=require('node:fs');
const vm=require('node:vm');
test('pending body animation loading reserves the avatar before a high five can start',async()=>{
  const html=fs.readFileSync(require.resolve('../assets/web/vrm_viewer.html'),'utf8');
  let release;
  const pending=new Promise(resolve=>{release=resolve;});
  const context=vm.createContext({currentVrm:{},_pendingBodyAnimationLoads:0,_bodyRequest:0,_studyQuiet:false,loadClip:()=>pending,console:{error(){}},
    highFive:null,window:{HighFive:{createRig:(_,config)=>config}},THREE:{},renderer:{domElement:{}},camera:{},
    _isGreetingDone:true,_currentAnimName:'idle',ANIMATIONS:{idle:'idle'},sendToFlutter(){},finishHighFiveGreeting(){}});
  vm.runInContext(html.slice(html.indexOf('async function playAnimation('),html.indexOf('function stopAnimation(')),context);
  vm.runInContext(html.slice(html.indexOf('highFive = window.HighFive.createRig('),html.indexOf('const loader=new GLTFLoader()')),context);
  assert.equal(context.highFive.isReady(),true);
  const loading=context.playAnimation('variant');
  assert.equal(context.highFive.isReady(),false);
  release(null);await loading;
  assert.equal(context.highFive.isReady(),true);
});
function fixture(){let time=0;const events=[];const d=HighFive.createTimeline({now:()=>time,onState:s=>events.push(s)});return {d,events,at(t){time=t;return d.tick();}};}
test('starts once, waits at source frame and times out through the original lowering',()=>{
  const f=fixture();assert.equal(f.d.start(),true);assert.equal(f.d.start(),false);
  assert.equal(f.at(.55).state,'raising');assert.equal(f.at(.55).clipTime,1.5);
  assert.equal(f.at(1.2).state,'waiting');assert.equal(f.at(1.2).weight,1);
  assert.equal(f.at(7.5).state,'returning');assert.equal(f.at(11).state,'idle');
  assert.equal(f.at(11).weight,0);assert.deepEqual(f.events,['raising','waiting','returning','idle']);
});
test('only waiting hand can be hit and it reacts just once',()=>{
  const f=fixture();f.d.start();assert.equal(f.d.hit(),false);f.at(1.2);
  assert.equal(f.d.hit(),true);assert.equal(f.d.hit(),false);
  assert.equal(f.at(1.3).state,'hit');assert.equal(f.at(1.3).clipTime,1.8);
  assert.equal(f.at(1.7).state,'returning');assert.equal(f.at(5.3).state,'idle');
});
test('cancelling a partial raise reverses the source pose without a discontinuity',()=>{
  const f=fixture();f.d.start();const before=f.at(.5);f.d.cancel();
  assert.equal(f.at(.5).clipTime,before.clipTime);assert.equal(f.at(.5).weight,before.weight);
  assert.ok(f.at(.7).clipTime<before.clipTime);assert.equal(f.at(1).weight,0);
});
test('full raise, hold and release have continuous blend and source time',()=>{
  const f=fixture();f.d.start();let previous=f.at(0);
  for(let i=1;i<=1000;i++){
    const next=f.at(i/100);assert.ok(next.weight>=0&&next.weight<=1);
    assert.ok(Math.abs(next.weight-previous.weight)<.06);
    if(next.weight>0&&previous.weight>0)assert.ok(Math.abs(next.clipTime-previous.clipTime)<.02);
    previous=next;
  }
});
test('cancel during raising fades from current weight, model replacement resets immediately',()=>{
  const f=fixture();f.d.start();const before=f.at(.2).weight;f.d.cancel();
  assert.equal(f.at(.2).weight,before);assert.ok(f.at(.3).weight<before);
  f.d.cancel(true);assert.equal(f.at(.3).state,'idle');assert.equal(f.d.hit(),false);
});
test('render stalls expire waiting without requiring more animation frames',()=>{
  const f=fixture();f.d.start();assert.equal(f.at(60).state,'idle');assert.equal(f.d.hit(),false);
});
test('tap hit testing rejects misses, drags, long presses and non-primary buttons',()=>{
  const target={x:100,y:100,radius:28,visible:true};
  const tap={x:102,y:98,distance:2,duration:120,button:0};
  assert.equal(HighFive.isPalmTap(tap,target),true);
  for(const patch of [{x:170},{distance:12},{duration:800},{button:2}]) assert.equal(HighFive.isPalmTap({...tap,...patch},target),false);
  assert.equal(HighFive.isPalmTap(tap,{...target,visible:false}),false);
});
