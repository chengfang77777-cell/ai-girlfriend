const {test}=require('node:test');
const assert=require('node:assert/strict');
const bg=require('../assets/web/js/companion-background.js');

function fixture({reducedMotion=false,window,theme,motionMode}={}) {
  let hidden=false;
  const contexts=[];
  const makeCanvas=()=>{
    const gradient={addColorStop(){}};
    const ctx=new Proxy({draws:0,createLinearGradient:()=>gradient,createRadialGradient:()=>gradient,
      createImageData:(w,h)=>({data:new Uint8ClampedArray(w*h*4)})}, {
      get(target,key){return key in target?target[key]:(...args)=>{if(key==='drawImage')target.draws++;for(const arg of args)if(typeof arg==='number')assert.ok(Number.isFinite(arg),`non-finite ${String(key)}`);};},
      set(target,key,value){target[key]=value;return true;}
    });
    contexts.push(ctx);
    return {width:800,height:600,getContext:()=>ctx};
  };
  let seed=9;
  const random=()=>((seed=(seed*1664525+1013904223)>>>0)/4294967296);
  const engine=bg.create(makeCanvas(),{createCanvas:makeCanvas,random,reducedMotion,window,theme,motionMode,isHidden:()=>hidden,width:800,height:600,dpr:1});
  return {engine,contexts,hide:value=>hidden=value};
}

test('all eight existing presets and legacy aliases resolve; unknown values fall back',()=>{
  const {engine}=fixture();
  for(const [id,alias] of Object.entries(bg.ALIASES)) {
    engine.setTheme(id);assert.equal(engine.getState().id,id);
    engine.setTheme(alias);assert.equal(engine.getState().id,id);
    engine.frame(0);
  }
  assert.equal(Object.keys(bg.PRESETS).length,8);
  engine.setTheme('missing');assert.equal(engine.getState().id,'dreamy_starry');
});

test('saved theme and explicit motion are applied before the first frame',()=>{
  const {engine}=fixture({theme:'sakura',motionMode:'gentle',reducedMotion:true});
  assert.equal(engine.getState().id,'sakura_falling');
  assert.equal(engine.getState().motionMode,'gentle');
  assert.equal(engine.getState().reducedMotion,false);
  assert.equal(engine.getState().transition,1);
  engine.frame(0);engine.frame(50);
  assert.ok(engine.getState().time>0);
});

test('motion advances by elapsed seconds at both 30 and 60 Hz',()=>{
  const slow=fixture().engine,fast=fixture().engine;
  slow.frame(0);fast.frame(0);
  for(let i=1;i<=30;i++)slow.frame(i*1000/30);
  for(let i=1;i<=60;i++)fast.frame(i*1000/60);
  assert.ok(Math.abs(slow.getState().time-fast.getState().time)<.00001);
  assert.ok(Math.abs(slow.getState().time-1)<.00001);
  assert.ok(fast.getState().frames<=32,'background must not repaint at avatar frame rate');
});

test('theme transitions finish, can be interrupted, and no-op selections preserve particles',()=>{
  const {engine}=fixture();engine.frame(0);engine.frame(50);
  engine.setTheme('sakura_falling');assert.ok(engine.getState().transition<1);
  for(let i=1;i<=10;i++)engine.frame(50+i*50);
  engine.setTheme('ice_world');assert.equal(engine.getState().id,'ice_world');
  for(let i=1;i<=35;i++)engine.frame(550+i*50);
  assert.equal(engine.getState().transition,1);
  const state=engine.getState();engine.setTheme('ice_world');
  assert.equal(engine.getState().time,state.time);
  assert.equal(engine.getState().transition,1);
});

test('resize bounds high-DPI cost and draws every preset with finite coordinates',()=>{
  const {engine}=fixture();
  for(const id of Object.keys(bg.PRESETS)) {
    engine.setTheme(id);
    engine.resize(3840,2160,3);
    assert.ok(engine.getState().pixels<=1800000);
    assert.ok(engine.getState().particles<=100);
    engine.frame(100);engine.frame(200);
    engine.resize(0,0,2);engine.frame(300);
    engine.resize(390,700,1.5);engine.frame(400);
  }
});

test('reduced motion stays static and theme changes remain visible immediately',()=>{
  const {engine}=fixture({reducedMotion:true});engine.frame(0);
  const before=engine.getState();
  engine.frame(50);engine.frame(1000);
  assert.equal(engine.getState().frames,before.frames);
  assert.equal(engine.getState().time,0);
  engine.setTheme('cozy_room');engine.frame(1100);
  assert.equal(engine.getState().id,'cozy_room');
  assert.equal(engine.getState().transition,1);
  assert.equal(engine.getState().frames,before.frames+1);
  engine.setReducedMotion(false);engine.frame(1200);engine.frame(1250);
  assert.ok(engine.getState().time>0);
});

