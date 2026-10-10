(function(){
  'use strict';
  const node=document.getElementById('populationLeaderboard'),select=document.getElementById('leaderboardFair');
  if(!node||!select)return;
  const kind=document.body.dataset.workspace==='students'?'students':'employers';
  const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  let rows=[];
  function render(){
    const values=FairReport.scope(rows,{event:select.value}),list=FairReport.leaderboard(values,kind).slice(0,10);
    node.innerHTML=list.length?'<ol class="fair-leaderboard">'+list.map(g=>`<li><span class="leaderboard-rank">${g.rank}</span><div><strong>${esc(g.label)}</strong><small>${g.reached.toLocaleString()} ${kind==='students'?'employers connected':'students reached'}</small></div><strong class="leaderboard-score">${g.connections.toLocaleString()}<small>connections</small></strong></li>`).join('')+'</ol><p class="workspace-caption">Equal connection counts share a rank. Each student–company connection is counted once per fair or source.</p>':'<div class="directory-prompt">No recorded connections in this selection.</div>';
  }
  async function load(){
    select.disabled=true;node.textContent='Loading rankings…';
    try{
      await requireUniversityCardAccess();
      const result=await FairReport.loadReport(tapid.client);rows=result.data.rows;
      const previous=select.value||new URLSearchParams(location.search).get('fair')||'';
      select.innerHTML='<option value="">All fairs and connection sources</option>'+result.data.events.map(e=>`<option value="${esc(e.key)}">${esc(e.name)}</option>`).join('');
      select.value=result.data.events.some(e=>e.key===previous)?previous:'';select.disabled=false;render();
    }catch(error){node.innerHTML='<p>Rankings could not be loaded. Refresh to retry.</p>';}
  }
  select.onchange=render;
  document.getElementById(kind==='students'?'refreshWorkspace':'refreshApprovals')?.addEventListener('click',load);
  load();
})();
