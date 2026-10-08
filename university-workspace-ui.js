(function(root){
  'use strict';
  const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const number=v=>Number(v||0).toLocaleString();
  function kpis(items){return items.map(x=>`<article class="report-kpi"><strong>${esc(x.value)}</strong><span>${esc(x.label)}</span>${x.detail?`<small>${esc(x.detail)}</small>`:''}</article>`).join('');}
  function table(headers,rows){return rows.length?`<table class="report-table"><thead><tr>${headers.map(h=>`<th scope="col">${esc(h)}</th>`).join('')}</tr></thead><tbody>${rows.map(r=>`<tr>${r.map(c=>`<td>${c}</td>`).join('')}</tr>`).join('')}</tbody></table>`:'<div class="report-empty">No data yet</div>';}
  function bars(items,denominator){
    if(!items.length)return '<div class="report-empty">No data yet</div>';
    const max=denominator??Math.max(...items.map(x=>Number(x.value)||0),1);
    return items.map(x=>{const value=Number(x.value)||0,width=max?Math.min(100,value/max*100):0;return `<div class="workspace-bar"><div><span>${esc(x.label)}</span><strong>${number(value)}${denominator!=null?` <small>${max?Math.round(value/max*100)+'%':'—'}</small>`:''}</strong></div><div class="workspace-track"><i style="width:${width}%;background:${x.color||'#347853'}"></i></div></div>`;}).join('');
  }
  function donut(items,label){
    const total=items.reduce((n,x)=>n+(Number(x.value)||0),0);let angle=0;
    const segments=items.map(x=>{const from=angle;angle+=total?Number(x.value)/total*100:0;return `${x.color} ${from}% ${angle}%`;});
    return `<div class="donut-flex"><div class="report-donut" style="background:${total?'conic-gradient('+segments.join(',')+')':'#e5ebe1'}"><div><strong>${number(total)}</strong><small>${esc(label)}</small></div></div><div class="report-legend">${items.map(x=>`<div><i style="background:${x.color}"></i>${esc(x.label)} <b>${number(x.value)}</b></div>`).join('')}</div></div>`;
  }
  function columns(items,label){
    const max=Math.max(...items.map(x=>Number(x.value)||0),1),width=620,base=155,step=560/Math.max(items.length,1);
    return `<svg class="workspace-chart" viewBox="0 0 ${width} 198" role="img" aria-label="${esc(label)}">${[...new Set([0,Math.floor(max/2),max])].map(t=>`<line x1="32" x2="612" y1="${base-120*t/max}" y2="${base-120*t/max}" stroke="#e3e9df"/><text x="0" y="${base-120*t/max+4}" fill="#748477" font-size="10">${number(t)}</text>`).join('')}${items.map((x,i)=>{const v=Number(x.value)||0,h=v/max*120,pos=40+i*step;return `<rect x="${pos}" y="${base-h}" width="${Math.max(8,step-12)}" height="${h}" rx="5" fill="${i===items.length-1?'#15533a':'#88b195'}"><title>${esc(x.label)}: ${number(v)}</title></rect><text x="${pos+(step-12)/2}" y="${base-h-7}" text-anchor="middle" font-size="11" fill="#32563e">${number(v)}</text><text x="${pos+(step-12)/2}" y="177" text-anchor="middle" font-size="10" fill="#748477">${esc(x.short||x.label)}</text>`;}).join('')}</svg>`;
  }
  root.UniversityUI={esc,number,kpis,table,bars,donut,columns};
})(typeof globalThis!=='undefined'?globalThis:this);

(function(root){
 const U=root.UniversityUI;
 U.volumeBars=function(items,label='connections'){
  if(!items.length||!items.some(x=>Number(x.value)>0||x.accounts!=null))return '<div class="report-empty">No '+U.esc(label)+' recorded yet</div>';
  const total=items.reduce((n,x)=>n+(Number(x.value)||0),0),max=Math.max(...items.map(x=>Number(x.value)||0),1);
  return '<div class="engagement-bars">'+items.map(x=>{
   const value=Number(x.value)||0;return `<div class="engagement-row"><div class="engagement-row-head"><span>${x.filter?`<button type="button" class="chart-filter-button" data-directory-dimension="${U.esc(x.filter.dimension)}" data-directory-value="${U.esc(x.filter.value)}">${U.esc(x.label)}</button>`:U.esc(x.label)}</span><strong>${U.number(value)} <small>${U.esc(label)}</small></strong></div><div class="workspace-track" role="img" aria-label="${U.esc(x.label)}: ${U.number(value)} ${U.esc(label)}"><i style="width:${value/max*100}%"></i></div>${x.accounts!=null?`<p class="engagement-context">${x.accounts?Math.round((x.connected||0)/x.accounts*100)+'%':'—'} participation · ${U.number(x.connected||0)} of ${U.number(x.accounts)} students</p>`:`<span class="engagement-share">${(total?Math.round(value/total*100):0)}% of connections shown</span>`}</div>`;
  }).join('')+'</div>';
 };
 U.participation=function(connected,total,label){
  const rate=total?Math.round(connected/total*100):null;
  return `<div class="engagement-participation"><strong>${rate===null?'—':rate+'%'}</strong><span>${U.number(connected)} of ${U.number(total)} ${U.esc(label)} have connections</span><div class="participation-track" role="img" aria-label="${U.number(connected)} of ${U.number(total)} ${U.esc(label)} have connections"><i style="width:${rate||0}%"></i></div><div class="participation-legend"><span><i></i>Connected</span><span><i></i>No connections yet</span></div></div>`;
 };
})(typeof globalThis!=='undefined'?globalThis:this);
