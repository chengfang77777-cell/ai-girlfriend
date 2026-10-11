(function(root,factory){
  const api=factory();
  if(typeof module==='object'&&module.exports) module.exports=api;
  else root.HighFive=api;
})(typeof window!=='undefined'?window:globalThis,function(){
  'use strict';
  const START=.95,HOLD=1.8,END=4.6666665,BLEND=.30,RELEASE=.9,WAIT=6,HIT=.15;
  const ease=x=>{x=Math.max(0,Math.min(1,x));return x*x*(3-2*x);};
  function createTimeline({now,onState=()=>{},endTime=END}){
    let state='idle',since=0,reverseFrom=null,reverseWeight=1;
    function enter(next,time){state=next;since=time;onState(next);}
    function tick(){
      const t=now(),returnDuration=reverseFrom===null?endTime-HOLD+RELEASE:.4;
      for(let i=0;i<4;i++){
        if(state==='raising'&&t-since>=HOLD-START)enter('waiting',since+HOLD-START);
        else if(state==='waiting'&&t-since>=WAIT)enter('returning',since+WAIT);
        else if(state==='hit'&&t-since>=HIT)enter('returning',since+HIT);
        else if(state==='returning'&&t-since>=returnDuration)enter('idle',since+returnDuration);
        else break;
      }
      const age=Math.max(0,t-since);
      let clipTime=HOLD,weight=1;
      if(state==='idle'){clipTime=START;weight=0;}
      else if(state==='raising'){clipTime=Math.min(HOLD,START+age);weight=ease(age/BLEND);}
      else if(state==='returning'){
        if(reverseFrom!==null){clipTime=reverseFrom+(START-reverseFrom)*ease(age/.4);weight=reverseWeight*(1-ease(age/.4));}
        else{clipTime=Math.min(endTime,HOLD+age);weight=1-ease((age-(endTime-HOLD))/RELEASE);}
      }
      return {state,clipTime,weight,releaseReady:state==='returning'&&reverseFrom===null&&age>=endTime-HOLD};
    }
    return {tick,start(){if(tick().state!=='idle')return false;reverseFrom=null;enter('raising',now());return true;},
      hit(){if(tick().state!=='waiting')return false;enter('hit',now());return true;},
      cancel(immediate=false){const s=tick();if(s.state==='idle')return;
        if(immediate)enter('idle',now());
        else if(s.state!=='returning'){
          if(s.state==='raising'){reverseFrom=s.clipTime;reverseWeight=s.weight;}
          enter('returning',now());
        }
      }};
  }
  function isPalmTap(tap,target){return !!target?.visible&&tap.button===0&&tap.duration<=600&&tap.distance<=7&&
    Math.hypot(tap.x-target.x,tap.y-target.y)<=target.radius;}

  // Sample the exact retargeted greeting, including body and fingers. Do not
  // solve or rotate the arm independently of its authored shoulder/elbow roll.
  function createPoseSampler(THREE,vrm,clip){
    const root=vrm.humanoid.normalizedHumanBonesRoot||vrm.scene;
    const channels=[];
    for(const track of clip.tracks){
      const match=/^(.*)\.(quaternion|position)$/.exec(track.name);if(!match)continue;
      const node=root.getObjectByName(match[1])||vrm.scene.getObjectByName(match[1]);if(!node)continue;
      channels.push({node,key:match[2],interpolant:track.createInterpolant(),base:null,
        target:match[2]==='quaternion'?new THREE.Quaternion():new THREE.Vector3()});
    }
    function restore(){for(const c of channels){if(c.base)c.node[c.key].copy(c.base);c.base=null;}}
    return {valid:channels.length>0,restore,sample(time,weight){
      for(const c of channels){
        c.base=c.node[c.key].clone();c.target.fromArray(c.interpolant.evaluate(time));
        if(c.key==='quaternion')c.node.quaternion.slerpQuaternions(c.base,c.target,weight);
        else c.node.position.lerpVectors(c.base,c.target,weight);
      }
    }};
  }
  function createRig(THREE,{canvas,camera,getVrm,getGreetingClip,isReady=()=>true,onState=()=>{},onHit=()=>{},onRelease}){
    const V=()=>new THREE.Vector3();
    let rig=null,down=null,palm=null;
    const marker=document.createElement('div');
    marker.setAttribute('aria-hidden','true');
    marker.style.cssText='position:fixed;display:none;pointer-events:none;width:50px;height:50px;border:2px solid #ffacd5;border-radius:50%;background:#ffffff22;box-shadow:0 0 18px #ff96c577;transform:translate(-50%,-50%);z-index:4;overflow:visible';
    const label=document.createElement('span');label.textContent='点掌心 · 击掌';
    label.style.cssText='position:absolute;top:57px;left:50%;transform:translateX(-50%);white-space:nowrap;padding:5px 9px;border-radius:12px;color:white;background:#38283dd9;font:13px sans-serif';
    marker.appendChild(label);document.body.appendChild(marker);
    const stateChanged=s=>{if(s!=='waiting'&&s!=='hit')marker.style.display='none';onState(s);};
    let timeline=createTimeline({now:()=>performance.now()/1000,onState:stateChanged});
    function restore(){rig?.sampler.restore();}
    function bind(){
      const vrm=getVrm(),clip=getGreetingClip();
      if(rig?.vrm===vrm&&rig?.clip===clip)return rig;
      restore();rig=null;
      if(!vrm?.humanoid||!clip)return null;
      const hand=vrm.humanoid.getNormalizedBoneNode('rightHand');if(!hand)return null;
      const sampler=createPoseSampler(THREE,vrm,clip);if(!sampler.valid)return null;
      rig={vrm,clip,hand,middle:vrm.humanoid.getNormalizedBoneNode('rightMiddleProximal'),sampler};
      timeline=createTimeline({now:()=>performance.now()/1000,onState:stateChanged,endTime:clip.duration});
      return rig;
    }
    function project(){
      if(!rig)return null;
      const center=rig.hand.getWorldPosition(V());
      if(rig.middle)center.lerp(rig.middle.getWorldPosition(V()),.55);
      const p=center.project(camera),rect=canvas.getBoundingClientRect();
      return {x:rect.left+(p.x+1)*rect.width/2,y:rect.top+(1-p.y)*rect.height/2,radius:32,
        visible:p.z>-1&&p.z<1&&Math.abs(p.x)<.96&&Math.abs(p.y)<.92};
    }
    function update(){
      const s=timeline.tick();
      if(s.releaseReady&&rig&&!rig.released&&onRelease){
        restore();rig.released=true;
        // Transfer the final authored pose to the same mixer used at startup.
        // That mixer restarts idle from its beginning and owns the entire fade.
        onRelease(rig.clip);
      }
      if(rig?.released){palm=null;marker.style.display='none';return;}
      if(!s.weight){palm=null;return;}
      if(!rig||rig.vrm!==getVrm()){timeline.cancel(true);return;}
      rig.sampler.sample(s.clipTime,s.weight);
      rig.vrm.scene.updateMatrixWorld(true);palm=project();
      if((s.state==='waiting'||s.state==='hit')&&palm?.visible){
        marker.style.display='block';marker.style.left=palm.x+'px';marker.style.top=palm.y+'px';
        label.textContent=s.state==='hit'?'啪！':'点掌心 · 击掌';
        marker.style.background=s.state==='hit'?'#ffb7dbaa':'#ffffff22';
      }else marker.style.display='none';
    }
    let soundContext=null;
    function prepareSound(){try{soundContext??=new(window.AudioContext||window.webkitAudioContext)();void soundContext.resume().catch(()=>{});}catch(_){}}
    function impact(){
      try{
        prepareSound();if(!soundContext)return;
        const n=Math.floor(soundContext.sampleRate*.07),buffer=soundContext.createBuffer(1,n,soundContext.sampleRate),data=buffer.getChannelData(0);
        for(let i=0;i<n;i++)data[i]=(Math.random()*2-1)*Math.exp(-i/n*7)*.22;
        const source=soundContext.createBufferSource(),filter=soundContext.createBiquadFilter();
        filter.type='bandpass';filter.frequency.value=1800;filter.Q.value=.7;source.buffer=buffer;
        source.connect(filter);filter.connect(soundContext.destination);source.onended=()=>{source.disconnect();filter.disconnect();};source.start();
      }catch(_){}
    }
    canvas.addEventListener('pointerdown',e=>{down={id:e.pointerId,x:e.clientX,y:e.clientY,time:performance.now(),distance:0,button:e.button};});
    canvas.addEventListener('pointermove',e=>{if(down?.id===e.pointerId)down.distance=Math.max(down.distance,Math.hypot(e.clientX-down.x,e.clientY-down.y));});
    canvas.addEventListener('pointercancel',()=>{down=null;});
    canvas.addEventListener('pointerup',e=>{
      const tap=down;down=null;if(!tap||tap.id!==e.pointerId)return;
      tap.distance=Math.max(tap.distance,Math.hypot(e.clientX-tap.x,e.clientY-tap.y));
      if(isPalmTap({...tap,x:e.clientX,y:e.clientY,duration:performance.now()-tap.time},palm)&&timeline.hit()){
        impact();onHit();
      }
    });
    return {restore,update,start(){
        if(!isReady()||timeline.tick().state!=='idle'||!bind())return false;
        rig.released=false;
        prepareSound();return timeline.start();},
      cancel(immediate=false){down=null;timeline.cancel(immediate);if(immediate){restore();palm=null;rig=null;marker.style.display='none';}},
      get active(){return timeline.tick().state!=='idle';},snapshot(){return {...timeline.tick(),palm};}};
  }
  return {createTimeline,isPalmTap,createPoseSampler,createRig};
});
