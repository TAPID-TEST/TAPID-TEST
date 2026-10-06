(function(){
  'use strict';
  const $=id=>document.getElementById(id),M=FairReport;
  const esc=v=>String(v??'').replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));
  const n=v=>Number(v||0).toLocaleString(),rate=(v,total)=>total?`${M.pct(v,total)}%`:'—';
  const label=s=>({connected:'New connection',follow_up:'Follow-up planned',contacted:'Contacted',screening:'Under consideration',interview:'Interview',offer:'Offer extended',accepted_offer:'Offer accepted',internship:'Internship',job:'Hired',passed:'Closed'}[s]||s);
  const day=v=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Los_Angeles',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(v));
  const date=v=>Number.isFinite(Date.parse(v))?new Date(v).toLocaleDateString('en-US',{timeZone:'America/Los_Angeles',month:'short',day:'numeric',year:'numeric'}):'Date unavailable';
  let rows=[],events=[],admin=null,loadedAt=null;
  function filters(event=$('reportEvent').value){return {event,employer:$('reportEmployer').value,major:$('reportMajor').value,year:$('reportYear').value,from:$('reportStart').value,through:$('reportEnd').value};}
  const days=()=>Number($('reportWindow').value);
  const selected=()=>M.scope(rows,filters());
  function options(id,list,all){const node=$(id),value=node.value;node.innerHTML=`<option value="">${esc(all)}</option>`+list.map(([key,title])=>`<option value="${esc(key)}">${esc(title)}</option>`).join('');node.value=list.some(x=>String(x[0])===value)?value:'';}
  function resultCell(value,total){return `${n(value)} <small>· ${rate(value,total)}</small>`;}
  function table(headers,body){return body.length?`<table class="report-table"><thead><tr>${headers.map(h=>`<th scope="col">${esc(h)}</th>`).join('')}</tr></thead><tbody>${body.map(cells=>`<tr>${cells.map(c=>`<td>${c}</td>`).join('')}</tr>`).join('')}</tbody></table>`:'<div class="report-empty">No connections in this selection</div>';}
  function drawMilestones(s){$('milestoneChart').innerHTML=M.stages.filter(([key])=>key!=='connected').map(([key,title])=>`<div class="milestone-row"><span>${esc(title)}</span><div class="milestone-track"><i style="width:${M.pct(s.reached[key],s.connections)||0}%"></i></div><b>${n(s.reached[key])} <small>${rate(s.reached[key],s.connections)}</small></b></div>`).join('');}
  function drawActivity(values){
    const map=new Map();values.filter(r=>Number.isFinite(M.stamp(r.connected_at))).forEach(r=>{const key=day(r.connected_at);map.set(key,(map.get(key)||0)+1);});
    const keys=[...map.keys()].sort();
    if(!keys.length){$('connectionActivity').innerHTML='<div class="report-empty">No dated connections</div>';return;}
    const start=Date.parse(keys[0]+'T00:00:00Z'),last=Date.parse(keys.at(-1)+'T00:00:00Z'),span=Math.round((last-start)/86400000)+1,step=Math.max(1,Math.ceil(span/24));
    const counts=Array(Math.ceil(span/step)).fill(0);
    for(const [key,count]of map)counts[Math.floor((Date.parse(key+'T00:00:00Z')-start)/86400000/step)]+=count;
    const max=Math.max(...counts,1),width=600,base=142,dx=550/Math.max(counts.length-1,1),points=counts.map((v,i)=>[35+i*dx,base-v/max*110]);
    $('connectionActivity').innerHTML=`<svg viewBox="0 0 ${width} 174" role="img" aria-label="Daily connection counts"><defs><linearGradient id="reportArea" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#75b18c" stop-opacity=".35"/><stop offset="1" stop-color="#75b18c" stop-opacity="0"/></linearGradient></defs>${[0,.5,1].map(f=>`<line x1="35" x2="585" y1="${base-110*f}" y2="${base-110*f}" stroke="#e1e9dd"/><text x="0" y="${base-110*f+4}" font-size="10" fill="#7b8c7b">${Math.round(max*f)}</text>`).join('')}<polygon fill="url(#reportArea)" points="35,${base} ${points.map(p=>p.join(',')).join(' ')} ${points.at(-1)[0]},${base}"/><polyline stroke="#2b7750" stroke-width="2.5" fill="none" points="${points.map(p=>p.join(',')).join(' ')}"/>${points.map((p,i)=>`<circle cx="${p[0]}" cy="${p[1]}" r="4" fill="#2b7750"><title>${new Date(start+i*step*86400000).toISOString().slice(0,10)}: ${counts[i]} connections${step>1?' / '+step+' days':''}</title></circle>`).join('')}</svg><div class="chart-axis"><span>${esc(keys[0])}</span><span>${step===1?'Daily':step+'-day totals'}</span><span>${esc(keys.at(-1))}</span></div>`;
  }
  function groupTable(values,key){const groups=M.breakdown(values,key,days(),loadedAt.getTime());return table([key==='company_id'?'Employer':key==='major'?'Major':'Class year','Connections','Students','Employer activity','Interviews','Offers','Hires'],groups.map(g=>[key==='company_id'?`<button data-employer="${esc(g.key)}">${esc(g.label)}</button>`:esc(g.label),n(g.connections),n(g.students),resultCell(g.reached.contacted,g.connections),resultCell(g.reached.interview,g.connections),resultCell(g.reached.offer,g.connections),resultCell(g.reached.job,g.connections)]));}
  function drawComparison(){
    const key=$('compareEvent').value,other=events.find(e=>e.key===key),current=events.find(e=>e.key===$('reportEvent').value);
    if(!current||!other||current.key===other.key){$('comparisonTable').innerHTML='<div class="report-empty">Choose two different career fairs above</div>';return;}
    const groups=[current,other].map(e=>{let cohort=M.scope(rows,filters(e.key));if(days()&&$('compareMature').checked)cohort=cohort.filter(r=>M.stamp(r.connected_at)+days()*86400000<=loadedAt.getTime());return {event:e,stats:M.summarize(cohort,days(),loadedAt.getTime())};});
    const cells=[['Students',s=>n(s.students)],['Employers',s=>n(s.employers)],['Connections',s=>n(s.connections)],...M.stages.filter(([k])=>k!=='connected').map(([k,title])=>[title,s=>resultCell(s.reached[k],s.connections)]),['Median first employer activity',s=>s.median===null?'—':s.median.toFixed(1)+' days'],['Window complete',s=>`${n(s.mature)} / ${n(s.connections)}`]];
    $('comparisonTable').innerHTML=table(['Metric',current.name,other.name],cells.map(([title,fn])=>[esc(title),...groups.map(g=>fn(g.stats))]))+(days()?'<div class="report-window-note">First '+days()+' days after each connection · '+($('compareMature').checked?'completed windows only':'includes provisional windows')+'</div>':'');
  }
  function drawFairs(){
    const groups=events.map(event=>({event,s:M.summarize(M.scope(rows,filters(event.key)),days(),loadedAt.getTime())}));
    $('fairTable').innerHTML=table(['Career fair','Date','Connections','Interview reached','Offer extended','Hired','Window complete'],groups.map(({event:e,s})=>[`<button data-fair="${esc(e.key)}">${esc(e.name)}</button>`,esc(e.date?date(e.date):'Date unavailable'),n(s.connections),resultCell(s.reached.interview,s.connections),resultCell(s.reached.offer,s.connections),resultCell(s.reached.job,s.connections),`${n(s.mature)} / ${n(s.connections)}`]));
  }
  function render(){
    if($('reportStart').value&&$('reportEnd').value&&$('reportStart').value>$('reportEnd').value){tapid.setMessage($('pageMessage'),'Connected from must be before connected through.','error');$('printReport').disabled=$('exportReport').disabled=true;return;}
    tapid.setMessage($('pageMessage'),'');$('printReport').disabled=$('exportReport').disabled=false;
    const values=selected(),s=M.summarize(values,days(),loadedAt.getTime()),event=events.find(e=>e.key===$('reportEvent').value),title=event?.name||'All career fairs';
    if($('comparisonWindowControl'))$('comparisonWindowControl').hidden=!$('compareEvent').value||!days();
    $('reportTitle').textContent=title;$('printTitle').textContent=title+' · Career-fair report';
    const parts=[admin.school_name,event?.date?date(event.date):null,days()?`First ${days()} days after connection`:'All recorded results',`Generated ${loadedAt.toLocaleString('en-US',{timeZone:'America/Los_Angeles'})} PT`,$('reportEmployer').selectedOptions[0]?.textContent,$('reportMajor').value,$('reportYear').value,$('reportStart').value?`Connected from ${$('reportStart').value}`:null,$('reportEnd').value?`Through ${$('reportEnd').value}`:null].filter(Boolean);
    $('printScope').textContent=parts.join(' · ');
    $('reportContext').innerHTML=[event?.date?date(event.date):'Event date unavailable',days()?`First ${days()} days after connection`:'All recorded results',`Loaded ${loadedAt.toLocaleTimeString()}`,event?.ambiguous?'Shared event name · attribution unresolved':null,days()&&s.mature<s.connections?`${s.connections-s.mature} observation windows still open`:null].filter(Boolean).map((x,i)=>`<span class="report-chip ${x.includes('unresolved')||x.includes('still open')?'warning':''}">${esc(x)}</span>`).join('');
    $('metricConnections').textContent=n(s.connections);$('metricConnectedStudents').textContent=n(s.students);$('metricEmployers').textContent=n(s.employers);
    drawMilestones(s);drawActivity(values);
    const p=s.coverage||0;$('momentumDonut').style.background=s.connections?`conic-gradient(#236a45 0% ${p}%,#e1e9db ${p}% 100%)`:'#e1e9db';$('momentumTotal').textContent=s.coverage===null?'—':s.coverage+'%';
    $('momentumLegend').innerHTML=`<div><i style="background:#236a45"></i>Recorded <b>${n(s.reached.contacted)}</b></div><div><i style="background:#e1e9db"></i>Not recorded <b>${n(s.connections-s.reached.contacted)}</b></div>`;
    $('followUpStats').innerHTML=`<div class="report-statline"><span>Median time to first employer activity</span><strong>${s.median===null?'—':s.median.toFixed(1)+'d'}</strong></div><div class="report-statline"><span>No recorded employer activity · 7+ days</span><strong>${n(s.stale)}</strong></div>`;
    $('opportunityChart').innerHTML=Object.entries(s.current).sort((a,b)=>b[1]-a[1]).map(([key,count])=>`<div class="milestone-row"><span>${esc(label(key))}</span><div class="milestone-track"><i style="width:${M.pct(count,s.connections)||0}%"></i></div><b>${n(count)}</b></div>`).join('')||'<div class="report-empty">No current stages</div>';
    $('employerTable').innerHTML=groupTable(values,'company_id');$('majorTable').innerHTML=groupTable(values,'major');$('yearTable').innerHTML=groupTable(values,'school_year');drawComparison();drawFairs();
    document.querySelector('[data-panel="comparison"]').classList.toggle('no-print',!$('compareEvent').value||$('compareEvent').value===$('reportEvent').value);
    $('reportContent').hidden=false;$('loadingReport').hidden=true;
  }
  async function load(){
    $('refreshReport').disabled=true;$('printReport').disabled=$('exportReport').disabled=true;$('loadingReport').hidden=false;
    try{
      const ctx=await requireUniversityCardAccess();admin=ctx.admin;$('schoolName').textContent=admin.school_name;
      const r=await tapid.client.rpc('university_fair_report');if(r.error)throw r.error;
      rows=r.data?.rows||[];events=r.data?.events||[];loadedAt=new Date(r.data?.generated_at||Date.now());
      const old=$('reportEvent').value,past=events.filter(e=>e.date&&Date.parse(e.date)<=Date.now()).sort((a,b)=>Date.parse(b.date)-Date.parse(a.date));
      options('reportEvent',events.map(e=>[e.key,e.name+(e.date?' · '+date(e.date):'')]),'All connection sources');
      const newestRecorded=rows.slice().sort((a,b)=>M.stamp(b.connected_at)-M.stamp(a.connected_at))[0]?.event_key;
      const linked=new URLSearchParams(location.search).get('fair');
      $('reportEvent').value=events.some(e=>e.key===old)?old:events.some(e=>e.key===linked)?linked:past[0]?.key||newestRecorded||events[0]?.key||'';$('reportEvent').disabled=false;
      options('compareEvent',events.map(e=>[e.key,e.name+(e.date?' · '+date(e.date):'')]),'No comparison');
      options('reportEmployer',[...new Map(rows.map(r=>[String(r.company_id),r.company_name])).entries()],'All employers');
      for(const [id,key,title]of [['reportMajor','major','All majors'],['reportYear','school_year','All class years']])options(id,[...new Set(rows.map(r=>r[key]).filter(Boolean))].sort().map(v=>[v,v]),title);
      render();
    }catch(e){$('loadingReport').hidden=true;$('reportContent').hidden=true;tapid.setMessage($('pageMessage'),e.code==='PGRST202'?'Install the university workspace SQL update to enable reports.':e.message,'error');}
    finally{$('refreshReport').disabled=false;}
  }
  function csvCell(v){let value=String(v??'');if(/^[=+\-@\t\r]/.test(value))value="'"+value;return '"'+value.replaceAll('"','""')+'"';}
  function exportSummary(){
    const s=M.summarize(selected(),days(),loadedAt.getTime()),event=events.find(e=>e.key===$('reportEvent').value);
    const output=[['TapID career-fair report',event?.name||'All sources'],['University',admin.school_name],['Generated',loadedAt.toISOString()],['Results window',days()?`First ${days()} days after each connection`:'All recorded results'],['Employer',$('reportEmployer').selectedOptions[0]?.textContent],['Major',$('reportMajor').value||'All'],['Class year',$('reportYear').value||'All'],['Connected from',$('reportStart').value||'Any'],['Connected through',$('reportEnd').value||'Any'],[],['Metric','Count','Percent of connections'],['Connections',s.connections],['Students',s.students],['Employers',s.employers],...M.stages.filter(([k])=>k!=='connected').map(([k,title])=>[title,s.reached[k],rate(s.reached[k],s.connections)]),['Median first employer activity (days)',s.median??'Not recorded'],['Complete observation windows',s.mature],[],['Employer','Connections','Students','Employer activity','Interviews','Offers','Hires']];
    for(const g of M.breakdown(selected(),'company_id',days(),loadedAt.getTime()))output.push([g.label,g.connections,g.students,g.reached.contacted,g.reached.interview,g.reached.offer,g.reached.job]);
    for(const [key,title]of [['major','Major'],['school_year','Class year']]){output.push([], [title,'Connections','Students','Employer activity','Interviews','Offers','Hires']);for(const g of M.breakdown(selected(),key,days(),loadedAt.getTime()))output.push([g.label,g.connections,g.students,g.reached.contacted,g.reached.interview,g.reached.offer,g.reached.job]);}
    output.push([],['Current employer-reported stage','Connections','Percent of connections']);
    for(const [stage,count]of Object.entries(s.current))output.push([label(stage),count,rate(count,s.connections)]);
    output.push([],['No recorded employer activity after 7 days',s.stale],[],['Connection date (Pacific)','Connections']);
    const daily=new Map();for(const r of selected())if(Number.isFinite(M.stamp(r.connected_at))){const key=M.dateKey(r.connected_at);daily.set(key,(daily.get(key)||0)+1);}
    for(const [key,count]of [...daily].sort((a,b)=>a[0].localeCompare(b[0])))output.push([key,count]);
    const comparison=events.find(e=>e.key===$('compareEvent').value);
    if(event&&comparison&&event.key!==comparison.key){
      output.push([],['Fair comparison',days()&&$('compareMature').checked?'Completed observation windows only':'All selected connections'],['Career fair','Connections','Students','Employers',...M.stages.filter(([k])=>k!=='connected').map(([,title])=>title),'Median first employer activity (days)','Complete windows']);
      for(const e of [event,comparison]){let cohort=M.scope(rows,filters(e.key));if(days()&&$('compareMature').checked)cohort=cohort.filter(r=>M.stamp(r.connected_at)+days()*86400000<=loadedAt.getTime());const stats=M.summarize(cohort,days(),loadedAt.getTime());output.push([e.name,stats.connections,stats.students,stats.employers,...M.stages.filter(([k])=>k!=='connected').map(([k])=>stats.reached[k]),stats.median??'Not recorded',stats.mature]);}
    }
    output.push([],['Source','Recorded TapID connections and employer-reported milestones; not official graduate-placement results.']);
    const blob=new Blob(['\uFEFF'+output.map(c=>c.map(csvCell).join(',')).join('\r\n')],{type:'text/csv;charset=utf-8'}),a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='tapid-'+(event?.name||'all-fairs').replace(/[^a-z0-9]+/gi,'-')+'-'+day(loadedAt)+'.csv';a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000);
  }
  ['reportEvent','reportWindow','compareEvent','compareMature','reportEmployer','reportMajor','reportYear','reportStart','reportEnd'].forEach(id=>$(id).addEventListener('change',()=>{if(loadedAt)render();}));
  $('clearReportFilters').onclick=()=>{['reportEmployer','reportMajor','reportYear','reportStart','reportEnd'].forEach(id=>$(id).value='');if(loadedAt)render();};
  $('reportTabs').onclick=e=>{const b=e.target.closest('[data-tab]');if(!b)return;document.querySelectorAll('[data-tab]').forEach(t=>t.classList.toggle('active',t===b));document.querySelectorAll('[data-panel]').forEach(p=>p.hidden=p.dataset.panel!==b.dataset.tab);};
  document.addEventListener('click',e=>{const fair=e.target.closest('[data-fair]'),employer=e.target.closest('[data-employer]');if(fair){$('reportEvent').value=fair.dataset.fair;render();}if(employer){$('reportEmployer').value=employer.dataset.employer;render();}});
  $('refreshReport').onclick=load;$('exportReport').onclick=exportSummary;$('printReport').onclick=()=>{if(loadedAt)window.print();};
  $('logoutBtn').onclick=async()=>{await tapid.client.auth.signOut();sessionStorage.removeItem('tapid-university-explicit-login');location.replace('university-login.html');};
  load();
})();