test('hidden documents pause without a jump and study motion settles gently',()=>{
  const {engine,hide}=fixture();engine.frame(0);engine.frame(100);
  hide(true);engine.frame(200);const before=engine.getState();engine.frame(60000);
  assert.equal(engine.getState().frames,before.frames);
  hide(false);engine.frame(60100);
  assert.equal(engine.getState().time,before.time);
  engine.setQuiet(true);
  for(let i=1;i<=60;i++)engine.frame(60100+i*50);
  assert.ok(engine.getState().motion<.35);
  engine.dispose();const disposed=engine.getState();engine.frame(64000);
  assert.equal(engine.getState().frames,disposed.frames);
});

test('explicit motion choices stay authoritative across system preference changes',()=>{
  let changed;
  const preference={matches:true,addEventListener:(_,handler)=>changed=handler,removeEventListener(){}};
  const {engine}=fixture({reducedMotion:true,window:{matchMedia:()=>preference}});
  engine.setMotionMode('gentle');assert.equal(engine.getState().reducedMotion,false);
  changed({matches:true});assert.equal(engine.getState().reducedMotion,false);
  engine.setMotionMode('system');assert.equal(engine.getState().reducedMotion,true);
  preference.matches=false;changed({matches:false});assert.equal(engine.getState().reducedMotion,false);
  engine.setMotionMode('still');changed({matches:false});assert.equal(engine.getState().reducedMotion,true);
});

function interactiveFixture(options={}) {
  const handlers=new Map();
  const window={addEventListener:(name,handler,options)=>{assert.equal(options.passive,true);handlers.set(name,handler);},
    removeEventListener:name=>handlers.delete(name)};
  const setup=fixture({...options,window});
  const emit=(name,values={})=>handlers.get(name)?.({clientX:200,clientY:200,
    button:0,isPrimary:true,pointerId:1,timeStamp:100,...values});
  return {...setup,emit,handlers};
}

test('primary short clicks create bounded warm effects, expire, and never intercept input',()=>{
  const {engine,emit}=interactiveFixture();engine.frame(0);
  for(let i=0;i<30;i++) {
    emit('pointerdown');emit('pointerup',{timeStamp:180});
  }
  assert.ok(engine.getState().blooms>0);
  assert.ok(engine.getState().blooms<=6);
  for(let i=1;i<=40;i++)engine.frame(i*100);
  assert.equal(engine.getState().blooms,0);
  const before=engine.getState().frames;engine.dispose();
  emit('pointerdown');emit('pointerup');engine.frame(5000);
  assert.equal(engine.getState().frames,before);
});

test('dragging, long presses and non-primary buttons never emit click effects',()=>{
  const {engine,emit}=interactiveFixture();
  emit('pointerdown');emit('pointerup',{clientX:260});
  emit('pointerdown');emit('pointermove',{clientX:260});emit('pointerup');
  emit('pointerdown');emit('pointerup',{timeStamp:800});
  emit('pointerdown',{button:2});emit('pointerup',{button:2});
  emit('pointerdown',{isPrimary:false});emit('pointerup',{isPrimary:false});
  assert.equal(engine.getState().blooms,0);
});

test('hover trails stay bounded, fade, and active effects clear for study/still modes',()=>{
  const {engine,emit}=interactiveFixture();engine.frame(0);
  for(let i=1;i<=30;i++) {
    engine.frame(i*50);emit('pointermove',{clientX:100+i*6});
  }
  assert.ok(engine.getState().trail>0);
  assert.ok(engine.getState().trail<=14);
  emit('pointerdown');emit('pointerup',{timeStamp:180});
  engine.setQuiet(true);
  assert.equal(engine.getState().blooms,0);assert.equal(engine.getState().trail,0);
  engine.setQuiet(false);emit('pointermove');
  emit('pointerdown');emit('pointerup',{timeStamp:180});
  engine.setMotionMode('still');
  assert.equal(engine.getState().blooms,0);assert.equal(engine.getState().trail,0);
  assert.equal(engine.getState().hover,0);
  engine.setMotionMode('gentle');emit('pointermove');
  for(let i=31;i<=55;i++)engine.frame(i*50);
  assert.equal(engine.getState().trail,0);
});

test('hover light eases in, leaves smoothly, and still/study modes suppress blooms',()=>{
  const {engine,emit}=interactiveFixture();engine.frame(0);
  emit('pointermove');
  for(let i=1;i<=20;i++)engine.frame(i*50);
  assert.ok(engine.getState().hover>.5);
  emit('pointerleave');
  for(let i=21;i<=60;i++)engine.frame(i*50);
  assert.ok(engine.getState().hover<.05);
  engine.setQuiet(true);emit('pointerdown');emit('pointerup',{timeStamp:180});
  assert.equal(engine.getState().blooms,0);
  engine.setQuiet(false);engine.setMotionMode('still');
  const before=engine.getState().frames;
  emit('pointermove');emit('pointerdown');emit('pointerup',{timeStamp:180});
  engine.frame(4000);const settled=engine.getState().frames;
  engine.frame(5000);assert.equal(engine.getState().frames,settled);
  assert.ok(settled<=before+1);assert.equal(engine.getState().blooms,0);
});
