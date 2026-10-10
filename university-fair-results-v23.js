(function(){
  'use strict';
  const $=id=>document.getElementById(id),M=FairReport;
  const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const num=v=>Number(v||0).toLocaleString();
  const date=v=>Number.isFinite(Date.parse(v))?new Date(v).toLocaleDateString('en-US',{timeZone:'America/Los_Angeles',month:'short',day:'numeric',year:'numeric'}):'Date unavailable';
  let rows=[],events=[],current='',generated=new Date(),admin=null;
  const days=()=>Number($('reportWindow').value);
  const table=(headers,body)=>body.length?`<table class="report-table"><thead><tr>${headers.map(h=>`<th scope="col">${esc(h)}</th>`).join('')}</tr></thead><tbody>${body.map(cells=>'<tr>'+cells.map(c=>`<td>${c}</td>`).join('')+'</tr>').join('')}</tbody></table>`:'<div class="directory-prompt">No results to display.</div>';
  function stats(key,mature=false){let values=M.scope(rows,{event:key});if(mature&&days())values=values.filter(r=>M.stamp(r.connected_at)+days()*86400000<=generated.getTime());return M.summarize(values,days(),generated.getTime());}
  function metrics(s){return [['Connections',s.connections],['Students participating',s.students],['Employers participating',s.employers],['Interviews recorded',s.reached.interview],['Offers extended',s.reached.offer]];}
  function directory(){
    const query=$('fairSearch').value.trim().toLowerCase(),status=$('fairStatus').value,from=$('fairFrom').value,through=$('fairThrough').value;
    if(from&&through&&from>through){$('fairDirectory').innerHTML='<p>From date must be before through date.</p>';return;}
    const list=events.filter(e=>{
      const stamp=Number.isFinite(Date.parse(e.date))?new Intl.DateTimeFormat('en-CA',{timeZone:'America/Los_Angeles',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(e.date)):'';
      return (!query||e.name.toLowerCase().includes(query))&&(!status||TapIDReview.fairState(e)===status)&&(!from||stamp&&stamp>=from)&&(!through||stamp&&stamp<=through);
    }).sort((a,b)=>(Date.parse(b.date)||0)-(Date.parse(a.date)||0));
    $('fairDirectory').innerHTML=list.length?list.map(e=>`<button type="button" class="fair-event ${e.key===current?'selected':''}" data-fair="${esc(e.key)}" aria-pressed="${e.key===current}"><span><strong>${esc(e.name)}</strong><small>${esc(date(e.date))} · ${esc(TapIDReview.fairState(e))}</small></span><span>${e.key===current?'Viewing results':'View results →'}</span></button>`).join(''):'<div class="directory-prompt">No career fairs match these filters.</div>';
  }
  function render(){
    directory();const event=events.find(e=>e.key===current);
    if(!event){$('reportContent').hidden=true;$('printReport').disabled=$('exportReport').disabled=true;return;}
    $('reportContent').hidden=false;$('printReport').disabled=$('exportReport').disabled=false;
    $('selectedFairName').textContent=event.name;$('selectedFairDate').textContent=date(event.date);
    const suffix='?fair='+encodeURIComponent(current);
    $('fairPopulationLink').href='university-employers.html'+suffix;$('fairStudentLink').href='university-students.html'+suffix;
    $('printTitle').textContent=event.name+' · Career-fair results';$('printScope').textContent=admin.school_name+' · '+date(event.date)+' · '+(days()?'First '+days()+' days after connection':'All recorded results')+' · Generated '+generated.toLocaleString('en-US',{timeZone:'America/Los_Angeles'})+' PT';
    $('eventResults').innerHTML=table(['Event result','Count'],metrics(stats(current)).map(([label,value])=>[esc(label),num(value)]));
    const previous=$('compareEvent').value;
    $('compareEvent').innerHTML='<option value="">Choose another fair</option>'+events.filter(e=>e.key!==current).map(e=>`<option value="${esc(e.key)}">${esc(e.name)} · ${esc(date(e.date))}</option>`).join('');
    $('compareEvent').value=events.some(e=>e.key===previous&&e.key!==current)?previous:'';
    const other=events.find(e=>e.key===$('compareEvent').value);
    $('comparisonWindowControl').hidden=!other||!days();
    if(other){const a=metrics(stats(current,$('compareMature').checked)),b=metrics(stats(other.key,$('compareMature').checked));$('comparisonTable').innerHTML=table(['Event result',event.name,other.name,'Difference'],a.map(([label,value],i)=>[esc(label),num(value),num(b[i][1]),(value-b[i][1]>0?'+':'')+num(value-b[i][1])]))+(days()?'<p class="workspace-caption">'+($('compareMature').checked?'Completed results windows only.':'Includes results windows still in progress.')+'</p>':'');}
    else $('comparisonTable').innerHTML='<p class="directory-prompt">Choose another fair above to compare participation, connections, interviews, and offers.</p>';
    $('fairTable').innerHTML=table(['Career fair','Date','Connections','Students','Employers','Interviews','Offers'],events.slice().sort((a,b)=>(Date.parse(b.date)||0)-(Date.parse(a.date)||0)).map(e=>{const s=stats(e.key);return [`<button class="text-action" data-fair="${esc(e.key)}">${esc(e.name)}</button>`,esc(date(e.date)),num(s.connections),num(s.students),num(s.employers),num(s.reached.interview),num(s.reached.offer)];}));
  }
  async function load(){
    $('refreshReport').disabled=true;$('loadingReport').hidden=false;$('printReport').disabled=$('exportReport').disabled=true;
    try{const ctx=await requireUniversityCardAccess();admin=ctx.admin;$('schoolName').textContent=admin.school_name;
      const result=await M.loadReport(tapid.client);rows=result.data.rows;events=result.data.events;generated=new Date(result.data.generated_at||Date.now());
      const linked=new URLSearchParams(location.search).get('fair');
      if(!events.some(e=>e.key===current))current=events.some(e=>e.key===linked)?linked:TapIDReview.defaultFair(events)||events[0]?.key||'';
      tapid.setMessage($('pageMessage'),'');render();
      if(!events.length)$('fairDirectory').innerHTML='<p>No career fairs yet. Use Add a career fair to create your first event.</p>';
    }catch(e){$('reportContent').hidden=true;$('fairDirectory').textContent='Career fairs could not be loaded. Refresh to retry.';tapid.setMessage($('pageMessage'),e.code==='PGRST202'?'Career-fair report functions are missing. Install the university report SQL update, then refresh.':e.message,'error');}
    finally{$('refreshReport').disabled=false;$('loadingReport').hidden=true;}
  }
  function csvCell(value){let s=String(value??'');if(/^[=+\-@\t\r]/.test(s))s="'"+s;return '"'+s.replaceAll('"','""')+'"';}
  function exportReport(){const output=[['Career fair','Date','Connections','Students','Employers','Interviews','Offers']];for(const e of events){const s=stats(e.key);output.push([e.name,date(e.date),s.connections,s.students,s.employers,s.reached.interview,s.reached.offer]);}output.unshift(['University',admin.school_name],['Results window',days()?'First '+days()+' days after connection':'All recorded results'],['Generated',generated.toISOString()],[]);const a=document.createElement('a');a.href=URL.createObjectURL(new Blob(['\uFEFF'+output.map(c=>c.map(csvCell).join(',')).join('\r\n')],{type:'text/csv;charset=utf-8'}));a.download='tapid-career-fair-results.csv';a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000);}
  ['fairSearch','fairStatus','fairFrom','fairThrough'].forEach(id=>$(id).addEventListener(id==='fairSearch'?'input':'change',directory));
  $('clearFairSearch').onclick=()=>{['fairSearch','fairStatus','fairFrom','fairThrough'].forEach(id=>$(id).value='');directory();};
  ['reportWindow','compareEvent','compareMature'].forEach(id=>$(id).addEventListener('change',render));
  document.addEventListener('click',e=>{const b=e.target.closest('[data-fair]');if(b){current=b.dataset.fair;render();}});
  $('refreshReport').onclick=load;$('exportReport').onclick=exportReport;$('printReport').onclick=()=>window.print();
  $('logoutBtn').onclick=async()=>{await tapid.client.auth.signOut();sessionStorage.removeItem('tapid-university-explicit-login');location.replace('university-login.html');};
  load();
})();
