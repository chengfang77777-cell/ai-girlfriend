(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.CompanionBackground = factory();
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  const TAU = Math.PI * 2;
  const ALIASES = Object.freeze({dreamy_starry:'stars', sakura_falling:'sakura',
    cozy_room:'warm_glow', gradient_glow:'glow', fresh_meadow:'fireflies',
    sunset_dusk:'sunrays', ice_world:'snowflakes', mystic_night:'nebula'});
  const PRESETS = Object.freeze({
    dreamy_starry:{colors:['#101e2b','#2a3e4a','#536763'],light:'177,210,207',accent:'122,168,175',kind:'stars',max:100,dark:true},
    sakura_falling:{colors:['#faf4f0','#eedfdf','#d5cfc9'],light:'255,246,225',accent:'213,163,172',kind:'petals',max:56},
    cozy_room:{colors:['#f7f0e3','#ead9bf','#c6baa7'],light:'255,244,214',accent:'218,176,125',kind:'dust',max:48},
    gradient_glow:{colors:['#edf1e8','#d1ddd4','#dbc9c9'],light:'245,246,218',accent:'171,196,183',kind:'dust',max:44},
    fresh_meadow:{colors:['#eff3e8','#d8e4d5','#96ae97'],light:'248,244,193',accent:'120,164,144',kind:'fireflies',max:48},
    sunset_dusk:{colors:['#e3c9bc','#d6a190','#889798'],light:'255,224,178',accent:'236,181,156',kind:'dust',max:44},
    ice_world:{colors:['#f2f6f4','#dbe9e9','#adbec6'],light:'248,253,255',accent:'156,188,205',kind:'snow',max:54},
    mystic_night:{colors:['#0d222d','#163e43','#2e5154'],light:'134,216,182',accent:'116,166,199',kind:'stars',max:72,dark:true}
  });
  const clamp = (v,lo,hi) => Math.max(lo,Math.min(hi,v));
  const smooth = v => {v=clamp(v,0,1);return v*v*(3-2*v);};
  const wrap = v => ((v % 1) + 1) % 1;
  const rgba = (rgb,alpha) => `rgba(${rgb},${alpha})`;
  const resolve = id => Object.hasOwn(PRESETS,id) ? id :
    Object.keys(ALIASES).find(key => ALIASES[key]===id) || 'dreamy_starry';

  function create(canvas, options={}) {
    const environment = options.window || (typeof window!=='undefined' ? window : null);
    const doc = options.document || canvas.ownerDocument;
    const createCanvas = options.createCanvas || (() => doc.createElement('canvas'));
    const random = options.random || Math.random;
    const hidden = options.isHidden || (() => !!doc?.hidden);
    const context = canvas.getContext('2d',{alpha:false});
    const base = createCanvas(), previous = createCanvas();
    const baseContext = base.getContext('2d',{alpha:false});
    const previousContext = previous.getContext('2d',{alpha:false});
    const sprites = new Map(), listeners=[];
    let width=1,height=1,ratio=1,id=resolve(options.theme),particles=[];
    let time=0,frames=0,lastTick=null,lastPaint=-Infinity,wasHidden=false;
    let transition=1,transitionElapsed=1.5,dirty=true,disposed=false;
    let quiet=false,motion=1,reduced=!!options.reducedMotion;
    let motionMode='system';
    let pointer={x:0,y:0},target={x:0,y:0};
    let hover=0,pointerInside=false,press=null,effectTime=0,lastTrail=-Infinity;
    let blooms=[],trail=[];
    const preference=environment?.matchMedia?.('(prefers-reduced-motion: reduce)');
    if (options.reducedMotion===undefined) reduced=!!preference?.matches;

    function listen(owner,event,handler) {
      if (!owner?.addEventListener) return;
      owner.addEventListener(event,handler,{passive:true});
      listeners.push(() => owner.removeEventListener(event,handler));
    }
    function glow(rgb) {
      if (sprites.has(rgb)) return sprites.get(rgb);
      const sprite=createCanvas();sprite.width=sprite.height=128;
      const ctx=sprite.getContext('2d');
      const gradient=ctx.createRadialGradient(64,64,0,64,64,64);
      gradient.addColorStop(0,rgba(rgb,.9));gradient.addColorStop(.18,rgba(rgb,.54));
      gradient.addColorStop(.52,rgba(rgb,.14));gradient.addColorStop(1,rgba(rgb,0));
      ctx.fillStyle=gradient;ctx.fillRect(0,0,128,128);
      sprites.set(rgb,sprite);return sprite;
    }
    function petal() {
      if (sprites.has('petal')) return sprites.get('petal');
      const sprite=createCanvas();sprite.width=64;sprite.height=48;
      const ctx=sprite.getContext('2d');
      const g=ctx.createLinearGradient(12,10,52,36);
      g.addColorStop(0,'#fff9f5');g.addColorStop(.5,'#e7b5c0');g.addColorStop(1,'#c9879b');
      ctx.fillStyle=g;ctx.beginPath();ctx.moveTo(8,24);
      ctx.bezierCurveTo(22,0,51,2,55,18);ctx.lineTo(48,22);
      ctx.lineTo(55,26);ctx.bezierCurveTo(50,42,25,47,8,24);ctx.fill();
      ctx.strokeStyle='rgba(255,248,242,.5)';ctx.lineWidth=1;
      ctx.beginPath();ctx.moveTo(10,24);ctx.quadraticCurveTo(32,18,48,22);ctx.stroke();
      sprites.set('petal',sprite);return sprite;
    }
    function bokeh(rgb) {
      const key=`bokeh:${rgb}`;
      if(sprites.has(key)) return sprites.get(key);
      const sprite=createCanvas();sprite.width=sprite.height=128;
      const ctx=sprite.getContext('2d');
      const g=ctx.createRadialGradient(64,64,0,64,64,64);
      // Filled, feathered lens disks: avoid hollow rings that read as bubbles.
      g.addColorStop(0,rgba(rgb,.33));g.addColorStop(.5,rgba(rgb,.31));
      g.addColorStop(.7,rgba(rgb,.27));g.addColorStop(.9,rgba(rgb,.09));
      g.addColorStop(1,rgba(rgb,0));
      ctx.fillStyle=g;ctx.fillRect(0,0,128,128);
      sprites.set(key,sprite);return sprite;
    }
    function ribbon(rgb,accent) {
      const key=`ribbon:${rgb}:${accent}`;
      if(sprites.has(key)) return sprites.get(key);
      const sprite=createCanvas();sprite.width=512;sprite.height=192;
      const ctx=sprite.getContext('2d');
      const g=ctx.createLinearGradient(0,0,512,0);
      g.addColorStop(0,rgba(rgb,0));g.addColorStop(.25,rgba(rgb,.65));
      g.addColorStop(.65,rgba(accent,.5));g.addColorStop(1,rgba(accent,0));
      // Blur only while making the reusable texture, never the full live frame.
      ctx.filter='blur(10px)';ctx.strokeStyle=g;ctx.lineCap='round';
      for(const [weight,alpha] of [[86,.12],[54,.16],[28,.18]]) {
        ctx.lineWidth=weight;ctx.globalAlpha=alpha;ctx.beginPath();
        ctx.moveTo(-20,104);ctx.bezierCurveTo(90,30,220,168,330,103);
        ctx.bezierCurveTo(405,57,470,55,532,94);ctx.stroke();
      }
      sprites.set(key,sprite);return sprite;
    }
    function grain() {
      if(sprites.has('grain')) return sprites.get('grain');
      const sprite=createCanvas();sprite.width=sprite.height=128;
      const ctx=sprite.getContext('2d'),data=ctx.createImageData(128,128);
      for(let i=0;i<data.data.length;i+=4) {
        const shade=random()<.5?0:255;
        data.data[i]=data.data[i+1]=data.data[i+2]=shade;
        data.data[i+3]=8+Math.floor(random()*8);
      }
      ctx.putImageData(data,0,0);sprites.set('grain',sprite);return sprite;
    }
    function light(ctx,x,y,r,rgb,alpha) {
      ctx.save();ctx.globalAlpha=alpha;ctx.drawImage(glow(rgb),x-r,y-r,r*2,r*2);ctx.restore();
    }
    function shape(ctx,fill,draw) {
      ctx.fillStyle=fill;ctx.beginPath();draw(ctx);ctx.closePath();ctx.fill();
    }
    function hills(ctx,color,y,depth) {
      shape(ctx,color,p=>{
        p.moveTo(0,height);p.lineTo(0,height*y);
        p.bezierCurveTo(width*.18,height*(y-depth),width*.3,height*(y+depth),width*.5,height*y);
        p.bezierCurveTo(width*.72,height*(y-depth),width*.86,height*(y-depth*.2),width,height*(y+depth*.5));
        p.lineTo(width,height);
      });
    }
    function paintBase() {
      const p=PRESETS[id],ctx=baseContext;
      ctx.setTransform(ratio,0,0,ratio,0,0);
      ctx.globalAlpha=1;
      const g=ctx.createLinearGradient(0,0,width*.18,height);
      p.colors.forEach((color,i)=>g.addColorStop(i/2,color));
      ctx.fillStyle=g;ctx.fillRect(0,0,width+1,height+1);
      // Broad, low-contrast illumination leaves breathing room around the face.
      light(ctx,width*.52,height*.4,Math.max(width,height)*.66,p.light,p.dark?.19:.32);
      switch(id) {
        case 'sakura_falling':
          hills(ctx,'rgba(250,245,237,.42)',.78,.04);
          ctx.strokeStyle='rgba(127,105,102,.10)';ctx.lineWidth=width*.006;
          ctx.beginPath();ctx.moveTo(width*1.08,-height*.06);
          ctx.bezierCurveTo(width*.91,height*.16,width*.85,height*.11,width*.76,height*.22);ctx.stroke();
          ctx.lineWidth=width*.0025;ctx.beginPath();ctx.moveTo(width*.96,height*.07);
          ctx.quadraticCurveTo(width*.81,height*.035,width*.72,height*.05);ctx.stroke();
          for(let i=0;i<13;i++) {
            const x=width*(.73+i*.022),y=height*(.06+Math.sin(i*.7)*.028);
            light(ctx,x,y,width*.025,'235,186,192',.27);
          }
          break;
        case 'cozy_room': {
          const x=width*.075,y=height*.1,w=width*.245,h=height*.43;
          const windowLight=ctx.createLinearGradient(x,y,x+w,y+h);
          windowLight.addColorStop(0,'rgba(255,252,235,.90)');windowLight.addColorStop(1,'rgba(255,250,228,.20)');
          ctx.fillStyle=windowLight;ctx.fillRect(x,y,w,h);
          ctx.strokeStyle='rgba(121,107,83,.15)';ctx.lineWidth=3;
          ctx.strokeRect(x,y,w,h);ctx.beginPath();ctx.moveTo(x+w*.5,y);ctx.lineTo(x+w*.5,y+h);
          ctx.moveTo(x,y+h*.52);ctx.lineTo(x+w,y+h*.52);ctx.stroke();
          const beam=ctx.createLinearGradient(x,y+h*.3,width*.78,height);
          beam.addColorStop(0,'rgba(255,246,215,.32)');beam.addColorStop(1,'rgba(255,246,215,0)');
          shape(ctx,beam,p=>{p.moveTo(x,y+h);p.lineTo(x+w,y+h);p.lineTo(width*.95,height);p.lineTo(width*.4,height);});
          hills(ctx,'rgba(114,108,90,.035)',.86,.018);
          break;
        }
        case 'fresh_meadow':
          hills(ctx,'rgba(117,153,132,.16)',.68,.055);
          hills(ctx,'rgba(91,130,109,.13)',.85,.042);
          break;
        case 'sunset_dusk':
          light(ctx,width*.23,height*.54,Math.min(width,height)*.32,'255,223,172',.58);
          ctx.fillStyle='rgba(255,240,207,.65)';ctx.beginPath();
          ctx.arc(width*.23,height*.54,Math.min(width,height)*.055,0,TAU);ctx.fill();
          hills(ctx,'rgba(102,121,127,.17)',.71,.05);
          hills(ctx,'rgba(93,117,124,.11)',.86,.033);
          break;
        case 'ice_world':
          hills(ctx,'rgba(249,254,253,.57)',.68,.075);
          hills(ctx,'rgba(216,232,234,.47)',.82,.05);
          break;
        case 'dreamy_starry':
        case 'mystic_night':
          hills(ctx,'rgba(8,26,34,.22)',.88,.028);
          break;
      }
      // A quiet edge falloff gives the stage depth without tinting the model.
      const vignette=ctx.createRadialGradient(width*.5,height*.4,width*.15,width*.5,height*.4,Math.max(width,height)*.85);
      vignette.addColorStop(0,'rgba(31,48,43,0)');vignette.addColorStop(1,p.dark?'rgba(5,19,28,.36)':'rgba(78,88,71,.12)');
      ctx.fillStyle=vignette;ctx.fillRect(0,0,width+1,height+1);
      // Fixed fine grain dithers shallow gradients without sparkling or adding
      // work to the live animation; it is baked into this cached scenery.
      ctx.save();ctx.globalCompositeOperation='soft-light';
      ctx.fillStyle=ctx.createPattern(grain(),'repeat');ctx.fillRect(0,0,width+1,height+1);ctx.restore();
    }
    function seedParticles() {
      const desired=clamp(Math.round(width*height/(PRESETS[id].kind==='stars'?7500:10500)),24,PRESETS[id].max);
      while(particles.length<desired) particles.push({u:random(),v:random(),depth:.2+random()*.8,
        phase:random()*TAU,drift:(random()-.5)*.026,fall:.025+random()*.035});
      particles.length=desired;
    }
    function resize(w,h,dpr=1) {
      if (disposed) return;
      width=Math.max(1,Number.isFinite(w)?w:1);height=Math.max(1,Number.isFinite(h)?h:1);
      ratio=Math.min(clamp(dpr||1,.25,1.5),Math.sqrt(1800000/(width*height)));
      for(const surface of [canvas,base,previous]) {
        surface.width=Math.max(1,Math.floor(width*ratio));surface.height=Math.max(1,Math.floor(height*ratio));
      }
      transition=1;transitionElapsed=1.5;
      seedParticles();paintBase();dirty=true;
    }
    function setTheme(value,immediate=false) {
      if (disposed) return id;
      const next=resolve(value);
      if (id===next) return id;
      const fade=frames>0&&!reduced&&!immediate;
      if(fade) {
        previousContext.setTransform(1,0,0,1,0,0);
        previousContext.globalAlpha=1;previousContext.drawImage(canvas,0,0);
      }
      id=next;particles=[];blooms=[];trail=[];seedParticles();paintBase();
      transition=fade?0:1;transitionElapsed=fade?0:1.5;dirty=true;
      return id;
    }
    function drawAtmosphere(ctx,p) {
      const strength=quiet?.3:1,dx=pointer.x*22*strength,dy=pointer.y*14*strength;
      for(let i=0;i<3;i++) {
        const phase=time*(.18-i*.025)+i*2.1;
        const x=width*(.15+i*.34+Math.sin(phase)*.09)+dx*(i+1)*.5;
        const y=height*(.21+i*.12+Math.cos(phase*.7)*.065)+dy;
        light(ctx,x,y,Math.max(width,height)*(.38+i*.025),i%2?p.accent:p.light,p.dark?.24:.29);
      }
      if(id==='gradient_glow'||id==='mystic_night'||id==='sunset_dusk') {
        const dark=id==='mystic_night';
        for(let i=0;i<3;i++) {
          const y=height*(.22+i*.18)+Math.sin(time*.19+i)*height*.07;
          ctx.save();ctx.translate(width*.5+Math.sin(time*.14+i)*width*.075+dx,y+dy);
          ctx.rotate(Math.sin(time*.12+i)*.09);ctx.globalAlpha=dark?1:.85;
          ctx.drawImage(ribbon(p.light,p.accent),-width*.65,-height*.2,width*1.3,height*.4);ctx.restore();
        }
      }
      if(id==='cozy_room') drawCurtains(ctx,dx);
      if(id==='fresh_meadow') {
        ctx.strokeStyle='rgba(65,105,83,.24)';ctx.lineWidth=1.2;
        for(let i=0;i<34;i++) {
          const x=width*(i<17?i*.018:.72+(i-17)*.018),h=height*(.035+(i%5)*.009);
          const sway=Math.sin(time*.85+i*.5)*h*.28+dx*.15;
          ctx.beginPath();ctx.moveTo(x,height);
          ctx.quadraticCurveTo(x+4+sway,height-h*.7,x+8+sway,height-h);ctx.stroke();
        }
      }
    }
    function drawCurtains(ctx,dx) {
      const y=height*.085,h=height*.49;
      for(const [x,direction] of [[width*.058,1],[width*.335,-1]]) {
        const w=width*.076,sway=Math.sin(time*.7+direction)*width*.018+dx*.12;
        const gradient=ctx.createLinearGradient(x,y,x+w*direction,y);
        gradient.addColorStop(0,'rgba(255,253,241,.55)');
        gradient.addColorStop(.5,'rgba(255,253,241,.22)');
        gradient.addColorStop(1,'rgba(255,253,241,.04)');
        shape(ctx,gradient,p=>{
          p.moveTo(x,y);p.lineTo(x+w*direction,y);
          p.bezierCurveTo(x+w*direction+sway,y+h*.4,x+w*direction+sway*.6,y+h*.75,x+w*direction+sway,y+h);
          p.quadraticCurveTo(x+w*direction*.4+sway,y+h*1.02,x+sway*.3,y+h*.96);
          p.bezierCurveTo(x+sway,y+h*.6,x+sway*.4,y+h*.3,x,y);
        });
        ctx.strokeStyle='rgba(255,252,231,.28)';ctx.lineWidth=1;
        for(let i=1;i<=3;i++) {
          const fold=x+w*direction*i/4;ctx.beginPath();ctx.moveTo(fold,y);
          ctx.bezierCurveTo(fold+sway*.3,y+h*.3,fold+sway,y+h*.7,fold+sway*.7,y+h*.98);ctx.stroke();
        }
      }
      light(ctx,width*.2+Math.sin(time*.3)*width*.025,height*.3,
        width*.32,'255,237,189',.26+Math.sin(time*.45)*.07);
    }
    function drawBokeh(ctx,p) {
      const span=Math.min(width,height),strength=quiet?.35:1;
      for(let i=0;i<10;i++) {
        const phase=i*2.399,timeOffset=time*(.14+(i%3)*.025);
        const side=i%2===0?.1:.88;
        const x=width*(side+Math.sin(phase+timeOffset)*.09)+pointer.x*(12+i)*strength;
        const y=height*wrap(i*.137-time*.008*(.6+(i%4)*.3))+pointer.y*18*strength;
        const radius=span*(.024+(i%4)*.009)*(1+Math.sin(timeOffset+phase)*.13);
        ctx.save();ctx.globalAlpha=(p.dark?.56:.38)*(.7+.3*Math.sin(phase+timeOffset)**2);
        ctx.drawImage(bokeh(i%3===0?p.accent:'255,226,179'),x-radius,y-radius,radius*2,radius*2);ctx.restore();
      }
    }
    function drawParticles(ctx,p) {
      for(const q of particles) {
        const z=q.depth,phase=time*(.65+z*.35)+q.phase;
        let u=q.u,v=q.v;
        if(p.kind==='petals'||p.kind==='snow') {
          u=wrap(q.u+q.drift*time*z+Math.sin(phase)*(.02+z*.022));
          v=wrap(q.v+q.fall*time*(.4+z*.6));
        } else if(p.kind!=='stars') {
          u=wrap(q.u+q.drift*time*.5+Math.sin(phase*.48)*.05);
          v=wrap(q.v-time*.007*z+Math.cos(phase*.42)*.04);
        } else {
          u=wrap(q.u+Math.sin(phase*.3)*.008*z);
          v=wrap(q.v+Math.cos(phase*.25)*.006*z);
        }
        let x=u*(width+56)-28+pointer.x*18*z*(quiet?.3:1),y=v*(height+56)-28+pointer.y*12*z*(quiet?.3:1);
        const px=(pointer.x+1)*width*.5,py=(pointer.y+1)*height*.5;
        const vx=x-px,vy=y-py,distance=Math.hypot(vx,vy),reach=Math.min(width,height)*.27;
        const influence=(1-smooth(distance/reach))*hover*(quiet?.2:1);
        const pull=p.kind==='fireflies'?-.32:.25;
        x+=vx*influence*pull;y+=vy*influence*pull;
        const breathing=.58+.42*Math.sin(phase*.6)**2;
        // The periphery can carry richer detail; keep the portrait area quiet.
        const center=u>.34&&u<.66&&v>.12&&v<.68?.55:1;
        const alpha=clamp((.32+z*.48)*breathing*center+influence*.22,0,.85);
        ctx.save();ctx.globalAlpha=alpha;
        if(p.kind==='petals') {
          const size=4+z*13;
          ctx.translate(x,y);ctx.rotate(q.phase+time*(.15+z*.17)+influence*.4);
          ctx.scale(.45+.55*Math.abs(Math.cos(phase*.35)),1);
          ctx.drawImage(petal(),-size,-size*.75,size*2,size*1.5);
        } else {
          const r=p.kind==='stars'?.65+z*1.5:p.kind==='snow'?1.2+z*3:1+z*1.8;
          ctx.drawImage(glow(p.kind==='fireflies'?'255,248,184':p.light),x-r*5,y-r*5,r*10,r*10);
          ctx.fillStyle=p.kind==='fireflies'?'#fff6bd':'#fffdf6';ctx.beginPath();ctx.arc(x,y,r*.55,0,TAU);ctx.fill();
          if(p.kind==='snow'&&z>.8) {
            ctx.translate(x,y);ctx.rotate(q.phase+time*.04);ctx.strokeStyle='rgba(255,255,255,.8)';ctx.lineWidth=.7;
            ctx.beginPath();for(let j=0;j<3;j++) {
              const a=j*Math.PI/3;ctx.moveTo(-Math.cos(a)*r*2,-Math.sin(a)*r*2);ctx.lineTo(Math.cos(a)*r*2,Math.sin(a)*r*2);
            }ctx.stroke();
          }
        }
        ctx.restore();
      }
      if(id==='dreamy_starry'&&!quiet&&!reduced) {
        const travel=(time%22-4)/3.2;
        if(travel>0&&travel<1) {
          const x=width*(.1+travel*.28),y=height*(.15+travel*.14);
          ctx.save();ctx.globalAlpha=Math.sin(travel*Math.PI)*.48;
          ctx.strokeStyle='#d4e8e6';ctx.lineWidth=1;ctx.beginPath();
          ctx.moveTo(x-width*.055,y-height*.028);ctx.lineTo(x,y);ctx.stroke();
          ctx.drawImage(glow(p.light),x-5,y-5,10,10);ctx.restore();
        }
      }
    }
    function drawInteraction(ctx,p) {
      if(reduced) return;
      const span=Math.min(width,height),warm='255,222,164';
      if(hover>.01) {
        light(ctx,(pointer.x+1)*width*.5,(pointer.y+1)*height*.5,span*.23,
          warm,hover*(quiet?.07:p.dark?.36:.28));
      }
      for(const q of trail) {
        const life=1-(effectTime-q.born)/.9;
        light(ctx,q.u*width,q.v*height-(1-life)*12,8+life*13,warm,life*.3);
      }
      for(const q of blooms) {
        const age=effectTime-q.born,life=1-age/2.4;
        const x=q.u*width,y=q.v*height,r=span*(.035+smooth(age/1.8)*.24);
        light(ctx,x,y,r,warm,Math.min(1,age*8)*life*.72);
        ctx.save();ctx.globalAlpha=life*.18;ctx.strokeStyle=rgba(warm,.8);ctx.lineWidth=1;
        ctx.beginPath();ctx.arc(x,y,r*.64,0,TAU);ctx.stroke();ctx.restore();
        for(let i=0;i<9;i++) {
          const angle=i*2.399+q.phase,distance=(18+i%3*9)+age*(18+i%4*9);
          const sx=x+Math.cos(angle)*distance,sy=y+Math.sin(angle)*distance-age*14;
          if(p.kind==='petals') {
            ctx.save();ctx.globalAlpha=life*.75;ctx.translate(sx,sy);ctx.rotate(angle+age*.6);
            ctx.drawImage(petal(),-6,-4.5,12,9);ctx.restore();
          } else {
            light(ctx,sx,sy,5+life*5,warm,life*.8);
          }
        }
      }
    }
    function frame(stamp) {
      if(disposed||!Number.isFinite(stamp)) return;
      if(hidden()) {wasHidden=true;lastTick=stamp;return;}
      const delta=lastTick===null||wasHidden?0:clamp((stamp-lastTick)/1000,0,.1);
      wasHidden=false;lastTick=stamp;
      if(!reduced) {
        motion+=( (quiet?.26:1)-motion )*(1-Math.exp(-delta*2));
        time+=delta*motion;
        effectTime+=delta;
        blooms=blooms.filter(q=>effectTime-q.born<2.4);
        trail=trail.filter(q=>effectTime-q.born<.9);
        hover+=((pointerInside?1:0)-hover)*(1-Math.exp(-delta*4));
        const follow=1-Math.exp(-delta*2.4);
        pointer.x+=(target.x-pointer.x)*follow;pointer.y+=(target.y-pointer.y)*follow;
        if(transition<1) {
          transitionElapsed+=delta;transition=smooth(transitionElapsed/1.5);
        }
      }
      if(!dirty&&(reduced||stamp-lastPaint<1000/30-.5)) return;
      dirty=false;lastPaint=stamp;frames++;
      context.setTransform(ratio,0,0,ratio,0,0);context.globalAlpha=1;
      context.drawImage(base,0,0,width,height);
      drawAtmosphere(context,PRESETS[id]);drawBokeh(context,PRESETS[id]);
      drawParticles(context,PRESETS[id]);drawInteraction(context,PRESETS[id]);
      if(transition<1) {
        context.save();context.globalAlpha=1-transition;
        context.drawImage(previous,0,0,width,height);context.restore();
      }
    }
    function setReducedMotion(value) {
      if(reduced===!!value) return;
      reduced=!!value;transition=1;pointer={x:0,y:0};hover=0;blooms=[];trail=[];
      press=null;dirty=true;lastTick=null;
    }
    function setMotionMode(value) {
      motionMode=['gentle','still','system'].includes(value)?value:'system';
      setReducedMotion(motionMode==='system'?!!preference?.matches:motionMode==='still');
    }
    function setPointer(x,y) {
      if(!Number.isFinite(x)||!Number.isFinite(y)||disposed||reduced) return;
      target={x:clamp(x,-1,1),y:clamp(y,-1,1)};
      if(!pointerInside) pointer={...target};
      pointerInside=true;
    }
    function leavePointer() {pointerInside=false;target={x:0,y:0};press=null;}
    function pointerMove(event) {
      if(event.isPrimary===false) return;
      setPointer(event.clientX/width*2-1,event.clientY/height*2-1);
      if(press&&event.pointerId===press.id) press.distance=Math.max(press.distance,Math.hypot(event.clientX-press.x,event.clientY-press.y));
      if(pointerInside&&!reduced&&!quiet&&effectTime-lastTrail>.04) {
        trail.push({u:(target.x+1)*.5,v:(target.y+1)*.5,born:effectTime});
        trail=trail.slice(-14);lastTrail=effectTime;
      }
    }
    function pointerDown(event) {
      if(event.isPrimary===false||event.button!==0||reduced||quiet||disposed) return;
      press={id:event.pointerId,x:event.clientX,y:event.clientY,stamp:event.timeStamp,distance:0};
    }
    function pointerUp(event) {
      if(!press||event.pointerId!==press.id) return;
      const start=press;press=null;
      if(event.isPrimary===false||event.button!==0||reduced||quiet||disposed) return;
      const elapsed=event.timeStamp-start.stamp;
      if(elapsed<0||elapsed>500||start.distance>6||Math.hypot(event.clientX-start.x,event.clientY-start.y)>6) return;
      if(!Number.isFinite(event.clientX)||!Number.isFinite(event.clientY)) return;
      blooms.push({u:clamp(event.clientX/width,0,1),v:clamp(event.clientY/height,0,1),born:effectTime,phase:random()*TAU});
      blooms=blooms.slice(-6);
      if(event.pointerType==='touch') leavePointer();
    }
    function dispose() {
      if(disposed) return;disposed=true;listeners.forEach(remove=>remove());sprites.clear();blooms=[];trail=[];press=null;
    }
    resize(options.width||environment?.innerWidth||800,options.height||environment?.innerHeight||600,
      options.dpr||environment?.devicePixelRatio||1);
    if(options.motionMode) setMotionMode(options.motionMode);
    listen(environment,'resize',()=>resize(environment.innerWidth,environment.innerHeight,environment.devicePixelRatio));
    listen(environment,'pointermove',pointerMove);
    listen(environment,'pointerdown',pointerDown);
    listen(environment,'pointerup',pointerUp);
    listen(environment,'pointercancel',()=>{press=null;});
    listen(environment,'blur',leavePointer);
    listen(environment,'pointerleave',leavePointer);
    listen(doc,'pointerleave',leavePointer);
    listen(preference,'change',event=>{if(motionMode==='system')setReducedMotion(event.matches);});
    listen(environment,'pagehide',dispose);
    return {setTheme,resize,frame,setPointer,setReducedMotion,setMotionMode,dispose,
      setQuiet:value=>{quiet=!!value;if(quiet){blooms=[];trail=[];press=null;}},
      getState:()=>({id,time,frames,motion,motionMode,reducedMotion:reduced,transition,particles:particles.length,
        hover,blooms:blooms.length,trail:trail.length,
        width,height,pixelRatio:ratio,pixels:canvas.width*canvas.height})};
  }
  return {create,PRESETS,ALIASES};
});
