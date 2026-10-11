const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const Emotion = require('../assets/web/js/emotion-driver.js');
function manager(names = ['happy', 'sad', 'angry', 'relaxed', 'Surprised', 'aa', 'blink']) {
  const values = {aa: .4, blink: .2};
  return {expressionMap: Object.fromEntries(names.map(n => [n, {}])), values,
    setValue(n,v) { assert.ok(n in this.expressionMap); values[n] = v; }};
}
function advance(d, em, seconds, speaking = false) {
  for (let i=0;i<Math.round(seconds*60);i++) d.update(em, 1/60, speaking);
}
function faceValues(em) {
  return Object.entries(em.values).filter(([n]) => !['aa', 'blink'].includes(n)).map(([,v])=>v);
}
test('startup is exactly neutral without a permanent smile', () => {
  const em=manager(), d=Emotion.createDriver(); advance(d,em,20);
  assert.ok(faceValues(em).every(v => v === 0));
});
test('all eight moods give a restrained short pulse and return to exact neutral', () => {
  assert.equal(Object.keys(Emotion.PROFILES).length, 8);
  for (const mood of Object.keys(Emotion.PROFILES).filter(m => m !== 'neutral')) {
    const em=manager(), d=Emotion.createDriver(); d.setEmotion(mood);
    advance(d,em,1);
    const peak=Math.max(...faceValues(em));
    assert.ok(peak > .20 && peak <= .45, `${mood}: ${peak}`);
    advance(d,em,1.7);
    assert.ok(Math.max(...faceValues(em)) < peak*.7, `${mood} should fade`);
    advance(d,em,1.3);
    assert.ok(faceValues(em).every(v => v === 0), `${mood} should settle`);
    assert.equal(em.values.aa,.4); assert.equal(em.values.blink,.2);
  }
});
test('long speech never holds a smile and speech reduces mouth distortion', () => {
  const em=manager(), d=Emotion.createDriver(); d.setEmotion('happy'); advance(d,em,1);
  const resting=em.values.happy; advance(d,em,.3,true);
  assert.ok(em.values.happy < resting && em.values.happy > .20);
  for(let i=0;i<1200;i++) { em.values.happy=.9; d.update(em,1/60,true); }
  assert.equal(em.values.happy,0); assert.equal(em.values.aa,.4);
});
test('consecutive replies with the same mood each restart a brief pulse', () => {
  const em=manager(), d=Emotion.createDriver(); d.setEmotion('happy'); advance(d,em,4);
  assert.equal(em.values.happy,0);
  d.setEmotion('happy'); d.update(em,1/60,false);
  assert.ok(em.values.happy > 0 && em.values.happy < .05);
  advance(d,em,1); assert.ok(em.values.happy > .15);
  advance(d,em,3); assert.equal(em.values.happy,0);
});
test('case insensitive surprise alias and shy fallback still work', () => {
  const em=manager(), d=Emotion.createDriver();
  d.setEmotion(' SURPRISED '); advance(d,em,1); assert.ok(em.values.Surprised > .1);
  const fallback=manager(['JOY','SORROW','aa','blink']), shy=Emotion.createDriver();
  shy.setEmotion(' SHY '); advance(shy,fallback,1);
  assert.ok(fallback.values.JOY > .05);
  shy.setEmotion('bad input'); advance(shy,fallback,2);
  assert.ok(faceValues(fallback).every(v => v === 0));
});
test('changing mood eases the old expression away', () => {
  const em=manager(), d=Emotion.createDriver(); d.setEmotion('angry'); advance(d,em,1);
  const before=em.values.angry; d.setEmotion('sad'); d.update(em,1/60,false);
  assert.ok(em.values.angry > 0 && em.values.angry < before);
  assert.ok(em.values.sad > 0 && em.values.sad < .05);
});
test('each response triggers exactly one facial pulse, even for repeated moods', async () => {
  const html=fs.readFileSync(require.resolve('../assets/web/vrm_viewer.html'),'utf8');
  const source=html.slice(html.indexOf('async function triggerAction('), html.indexOf('// 兼容旧入口'));
  const moods=[];
  const context=vm.createContext({highFive:null,console:{log(){}}, ACTION_MAP:{}, EMOTION_EXPRESSIONS:Emotion.PROFILES,
    window:{EmotionDriver:Emotion}, _isGreetingDone:true, setEmotion:e=>moods.push(e)});
  vm.runInContext(source, context);
  await context.triggerAction('talk','happy'); await context.triggerAction('talk','happy');
  assert.deepEqual(moods,['happy','happy']);
});


test('wall clock expires an expression despite rendering stalls', () => {
  let time=0;
  const em=manager(), d=Emotion.createDriver({now:()=>time});
  d.setEmotion('happy');
  for(let i=0;i<60;i++) { time+=1/60; d.update(em,1/60,false); }
  assert.ok(em.values.happy>.15);
  time=10; d.update(em,1/60,false);
  assert.equal(em.values.happy,0);
});

