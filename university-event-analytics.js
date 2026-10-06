/* Event reporting uses current employer-reported stages, never inferred milestone history. */
let eventReferences=[],latestEvent='',reportLoadedAt=null;
const validDate=v=>v!==null&&v!==undefined&&v!==''&&Number.isFinite(new Date(v).getTime());
const shortDate=v=>validDate(v)?new Date(v).toLocaleDateString(undefined,{month:'short',day:'numeric',year:'numeric'}):'Date unavailable';
const rate=(n,d)=>d?`${Math.round(n/d*100)}%`:'—';
const isFair=name=>name&&!['direct connection','unspecified'].includes(name.trim().toLowerCase());
function eventCatalog(){
  const names=new Set([...eventReferences.map(e=>e.event_name),...reportRows.map(r=>r.event_name)].filter(isFair));
  return [...names].map(name=>{const refs=eventReferences.filter(e=>e.event_name===name);return {name,date:refs.length===1&&validDate(refs[0].starts_at)?refs[0].starts_at:null,ambiguous:refs.length>1};}).sort((a,b)=>(Date.parse(b.date)||0)-(Date.parse(a.date)||0)||a.name.localeCompare(b.name));
}
function initializeEvents(){
  const catalog=eventCatalog(),past=catalog.filter(e=>e.date&&Date.parse(e.date)<=Date.now());
  latestEvent=past[0]?.name||'';
  const node=document.getElementById('reportEvent');
  node.innerHTML='<option value="">All connection sources</option>'+catalog.map(e=>`<option value="${esc(e.name)}">${esc(e.name)}${e.date?' · '+esc(shortDate(e.date)):''}</option>`).join('')+([...new Set(reportRows.map(r=>r.event_name))].filter(n=>!isFair(n)).map(n=>`<option value="${esc(n)}">${esc(n||'Unspecified')}</option>`).join(''));
  node.value=latestEvent;
  document.getElementById('latestFair').disabled=!latestEvent;
  const compare=document.getElementById('compareEvent');
  compare.innerHTML='<option value="">Choose a career fair</option>'+catalog.map(e=>`<option value="${esc(e.name)}">${esc(e.name)}</option>`).join('');
  compare.value=past.find(e=>e.name!==latestEvent)?.name||'';
}
function cohortRows(event){
  const employer=document.getElementById('reportEmployer').value,major=document.getElementById('reportMajor').value,year=document.getElementById('reportYear').value,start=document.getElementById('reportStart').value,end=document.getElementById('reportEnd').value;
  return reportRows.filter(r=>(event===null||r.event_name===event)&&(!employer||r.company_name===employer)&&(!major||r.major===major)&&(!year||r.school_year===year)&&(!start||String(r.connected_at).slice(0,10)>=start)&&(!end||String(r.connected_at).slice(0,10)<=end));
}
function summarize(rows){return {connections:rows.length,students:new Set(rows.map(r=>r.student_key).filter(Boolean)).size,employers:new Set(rows.map(r=>r.company_id).filter(v=>v!=null)).size,followed:rows.filter(r=>validDate(r.first_follow_up_at)).length,interview:rows.filter(r=>r.candidate_status==='interview').length,offer:rows.filter(r=>r.candidate_status==='offer').length,accepted:rows.filter(r=>r.candidate_status==='accepted_offer').length,hired:rows.filter(r=>r.candidate_status==='job').length,internship:rows.filter(r=>r.candidate_status==='internship').length};}
function renderActivity(rows){
  const root=document.getElementById('connectionActivity'),dates=rows.map(r=>r.connected_at).filter(validDate).map(v=>Date.parse(v));
  if(!dates.length){root.innerHTML='<p class="analytics-empty">No dated connections for this selection.</p>';return;}
  const first=Math.min(...dates),last=Math.max(...dates),day=86400000,span=Math.floor((last-first)/day)+1,step=span<=21?1:Math.ceil(span/20),bins=Math.ceil(span/step),counts=Array(bins).fill(0);
  dates.forEach(t=>counts[Math.min(bins-1,Math.floor((t-first)/(day*step)))]++);
  const max=Math.max(...counts,1),w=650,h=170,base=145,dx=600/Math.max(bins-1,1),points=counts.map((n,i)=>[25+i*dx,base-n/max*110]);
  const line=points.map(p=>p.join(',')).join(' '),area=`25,${base} ${line} ${points[points.length-1][0]},${base}`;
  root.innerHTML=`<svg viewBox="0 0 ${w} ${h}" role="img" aria-label="Connections over time, ${dates.length} dated connections"><defs><linearGradient id="activityFill" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#69ad83" stop-opacity=".35"/><stop offset="100%" stop-color="#69ad83" stop-opacity=".03"/></linearGradient></defs>${[0,.5,1].map(f=>`<line x1="25" x2="625" y1="${base-f*110}" y2="${base-f*110}" stroke="#e6ede6" stroke-dasharray="4 4"/>`).join('')}<polygon points="${area}" fill="url(#activityFill)"/><polyline points="${line}" fill="none" stroke="#24764b" stroke-width="2.5"/>${points.map((p,i)=>`<circle cx="${p[0]}" cy="${p[1]}" r="3.5" fill="#24764b"><title>${esc(shortDate(first+i*day*step))}: ${counts[i]} connections${step>1?' in '+step+' days':''}</title></circle>`).join('')}</svg><div class="chart-axis"><span>${esc(shortDate(first))}</span><span>${step===1?'Daily connections':step+'-day connection totals'}</span><span>${esc(shortDate(last))}</span></div>`;
}
function renderComparisons(){
  const selected=document.getElementById('reportEvent').value,other=document.getElementById('compareEvent').value,root=document.getElementById('comparisonRows');
  if(!selected||!isFair(selected)||!other||selected===other){root.innerHTML='<p class="analytics-empty">Select two different career fairs to compare their current results.</p>';return;}
  const a=summarize(cohortRows(selected)),b=summarize(cohortRows(other));
  const metrics=[['Connections','connections',false],['Recorded follow-through','followed',true],['Currently interviewing','interview',true],['Offers currently extended','offer',true],['Offers currently accepted','accepted',true],['Currently hired','hired',true],['Internships confirmed','internship',true]];
  root.innerHTML=`<div class="compare-key"><span><i></i>${esc(selected)}</span><span><i></i>${esc(other)}</span></div>`+metrics.map(([label,key,showRate])=>{const max=Math.max(a[key],b[key],1);return `<div class="comparison-item"><strong>${label}</strong>${[a,b].map((s,i)=>`<div class="comparison-track"><div><span class="series-${i}" style="width:${s[key]/max*100}%"></span></div><small>${number(s[key])}${showRate?' · '+rate(s[key],s.connections):''}</small></div>`).join('')}</div>`;}).join('')+`<p class="subtle">Percentages use each fair’s filtered connections as the denominator. Different fair ages and reporting coverage affect comparisons.</p>`;
}
function renderFairResults(){
  const catalog=eventCatalog(),root=document.getElementById('eventRows');
  if(!catalog.length){root.innerHTML='<p class="analytics-empty">No career-fair connections or imported events yet.</p>';return;}
  const summaries=catalog.map(e=>({...e,stats:summarize(cohortRows(e.name))})),max=Math.max(...summaries.map(e=>e.stats.connections),1),selected=document.getElementById('reportEvent').value;
  root.innerHTML=summaries.map(e=>`<button type="button" class="fair-result ${selected===e.name?'selected':''}" data-fair="${esc(e.name)}"><div><strong>${esc(e.name)}</strong><small>${esc(e.date?shortDate(e.date):e.ambiguous?'Shared event name · dates ambiguous':'Event date not provided')}</small></div><span>${number(e.stats.connections)} connections</span><div class="fair-volume"><i style="width:${e.stats.connections/max*100}%"></i></div><small>${e.stats.students} students · ${e.stats.employers} employers · ${rate(e.stats.followed,e.stats.connections)} recorded follow-through</small></button>`).join('');
  root.querySelectorAll('[data-fair]').forEach(b=>b.onclick=()=>{document.getElementById('reportEvent').value=b.dataset.fair;renderReport();});
}
function renderEventAnalytics(rows){
  const selected=document.getElementById('reportEvent').value,s=summarize(rows),event=eventCatalog().find(e=>e.name===selected);
  document.getElementById('reportScope').textContent=`${selected||'All connection sources'} · ${number(rows.length)} relationships · ${number(s.students)} students`;
  document.getElementById('eventContext').textContent=event?.date?`${shortDate(event.date)} · ${Math.max(0,Math.floor((Date.now()-Date.parse(event.date))/86400000))} days since fair · latest reported status`:'Latest reported status. Import event dates in Governance to enable the latest-fair default.';
  document.getElementById('metricKnownStatus').textContent=rate(s.followed,s.connections);
  document.getElementById('lastUpdated').textContent=reportLoadedAt?`Data loaded ${reportLoadedAt.toLocaleTimeString()}`:'Loading data';
  renderActivity(rows);renderFairResults();renderComparisons();
}
