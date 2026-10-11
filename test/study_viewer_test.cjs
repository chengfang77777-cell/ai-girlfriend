const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const html=fs.readFileSync(require.resolve('../assets/web/vrm_viewer.html'),'utf8');
test('study focus suppresses interruptions; completion chimes and celebrates without TTS',()=>{
  const notes=[],actions=[],faces=[];let idle=0,variants=0,cancels=0;
  class AudioContext {
    currentTime=10;destination={};resume(){return Promise.resolve();}
    createOscillator(){return {frequency:{},connect(){},disconnect(){},start:t=>notes.push(t),stop(){}};}
    createGain(){return {gain:{setValueAtTime(){},linearRampToValueAtTime(){},exponentialRampToValueAtTime(){}},connect(){},disconnect(){}};}
  }
  const c=vm.createContext({window:{AudioContext},_studyQuiet:false,_isGreetingDone:true,_isInConversation:true,
    highFive:{cancel:()=>cancels++},stopIdleTimer(){},clearIdleCycleTimer(){},
    setEmotion:e=>faces.push(e),playIdleAnimation:()=>idle++,scheduleIdleVariant:()=>variants++,
    triggerAction:(...args)=>actions.push(args)});
  vm.runInContext(html.slice(html.indexOf('let _studySound ='),html.indexOf('// Unified message sender')),c);
  c.window.setStudyQuiet(true);assert.equal(c._studyQuiet,true);assert.equal(idle,1);
  c.window.setStudyQuiet(true);assert.equal(idle,1);assert.deepEqual(faces,['neutral']);
  c.window.celebrateStudyCompletion('study:1');
  assert.equal(c._studyQuiet,false);assert.equal(cancels,2);assert.equal(variants,1);
  assert.deepEqual(notes,[10,10.22]);assert.deepEqual(actions,[['happy','happy','study:1']]);
});
test('a superseded body request does not start idle over its replacement',async()=>{
  let idle=0;
  const c=vm.createContext({highFive:null,console:{log(){}},ACTION_MAP:{happy:{anim:'happy',emotion:'happy'}},
    EMOTION_EXPRESSIONS:{happy:{}},setEmotion(){},_isGreetingDone:true,_isInConversation:false,
    stopIdleTimer(){},clearIdleCycleTimer(){},playAnimation:async()=>null,playIdleAnimation:()=>idle++});
  vm.runInContext(html.slice(html.indexOf('async function triggerAction('),html.indexOf('// 兼容旧入口')),c);
  await c.triggerAction('happy','happy');assert.equal(idle,0);
});
