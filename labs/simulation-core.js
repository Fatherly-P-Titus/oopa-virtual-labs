/* OOPA Virtual Labs shared simulation helpers. No external dependencies. */
window.OOPASim = (() => {
  const $ = id => document.getElementById(id);
  function init(draw, update, reset) {
    const canvas=$('sim'), ctx=canvas.getContext('2d'); let running=true, speed=1, last=0, raf=0, w=0,h=0;
    function resize(){const r=canvas.getBoundingClientRect(),dpr=Math.min(devicePixelRatio||1,2);w=Math.max(1,r.width);h=Math.max(1,r.height);canvas.width=Math.round(w*dpr);canvas.height=Math.round(h*dpr);ctx.setTransform(dpr,0,0,dpr,0,0);render();}
    function render(){ctx.clearRect(0,0,w,h);draw(ctx,w,h);}
    function loop(t){const dt=Math.min(.04,Math.max(0,(t-last)/1000||0));last=t;if(running)update(dt*speed);render();raf=requestAnimationFrame(loop);}
    $('play').addEventListener('click',()=>{running=!running;$('play').textContent=running?'Pause':'Play';$('play').setAttribute('aria-pressed',String(running));$('stage-note').textContent=running?'Simulation running':'Paused';});
    $('step').addEventListener('click',()=>{update(.04*speed);render();});
    $('reset').addEventListener('click',()=>{reset();render();$('stage-note').textContent='Experiment reset';});
    $('speed').addEventListener('change',e=>speed=Number(e.target.value)||1);
    window.addEventListener('resize',resize);resize();raf=requestAnimationFrame(loop);
    return {canvas,ctx,render,dimensions:()=>({w,h}),setRunning(v){running=v;$('play').textContent=v?'Pause':'Play';},getRunning:()=>running};
  }
  function slider(parent,id,label,min,max,step,value,fmt,cb){const wrap=document.createElement('div');wrap.className='control';wrap.innerHTML=`<label for="${id}"><span>${label}</span><output id="${id}-out"></output></label><input id="${id}" type="range" min="${min}" max="${max}" step="${step}" value="${value}">`;parent.append(wrap);const el=$(id),out=$(id+'-out');function sync(){out.value=fmt?fmt(Number(el.value)):el.value;cb(Number(el.value));}el.addEventListener('input',sync);sync();return {get:()=>Number(el.value),set:v=>{el.value=v;sync();}};}
  function select(parent,id,label,options,value,cb){const wrap=document.createElement('div');wrap.className='control';wrap.innerHTML=`<label for="${id}"><span>${label}</span></label><select id="${id}">${options.map(o=>`<option value="${o[0]}">${o[1]}</option>`).join('')}</select>`;parent.append(wrap);const el=$(id);el.value=value;el.addEventListener('change',()=>cb(el.value));cb(el.value);return {get:()=>el.value,set:v=>{el.value=v;cb(v);}};}
  function check(parent,id,label,value,cb){const row=document.createElement('label');row.className='checkrow';row.innerHTML=`<input id="${id}" type="checkbox"><span>${label}</span>`;parent.append(row);const el=$(id);el.checked=value;el.addEventListener('change',()=>cb(el.checked));return {get:()=>el.checked,set:v=>{el.checked=v;cb(v);}};}
  function presets(items,cb){const p=$('presets');p.innerHTML='';items.forEach((it,i)=>{const b=document.createElement('button');b.type='button';b.className='chip'+(!i?' active':'');b.textContent=it[0];b.addEventListener('click',()=>{p.querySelectorAll('.chip').forEach(x=>x.classList.remove('active'));b.classList.add('active');cb(it[1]);});p.append(b);});}
  function stats(items){const el=$('stats');el.innerHTML='';const refs={};Object.entries(items).forEach(([k,v])=>{const d=document.createElement('div');d.innerHTML=`<dt>${k}</dt><dd>—</dd>`;el.append(d);refs[k]=d.querySelector('dd');});return (vals)=>Object.entries(vals).forEach(([k,v])=>{if(refs[k])refs[k].textContent=v;});}
  function notes(items){$('science-notes').innerHTML=`<div class="insight-grid">${items.map(x=>`<article><h3>${x[0]}</h3><p>${x[1]}</p></article>`).join('')}</div>`;}
  function axes(ctx,w,h,xlabel,ylabel){ctx.strokeStyle='#d8d1cd';ctx.lineWidth=1;ctx.beginPath();ctx.moveTo(42,14);ctx.lineTo(42,h-30);ctx.lineTo(w-12,h-30);ctx.stroke();ctx.fillStyle='#777';ctx.font='11px Arial';ctx.fillText(ylabel,8,18);ctx.fillText(xlabel,w-70,h-9);}
  return {init,slider,select,check,presets,stats,notes,axes,$};
})();
