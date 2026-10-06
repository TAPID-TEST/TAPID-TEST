(function(){
  'use strict';
  const $=id=>document.getElementById(id),U=UniversityUI,P=UniversityPopulation,M=FairReport,mode=document.body.dataset.workspace;
  let population=null,fair={rows:[],events:[]},admin=null,generated=null,page=0,directorySequence=0,directoryTotal=0,loadSequence=0;
  const date=v=>v?new Date(v).toLocaleDateString('en-US',{timeZone:'America/Los_Angeles',month:'short',day:'numeric',year:'numeric'}):'—';
  const pct=(n,d)=>P.rate(n,d)===null?'—':P.rate(n,d)+'%';
  function heading(){
    $('schoolName').textContent=admin.school_name;
    $('asOf').textContent='Updated '+generated.toLocaleString('en-US',{timeZone:'America/Los_Angeles'})+' PT';
    $('printScope').textContent=admin.school_name+' · All associated accounts · Generated '+generated.toLocaleString('en-US',{timeZone:'America/Los_Angeles'})+' PT';
  }
  function overview(){
    const s=population.students,e=P.employerSummary(population.employers),r=M.summarize(fair.rows,0,generated.getTime());
    $('overviewKpis').innerHTML=U.kpis([{label:'Student accounts',value:U.number(s.accounts),detail:U.number(s.new_30_days)+' created in last 30 days'},
      {label:'Approved companies',value:U.number(e.approved),detail:U.number(e.companies)+' companies registered'},
      {label:'Unique connections',value:U.number(r.connections),detail:'Student × company × source'},
      {label:'Interviews recorded',value:U.number(r.reached.interview),detail:pct(r.reached.interview,r.connections)+' of connections'}]);
    $('studentParticipation').innerHTML=U.bars([{label:'Email confirmed',value:s.email_confirmed},{label:'Public profile active',value:s.public_active},{label:'Has employer connections',value:s.students_connected}],s.accounts);
    $('employerParticipation').innerHTML=U.bars([{label:'Approved company',value:e.approved},{label:'Approved · connected with students',value:e.approvedActive},{label:'Approved · no connections yet',value:e.approved-e.approvedActive}],e.companies);
    $('overviewMilestones').innerHTML=U.bars(M.stages.filter(([key])=>!['connected','interview'].includes(key)).map(([key,label])=>({label,value:r.reached[key]})),r.connections);
    const actions=[['Confirm student email',s.unconfirmed,'university-students.html?state=unconfirmed'],['Complete student basics',s.setup_needed,'university-students.html?state=setup'],['Activate student profile',s.ready_to_activate,'university-students.html?state=ready'],['Active students · no connections',s.active_without_connections,'university-students.html?state=no-connections'],['Recruiter approvals pending',e.pendingRecruiters,'university-employers.html?view=approvals']];
    $('nextActions').innerHTML=actions.map(([label,count,href])=>`<a class="workspace-action" href="${href}"><span>${U.esc(label)}</span><b>${U.number(count)}</b></a>`).join('');
    const events=fair.events.slice().sort((a,b)=>(Date.parse(b.date)||0)-(Date.parse(a.date)||0));
    $('overviewFairs').innerHTML=U.table(['Career fair','Date','Students','Employers','Connections','Offers','Hires'],events.map(e=>{const r=M.summarize(M.scope(fair.rows,{event:e.key}),0,generated.getTime());return [`<a href="university-fairs.html?fair=${encodeURIComponent(e.key)}">${U.esc(e.name)}</a>`,U.esc(date(e.date)),U.number(r.students),U.number(r.employers),U.number(r.connections),U.number(r.reached.offer),U.number(r.reached.job)];}));
  }
  function students(){
    const s=population.students;
    $('studentKpis').innerHTML=U.kpis([{label:'Student accounts',value:U.number(s.accounts),detail:U.number(s.new_30_days)+' new in last 30 days'},
      {label:'Email confirmed',value:U.number(s.email_confirmed),detail:pct(s.email_confirmed,s.accounts)+' of accounts'},
      {label:'Serial assigned',value:U.number(s.cards_assigned),detail:'Issued or activated card'},
      {label:'Students with connections',value:U.number(s.students_connected),detail:pct(s.students_connected,s.accounts)+' of accounts'}]);
    $('accountGrowth').innerHTML=U.columns(population.account_growth.map(g=>({label:g.month,short:new Date(g.month+'-15T12:00:00Z').toLocaleDateString('en-US',{month:'short',timeZone:'UTC'}),value:g.accounts})),'Student accounts created each month, last twelve months');
    $('studentSetup').innerHTML=U.donut(P.setupStates(s),'student accounts');
    $('majorChart').innerHTML=U.bars(P.compactGroups(population.majors).map(g=>({label:g.label,value:g.accounts})));
    $('yearChart').innerHTML=U.bars(population.years.map(g=>({label:g.label,value:g.accounts})));
    $('majorParticipation').innerHTML=U.table(['Major','Accounts','Active profiles','Students with connections','Connection participation'],population.majors.map(g=>[U.esc(g.label),U.number(g.accounts),U.number(g.active),U.number(g.connected),pct(g.connected,g.accounts)]));
    for(const [id,groups,all]of [['studentMajor',population.majors,'All majors'],['studentYear',population.years,'All class years']]){const value=$(id).value;$(id).innerHTML=`<option value="">${all}</option>`+groups.map(g=>`<option value="${U.esc(g.label)}">${U.esc(g.label)}</option>`).join('');$(id).value=groups.some(g=>g.label===value)?value:'';}
  }
  function employers(){
    const e=P.employerSummary(population.employers);
    $('employerKpis').innerHTML=U.kpis([{label:'Companies registered',value:U.number(e.companies),detail:U.number(e.recruiters)+' recruiter accounts'},
      {label:'Approved companies',value:U.number(e.approved),detail:pct(e.approved,e.companies)+' of registered companies'},
      {label:'Companies with connections',value:U.number(e.active),detail:'Recorded student introductions'},
      {label:'Recruiter requests pending',value:U.number(e.pendingRecruiters),detail:'Awaiting university review'}]);
    $('approvalQueueCount').textContent=e.pendingRecruiters?'· '+U.number(e.pendingRecruiters):'';
    $('employerStatusChart').innerHTML=U.donut([{label:'Approved',value:e.approved,color:'#15533a'},{label:'Pending',value:e.pending,color:'#9dbb9c'},{label:'Declined',value:e.declined,color:'#d9dfd3'}],'companies');
    const top=population.employers.slice().sort((a,b)=>b.connections-a.connections).slice(0,8);
    $('employerVolumeChart').innerHTML=U.bars(top.map(e=>({label:e.name,value:e.connections})));
    $('employerDirectory').innerHTML=U.table(['Company','Access','Recruiters','Students','Connections','Fair sources','Interviews','Offers','Hires','Last connection'],population.employers.map(e=>{const results=M.summarize(fair.rows.filter(r=>String(r.company_id)===String(e.company_id)),0,generated.getTime());return [U.esc(e.name),`<span class="workspace-status ${e.status==='approved'?'':U.esc(e.status)}">${U.esc(e.status)}</span>`,U.number(e.recruiters),U.number(e.students),U.number(e.connections),U.number(e.events),U.number(results.reached.interview),U.number(results.reached.offer),U.number(results.reached.job),U.esc(date(e.last_connection_at))];}));
  }
  async function load(){
    const token=++loadSequence;$('printWorkspace').disabled=true;
    if($('loadingWorkspace'))$('loadingWorkspace').hidden=false;
    if($('refreshWorkspace'))$('refreshWorkspace').disabled=true;
    try{
      const ctx=await requireUniversityCardAccess();admin=ctx.admin;
      const calls=[tapid.client.rpc('university_population_report')];if(mode!=='students')calls.push(tapid.client.rpc('university_fair_report'));
      const results=await Promise.all(calls);if(token!==loadSequence)return;
      for(const r of results)if(r.error)throw r.error;
      population=results[0].data;if(!population?.students)throw new Error('Student reporting data is unavailable.');
      fair=results[1]?.data||{rows:[],events:[]};generated=new Date(population.generated_at);heading();
      if(mode==='overview')overview();if(mode==='students'){students();await loadDirectory();}if(mode==='employers')employers();
      if($('workspaceContent'))$('workspaceContent').hidden=false;
      $('printWorkspace').disabled=false;tapid.setMessage($('pageMessage'),'');
    }catch(e){if(token===loadSequence){if($('workspaceContent'))$('workspaceContent').hidden=true;tapid.setMessage($('pageMessage'),e.code==='PGRST202'?'Run the university population SQL update to enable this view.':e.message,'error');}}
    finally{if(token===loadSequence){if($('loadingWorkspace'))$('loadingWorkspace').hidden=true;if($('refreshWorkspace'))$('refreshWorkspace').disabled=false;}}
  }
  async function loadDirectory(){
    const token=++directorySequence;$('printDirectory').disabled=true;$('previousStudents').disabled=$('nextStudents').disabled=true;
    $('studentDirectory').innerHTML='<div class="report-empty">Loading students…</div>';
    try{
      const filters={p_search:$('studentSearch').value.trim(),p_major:$('studentMajor').value,p_year:$('studentYear').value,p_state:$('studentState').value,p_page:page};
      const result=await tapid.client.rpc('university_student_directory',filters);if(token!==directorySequence)return;if(result.error)throw result.error;
      const d=result.data;directoryTotal=d.total;
      if(page>0&&page*50>=d.total){page=Math.max(0,Math.ceil(d.total/50)-1);return loadDirectory();}
      $('studentDirectory').innerHTML=U.table(['Student','Major','Class year','Joined','Email','Card','Profile status','Connections','Last connection'],d.rows.map(s=>[s.username?`<a href="profile.html?u=${encodeURIComponent(s.username)}" target="_blank" rel="noopener">${U.esc(s.name)}</a>`:U.esc(s.name),U.esc(s.major),U.esc(s.class_year),U.esc(date(s.joined_at)),s.email_confirmed?'Confirmed':'Pending',s.card_assigned?'Assigned':'Not assigned',`<span class="workspace-status ${s.status==='Active'?'':'pending'}">${U.esc(s.status)}</span>`,U.number(s.connections),U.esc(date(s.last_connection_at))]));
      $('directoryPage').textContent=d.total?`${page*50+1}–${Math.min((page+1)*50,d.total)} of ${U.number(d.total)} students`:'0 students';
      $('directoryScope').textContent=[filters.p_search?'Search: '+filters.p_search:null,filters.p_major,filters.p_year,$('studentState').selectedOptions[0].textContent,'Directory page '+(page+1)].filter(Boolean).join(' · ');
      $('previousStudents').disabled=page===0;$('nextStudents').disabled=(page+1)*50>=d.total;$('printDirectory').disabled=false;
    }catch(e){if(token===directorySequence){$('studentDirectory').innerHTML='<div class="report-empty">Unable to load student directory</div>';tapid.setMessage($('pageMessage'),e.message,'error');}}
  }
  function print(){document.body.classList.remove('directory-print');heading();window.print();}
  $('printWorkspace').onclick=print;window.addEventListener('afterprint',()=>document.body.classList.remove('directory-print'));
  if(mode==='employers'){
    const view=v=>{const approvals=v==='approvals';$('employerAnalytics').hidden=approvals;$('employerApprovalSection').hidden=!approvals;document.querySelectorAll('[data-employer-view]').forEach(b=>b.classList.toggle('active',b.dataset.employerView===v));};
    $('employerViewTabs').onclick=e=>{const b=e.target.closest('[data-employer-view]');if(b)view(b.dataset.employerView);};
    view(new URLSearchParams(location.search).get('view')==='approvals'?'approvals':'analytics');
    $('refreshApprovals').addEventListener('click',load);window.addEventListener('tapid-employer-approval-updated',load);
  }else{
    $('refreshWorkspace').onclick=load;$('logoutBtn').onclick=async()=>{await tapid.client.auth.signOut();sessionStorage.removeItem('tapid-university-explicit-login');location.replace('university-login.html');};
  }
  if(mode==='students'){
    const initial=new URLSearchParams(location.search).get('state');if([...$('studentState').options].some(x=>x.value===initial))$('studentState').value=initial;
    let timer;const change=()=>{page=0;clearTimeout(timer);loadDirectory();};
    $('studentSearch').oninput=()=>{clearTimeout(timer);directorySequence++;$('printDirectory').disabled=true;timer=setTimeout(change,250);};
    ['studentMajor','studentYear','studentState'].forEach(id=>$(id).onchange=change);
    $('previousStudents').onclick=()=>{page--;loadDirectory();};$('nextStudents').onclick=()=>{page++;loadDirectory();};
    $('printDirectory').onclick=()=>{document.body.classList.add('directory-print');$('printScope').textContent=admin.school_name+' · '+$('directoryScope').textContent+' · '+$('directoryPage').textContent+' · Generated '+generated.toLocaleString('en-US',{timeZone:'America/Los_Angeles'})+' PT';window.print();};
    $('addStudents').onclick=()=>{$('studentSignupLink').value=tapid.siteUrl('signup.html');$('copyMessage').textContent='';$('addStudentsDialog').showModal();};
    $('closeAddStudents').onclick=()=>$('addStudentsDialog').close();
    $('copySignupLink').onclick=async()=>{try{await navigator.clipboard.writeText($('studentSignupLink').value);$('copyMessage').textContent='Signup link copied.';}catch{$('studentSignupLink').select();$('copyMessage').textContent='Select the link and press Ctrl+C or Command+C.';}};
  }
  load();
})();