test('every mood is visible during speech without touching mouth or blink', () => {
  for (const mood of Object.keys(Emotion.PROFILES).filter(m => m !== 'neutral')) {
    const em=manager(), d=Emotion.createDriver(); d.setEmotion(mood);
    advance(d,em,1,true);
    assert.ok(Math.max(...faceValues(em)) > .15, `${mood} is too faint during speech`);
    assert.equal(em.values.aa,.4); assert.equal(em.values.blink,.2);
  }
});

test('delayed audio renews the matching reply once then fades during long speech', () => {
  for (const delay of [8,30]) {
    let time=0;
    const em=manager(), d=Emotion.createDriver({now:()=>time});
    d.setEmotion('happy','reply-1');
    time=delay; d.update(em,1/60,false);
    assert.equal(em.values.happy,0);
    assert.equal(typeof d.startSpeech, 'function');
    assert.equal(d.startSpeech('reply-1'),true);
    for(let i=0;i<60;i++) {time+=1/60;d.update(em,1/60,true);}
    assert.ok(em.values.happy>.20);
    time+=30; d.update(em,1/60,true);
    assert.equal(em.values.happy,0);
    assert.equal(d.startSpeech('reply-1'),false, 'replay cannot revive the old mood');
  }
});

test('new reply or cancellation rejects stale audio mood tokens', () => {
  const em=manager(), d=Emotion.createDriver();
  d.setEmotion('happy','old'); d.setEmotion('sad','new');
  assert.equal(typeof d.startSpeech, 'function');
  assert.equal(d.startSpeech('old'),false);
  assert.equal(d.startSpeech('new'),true);
  d.setEmotion('happy','cancelled'); d.setEmotion('neutral');
  assert.equal(d.startSpeech('cancelled'),false);
  d.setEmotion('neutral','neutral-reply'); d.startSpeech('neutral-reply');
  advance(d,em,1,true);
  assert.ok(faceValues(em).every(v=>v===0));
});

test('both model loading entry points cancel the previous reply before asynchronous work', async () => {
  const html=fs.readFileSync(require.resolve('../assets/web/vrm_viewer.html'),'utf8');
  const source=html.slice(html.indexOf('async function loadModel('),html.indexOf('function _applyPose('));
  const em=manager(), d=Emotion.createDriver();
  const cancellations=[];
  const context=vm.createContext({_bodyRequest:0,_fades:[],_clipCache:{},highFive:{cancel:immediate=>cancellations.push(immediate)},currentVrm:null, setEmotion:value=>d.setEmotion(value),
    fetch:async()=>{throw new Error('test load');},
    loader:{parseAsync:async()=>{throw new Error('test load');}}, sendToFlutter(){}});
  vm.runInContext(source,context);
  for(const entry of ['loadModel','loadModelFromBuffer']) {
    d.setEmotion('happy','old-role'); advance(d,em,1);
    await context[entry]('model');
    assert.equal(d.startSpeech('old-role'),false,entry);
    advance(d,em,2);
    assert.ok(faceValues(em).every(v=>v===0),entry);
  }
  assert.deepEqual(cancellations,[true,true]);
});

test('explicit neutral emotion is preserved even when the body action is happy', async () => {
  const html=fs.readFileSync(require.resolve('../assets/web/vrm_viewer.html'),'utf8');
  const source=html.slice(html.indexOf('async function triggerAction('), html.indexOf('// 兼容旧入口'));
  const moods=[];
  const context=vm.createContext({highFive:null,console:{log(){}}, ACTION_MAP:{happy:{emotion:'happy'}},
    EMOTION_EXPRESSIONS:Emotion.PROFILES, _isGreetingDone:false,
    setEmotion:(e,id)=>moods.push([e,id])});
  vm.runInContext(source,context);
  await context.triggerAction('happy','neutral','reply');
  assert.deepEqual(moods,[['neutral','reply']]);
});

test('neutral talk clears a role reaction without entering conversation or stopping idle', async () => {
  const html=fs.readFileSync(require.resolve('../assets/web/vrm_viewer.html'),'utf8');
  const source=html.slice(html.indexOf('async function triggerAction('), html.indexOf('// 兼容旧入口'));
  const d=Emotion.createDriver(); d.setEmotion('happy','previous-role');
  const context=vm.createContext({highFive:null,console:{log(){}}, ACTION_MAP:{},
    EMOTION_EXPRESSIONS:Emotion.PROFILES, _isGreetingDone:true, _isInConversation:false,
    setEmotion:(e,id)=>d.setEmotion(e,id), stopIdleTimer(){throw new Error('idle must continue');}});
  vm.runInContext(source,context);
  await context.triggerAction('talk','neutral',null);
  assert.equal(d.startSpeech('previous-role'),false);
  assert.equal(context._isInConversation,false);
});
