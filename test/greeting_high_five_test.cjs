const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const HighFive=require('../assets/web/js/high-five.js');
const vm=require('node:vm');

test('high-five release uses exactly the startup greeting-to-idle mixer transition',async()=>{
  const html=fs.readFileSync(require.resolve('../assets/web/vrm_viewer.html'),'utf8');
  const release=html.match(/\/\/ BEGIN HIGH_FIVE_RELEASE([\s\S]*?)\/\/ END HIGH_FIVE_RELEASE/);
  assert.ok(release,'shared mixer handoff must replace the separate overlay fade');
  const THREE=await import('data:text/javascript;base64,'+Buffer.from(fs.readFileSync(require.resolve('../assets/web/js/three.module.js'))).toString('base64'));
  async function fixture(fromHighFive){
    const root=new THREE.Group(),bone=new THREE.Bone();bone.name='arm';root.add(bone);
    const greeting=new THREE.AnimationClip('greeting',4,[new THREE.VectorKeyframeTrack('arm.position',[0,4],[0,0,0,1,2,3])]);
    const idle=new THREE.AnimationClip('idle',3,[new THREE.VectorKeyframeTrack('arm.position',[0,3],[0,1,0,0,1,.2])]);
    const mixer=new THREE.AnimationMixer(root),greet=mixer.clipAction(greeting);
    const c=vm.createContext({THREE,currentVrm:{scene:root},_animationMixer:mixer,_currentAction:null,_currentAnimName:null,
      _bodyRequest:0,_pendingBodyAnimationLoads:0,_isAnimationPlaying:false,CROSSFADE:.6,
      ANIMATIONS:{greeting:'greeting',idle:'idle'},_clipCache:{greeting,idle},
      console:{log(){},error(){}},loadClip:async n=>n==='idle'?idle:greeting});
    vm.runInContext(html.slice(html.indexOf('const _fades = []'),html.indexOf('function stopAnimation(')),c);
    c.playIdleAnimation=()=>c.playAnimation('idle',true);
    vm.runInContext(release[1],c);
    if(fromHighFive){
      const old=mixer.clipAction(idle);old.play();mixer.update(1.4);c._currentAction=old;
      await c.finishHighFiveGreeting(greeting);
    }else{
      greet.reset().setLoop(THREE.LoopOnce,1).play();greet.clampWhenFinished=true;
      greet.time=greeting.duration;greet.paused=true;mixer.update(0);c._currentAction=greet;
      await c.playIdleAnimation();
    }
    const samples=[];
    for(let i=0;i<65;i++){c._updateFades(1/60);mixer.update(1/60);samples.push(bone.position.toArray());}
    return samples;
  }
  const actual=await fixture(true),expected=await fixture(false);
  actual.forEach((p,i)=>p.forEach((v,j)=>assert.ok(Math.abs(v-expected[i][j])<1e-8)));
});
test('high five pauses the greeting at the raised frame and resumes the same clip after a tap',()=>{
  let now=0;const d=HighFive.createTimeline({now:()=>now,endTime:4.6666665});
  d.start();now=.5;assert.equal(d.tick().clipTime,1.45);
  now=.9;assert.equal(d.tick().state,'waiting');assert.equal(d.tick().clipTime,1.8);
  now=3;assert.equal(d.tick().clipTime,1.8);assert.equal(d.hit(),true);
  now=3.65;assert.equal(d.tick().state,'returning');assert.ok(Math.abs(d.tick().clipTime-2.3)<1e-6);
  now=7;assert.equal(d.tick().state,'idle');
});
test('actual source clip rotations and translations are preserved, then original idle pose is restored',async()=>{
  const THREE=await import('data:text/javascript;base64,'+Buffer.from(fs.readFileSync(require.resolve('../assets/web/js/three.module.js'))).toString('base64'));
  const root=new THREE.Group(),bone=new THREE.Bone();bone.name='greetingArm';root.add(bone);
  const clip=new THREE.AnimationClip('greeting',2,[
    new THREE.QuaternionKeyframeTrack('greetingArm.quaternion',[0,2],[0,0,0,1,0,0,Math.sin(.5),Math.cos(.5)]),
    new THREE.VectorKeyframeTrack('greetingArm.position',[0,2],[0,0,0,0,1,0])]);
  const vrm={scene:root,humanoid:{normalizedHumanBonesRoot:root}};
  const sampler=HighFive.createPoseSampler(THREE,vrm,clip);bone.position.set(2,3,4);
  sampler.sample(1,1);
  assert.ok(bone.quaternion.angleTo(new THREE.Quaternion().fromArray(clip.tracks[0].createInterpolant().evaluate(1)))<1e-7);
  assert.deepEqual(bone.position.toArray(),[0,.5,0]);
  sampler.restore();assert.deepEqual(bone.position.toArray(),[2,3,4]);assert.equal(bone.quaternion.w,1);
});
