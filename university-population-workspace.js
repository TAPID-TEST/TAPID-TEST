(function(){
  'use strict';
  const $=id=>document.getElementById(id),U=UniversityUI,P=UniversityPopulation,M=FairReport,mode=document.body.dataset.workspace;
  let population=null,fair={rows:[],events:[]},admin=null,generated=null,page=0,directorySequence=0,directoryTotal=0,loadSequence=0,selectedCollege='',companyPage=0;
  const date=v=>v?new Date(v).toLocaleDateString('en-US',{timeZone:'America/Los_Angeles',month:'short',day:'numeric',year:'numeric'}):'—';
  const pct=(n,d)=>P.rate(n,d)===null?'—':P.rate(n,d)+'%';
  function heading(){
    $('schoolName').textContent=admin.school_name;
    $('asOf').textContent='Updated '+generated.toLocaleString('en-US',{timeZone:'America/Los_Angeles'})+' PT';
    $('printScope').textContent=admin.school_name+' · All associated accounts · Generated '+generated.toLocaleString('en-US',{timeZone:'America/Los_Angeles'})+' PT';
  }
  function overview(){
    const s=population.students,e=P.employerSummary(population.employers),r=M.summarize(fair.rows,0,generated.getTime());
    $('overviewKpis').innerHTML=U.kpis([
      {label:'Student accounts',value:U.number(s.accounts),href:'university-students.html#studentDirectoryPanel'},
      {label:'Company accounts',value:U.number(e.companies),href:'university-employers.html#employerDirectory'},
      {label:'Total connections',value:U.number(s.connections),href:'university-students.html?state=connected#studentDirectoryPanel'},
      {label:'Interviews recorded',value:U.number(r.reached.interview),href:'university-fairs.html'}]);
    $('studentParticipation').innerHTML=U.participation(s.students_connected,s.accounts,'student accounts');
    $('employerParticipation').innerHTML=U.participation(e.approvedActive,e.approved,'approved companies');
    $('universityNoticeCount').textContent=U.number(e.pendingRecruiters);
    const upcoming=fair.events.filter(event=>Number.isFinite(Date.parse(event.date))&&Date.parse(event.date)>generated.getTime());
    $('universityNotifications').innerHTML=`<a class="university-notice ${e.pendingRecruiters?'needs-review':''}" href="university-employers.html?view=approvals"><span class="notice-icon" aria-hidden="true">◎</span><span><strong>${e.pendingRecruiters?'Employer requests awaiting review':'No pending employer requests'}</strong><span>${e.pendingRecruiters?'Open the approval queue':'View employer approvals'}</span></span><b>${U.number(e.pendingRecruiters)}</b><span aria-hidden="true">→</span></a>`+
      (upcoming.length?`<a class="university-notice" href="university-fairs.html"><span class="notice-icon" aria-hidden="true">▦</span><span><strong>Upcoming career fairs</strong><span>View scheduled events</span></span><b>${U.number(upcoming.length)}</b><span aria-hidden="true">→</span></a>`:'');
    const actions=[['Students with zero connections',Math.max(0,s.accounts-s.students_connected),'university-students.html?state=never-connected#studentDirectoryPanel'],['Approved companies with zero connections',Math.max(0,e.approved-e.approvedActive),'university-employers.html?connections=zero#employerDirectory']];
    $('nextActions').innerHTML=actions.map(([label,count,href])=>`<a class="engagement-gap" href="${href}"><b>${U.number(count)}</b><span>${U.esc(label)}</span><span aria-hidden="true">→</span></a>`).join('');
    const events=fair.events.slice().sort((a,b)=>(Date.parse(b.date)||0)-(Date.parse(a.date)||0));
    $('overviewFairs').innerHTML=U.table(['Career fair','Date','Students','Employers','Connections','Interviews','Offers'],events.map(e=>{const r=M.summarize(M.scope(fair.rows,{event:e.key}),0,generated.getTime());return [`<a href="university-fairs.html?fair=${encodeURIComponent(e.key)}">${U.esc(e.name)}</a>`,U.esc(date(e.date)),U.number(r.students),U.number(r.employers),U.number(r.connections),U.number(r.reached.interview),U.number(r.reached.offer)];}));
  }
  function connectionCharts(){
    const rows=population.engagement_groups;
    const allMajors=$('connectionDimension').value==='major';
    const groups=P.engagementGroups(rows,'college');
    if(!groups.some(g=>g.label===selectedCollege))selectedCollege='';
    $('collegeChartTitle').textContent=allMajors?'Connections by major':selectedCollege||'Connections by college';
    $('collegeChartHint').textContent=selectedCollege?'Connections by major':'Select a college to see its majors';
    $('backToColleges').hidden=!selectedCollege;
    if(allMajors||selectedCollege){
      $('collegeConnections').innerHTML=U.categoryBars(P.engagementGroups(rows,'major',allMajors?'':selectedCollege).map(g=>({label:g.label,value:g.connections,filter:{dimension:'major',value:g.label}})));
    }else{
      $('collegeConnections').innerHTML=U.categoryBars(groups.map(g=>({label:g.label,value:g.connections,college:g.label})));
    }
    const yearOrder=['Freshman','Sophomore','Junior','Senior','Graduate'];const years=P.engagementGroups(rows,'year').sort((a,b)=>(yearOrder.includes(a.label)?yearOrder.indexOf(a.label):99)-(yearOrder.includes(b.label)?yearOrder.indexOf(b.label):99)||a.label.localeCompare(b.label));
    $('yearConnections').innerHTML=U.categoryBars(years.map(g=>({label:g.label,value:g.connections,accounts:g.accounts,connected:g.connected,filter:{dimension:'year',value:g.label}})));
  }
  function students(){
    const s=population.students;
    $('studentKpis').innerHTML=U.kpis([
      {label:'Student accounts',value:U.number(s.accounts),href:'#studentDirectoryPanel'},
      {label:'Students with connections',value:U.number(s.students_connected),href:'?state=connected#studentDirectoryPanel'},
      {label:'Total connections',value:U.number(s.connections),href:'?state=connected#studentDirectoryPanel'},
      {label:'Connection participation',value:pct(s.students_connected,s.accounts),href:'?state=never-connected#studentDirectoryPanel'}
    ]);
    const oldCollege=$('studentCollege').value;const colleges=[...new Set(population.engagement_groups.map(g=>g.college))].sort();$('studentCollege').innerHTML='<option value="">All colleges</option>'+colleges.map(c=>`<option>${U.esc(c)}</option>`).join('');$('studentCollege').value=colleges.includes(oldCollege)?oldCollege:'';
    connectionCharts();
    $('connectionGrowth').innerHTML=U.columns(population.connection_growth.map(g=>({label:g.month,short:new Date(g.month+'-15T12:00:00Z').toLocaleDateString('en-US',{month:'short',timeZone:'UTC'}),value:g.connections})),'New unique student-company-source connections per month, last twelve months');
    for(const [id,groups,all]of [['studentMajor',population.majors,'All majors'],['studentYear',population.years,'All class years']]){const value=$(id).value;$(id).innerHTML=`<option value="">${all}</option>`+groups.map(g=>`<option value="${U.esc(g.label)}">${U.esc(g.label)}</option>`).join('');$(id).value=groups.some(g=>g.label===value)?value:'';}
  }
  function employers(){
    const summary=P.employerSummary(population.employers),companies=P.engagedEmployers(population.employers),active=companies.filter(e=>P.num(e.connections)>0).length,recent=P.recentEmployers(companies).length;
    $('employerKpis').innerHTML=U.kpis([
      {label:'Company accounts',value:U.number(summary.companies),href:'#employerDirectory'},
      {label:'Companies with connections',value:U.number(active),detail:pct(active,companies.length)+' of approved companies'},
      {label:'Students reached',value:U.number(population.students.approved_employers_students),detail:'Each student counted once across approved companies'},
      {label:'Companies connecting · last 30 days',value:U.number(recent),detail:U.number(companies.reduce((n,e)=>n+P.num(e.connections_30_days),0))+' new connections'}
    ]);
    $('approvalQueueCount').textContent=summary.pendingRecruiters?'· '+U.number(summary.pendingRecruiters):'';
    const oldMajor=$('companyMajor').value,oldFair=$('companyFair').value;
    const majors=[...new Set(population.employers.flatMap(e=>(e.majors||[]).filter(g=>P.num(g.connections)>0).map(g=>g.label)))].sort();
    $('companyMajor').innerHTML='<option value="">Any major</option>'+majors.map(m=>`<option value="${U.esc(m)}">${U.esc(m)}</option>`).join('');$('companyMajor').value=majors.includes(oldMajor)?oldMajor:'';
    $('companyFair').innerHTML='<option value="">Any career fair</option>'+fair.events.map(e=>`<option value="${U.esc(e.key)}">${U.esc(e.name)}</option>`).join('');$('companyFair').value=fair.events.some(e=>e.key===oldFair)?oldFair:'';
    renderCompanyDirectory();
  }
  function renderCompanyDirectory(){
    if(!population)return;
    const filters={search:$('companySearch').value.trim(),status:$('companyStatus').value,activity:$('companyActivity').value,major:$('companyMajor').value,event:$('companyFair').value};
    $('previousCompanies').disabled=$('nextCompanies').disabled=true;
    if(!Object.values(filters).some(Boolean)){
      $('employerDirectory').innerHTML='<div class="directory-prompt">Search or choose a filter to show companies.</div>';
      $('companyDirectoryScope').textContent='';$('companyDirectoryPage').textContent='';$('companyPagination').hidden=true;companyPage=0;return;
    }
    const directorySource=population.employers.map(e=>({...e,eventKeys:[...new Set(M.scope(fair.rows,{employer:String(e.company_id)}).map(r=>r.event_key))]}));
    const rows=P.filterCompanies(directorySource,{...filters,sort:$('companySort').value}),size=25;companyPage=Math.min(companyPage,Math.max(0,Math.ceil(rows.length/size)-1));
    const visible=rows.slice(companyPage*size,(companyPage+1)*size);
    $('employerDirectory').innerHTML=visible.length?'<div class="company-directory-list">'+visible.map(e=>{
      const companyRows=M.scope(fair.rows,{employer:String(e.company_id)}),outcomes=M.summarize(companyRows,0,generated.getTime());
      const events=fair.events.map(event=>({name:event.name,date:date(event.date),...M.summarize(M.scope(companyRows,{event:event.key}),0,generated.getTime())})).filter(event=>event.connections>0);
      return U.companyDetails(e,{outcomes,events,lastConnection:date(e.last_connection_at),expanded:rows.length===1});
    }).join('')+'</div>':'<div class="directory-prompt">No companies match these filters.</div>';
    $('companyDirectoryScope').textContent=[filters.search?'Search: '+filters.search:null,filters.status?'Status: '+filters.status:null,filters.activity?'Activity: '+filters.activity:null,filters.major,filters.event?fair.events.find(e=>e.key===filters.event)?.name:null].filter(Boolean).join(' · ');
    $('companyDirectoryPage').textContent=rows.length?`${companyPage*size+1}–${Math.min((companyPage+1)*size,rows.length)} of ${U.number(rows.length)} companies`:'0 companies';
    $('companyPagination').hidden=rows.length===0;$('previousCompanies').disabled=companyPage===0;$('nextCompanies').disabled=(companyPage+1)*size>=rows.length;
  }
  async function load(){
    const token=++loadSequence;$('printWorkspace').disabled=true;
    if($('loadingWorkspace'))$('loadingWorkspace').hidden=false;
    if($('refreshWorkspace'))$('refreshWorkspace').disabled=true;
    try{
      const ctx=await requireUniversityCardAccess();admin=ctx.admin;
      const calls=[tapid.client.rpc('university_engagement_report')];if(mode!=='students')calls.push(tapid.client.rpc('university_fair_report'));
      const results=await Promise.all(calls);if(token!==loadSequence)return;
      for(const r of results)if(r.error)throw r.error;
      population=results[0].data;if(!population?.students||population.engagement_version!==1)throw new Error('Run tapid_engagement_analytics.sql to enable the new engagement analytics.');
      fair=results[1]?.data||{rows:[],events:[]};generated=new Date(population.generated_at);heading();
      if(mode==='overview')overview();if(mode==='students'){students();await loadDirectory();}if(mode==='employers')employers();
      if($('workspaceContent'))$('workspaceContent').hidden=false;
      $('printWorkspace').disabled=false;if(mode!=='students')tapid.setMessage($('pageMessage'),'');
      if(location.hash==='#studentDirectoryPanel')$('studentDirectoryPanel')?.scrollIntoView({block:'start'});
      if(mode==='employers'&&location.hash==='#employerDirectory'){$('employerDirectoryPanel').scrollIntoView({block:'start'});}
    }catch(e){if(token===loadSequence){if($('workspaceContent'))$('workspaceContent').hidden=true;tapid.setMessage($('pageMessage'),e.code==='PGRST202'?'Run tapid_engagement_analytics.sql to enable this view.':e.message,'error');}}
    finally{if(token===loadSequence){if($('loadingWorkspace'))$('loadingWorkspace').hidden=true;if($('refreshWorkspace'))$('refreshWorkspace').disabled=false;}}
  }
  async function loadDirectory(){
    const token=++directorySequence;$('printDirectory').disabled=true;$('previousStudents').disabled=$('nextStudents').disabled=true;
    const active=['studentSearch','studentCollege','studentMajor','studentYear','studentState'].some(id=>$(id).value.trim());
    if(!active){$('studentDirectory').innerHTML='<div class="directory-prompt">Search or choose a filter to show students.</div>';$('directoryScope').textContent='';$('directoryPage').textContent='';$('studentPagination').hidden=true;page=0;directoryTotal=0;tapid.setMessage($('pageMessage'),'');return;}
    $('studentPagination').hidden=false;
    $('studentDirectory').innerHTML='<div class="report-empty">Loading students…</div>';
    try{
      const filters={p_search:$('studentSearch').value.trim(),p_major:$('studentMajor').value,p_year:$('studentYear').value,p_state:$('studentState').value,p_page:page,p_college:$('studentCollege').value};
      const result=await tapid.client.rpc('university_student_directory_filtered',filters);if(token!==directorySequence)return;if(result.error)throw result.error;
      const d=result.data;if(!d||!Array.isArray(d.rows))throw new Error('Student directory returned an unexpected response.');directoryTotal=d.total;tapid.setMessage($('pageMessage'),'');
      if(page>0&&page*50>=d.total){page=Math.max(0,Math.ceil(d.total/50)-1);return loadDirectory();}
      $('studentDirectory').innerHTML=U.table(['Student','College','Major','Class year','Joined','Connections','Last connection'],d.rows.map(s=>[s.username?`<a href="profile.html?u=${encodeURIComponent(s.username)}" target="_blank" rel="noopener">${U.esc(s.name)}</a>`:U.esc(s.name),U.esc(s.college||'Unclassified major'),U.esc(s.major),U.esc(s.class_year),U.esc(date(s.joined_at)),U.number(s.connections),U.esc(date(s.last_connection_at))]));
      $('directoryPage').textContent=d.total?`${page*50+1}–${Math.min((page+1)*50,d.total)} of ${U.number(d.total)} students`:'0 students';
      $('directoryScope').textContent=[filters.p_search?'Search: '+filters.p_search:null,filters.p_college,filters.p_major,filters.p_year,$('studentState').selectedOptions[0].textContent,'Directory page '+(page+1)].filter(Boolean).join(' · ');
      $('previousStudents').disabled=page===0;$('nextStudents').disabled=(page+1)*50>=d.total;$('printDirectory').disabled=false;
    }catch(e){if(token===directorySequence){$('studentDirectory').innerHTML='<div class="report-empty">Unable to load student directory</div>';tapid.setMessage($('pageMessage'),e.code==='PGRST202'?'Student directory database update is missing. Run tapid_student_directory_repair.sql, then refresh.':e.message||'Student directory could not be loaded. Please retry.','error');}}
  }
  let printState=null;
  function restorePrint(){document.body.classList.remove('directory-print');if(!printState)return;
    for(const [el,open]of printState.details)el.open=open;
    if(mode==='employers'){$('employerAnalytics').hidden=printState.analyticsHidden;$('employerApprovalSection').hidden=printState.approvalsHidden;}printState=null;
  }
  function print(){document.body.classList.remove('directory-print');heading();
    printState={details:[...document.querySelectorAll('.college-group,.employer-details')].map(el=>[el,el.open])};
    for(const [el]of printState.details)el.open=true;
    if(mode==='employers'){printState.analyticsHidden=$('employerAnalytics').hidden;printState.approvalsHidden=$('employerApprovalSection').hidden;$('employerAnalytics').hidden=false;$('employerApprovalSection').hidden=true;}
    try{window.print();}catch(error){restorePrint();throw error;}
  }
  $('printWorkspace').onclick=print;window.addEventListener('afterprint',restorePrint);
  if(mode==='employers'){
    const applyCompanyFilters=()=>{companyPage=0;renderCompanyDirectory();};
    $('companySearch').oninput=applyCompanyFilters;['companyStatus','companyActivity','companyMajor','companyFair','companySort'].forEach(id=>$(id).onchange=applyCompanyFilters);
    $('clearCompanyFilters').onclick=()=>{['companySearch','companyStatus','companyActivity','companyMajor','companyFair'].forEach(id=>$(id).value='');applyCompanyFilters();};
    document.addEventListener('click',e=>{const b=e.target.closest('[data-company-quick]');if(!b)return;['companySearch','companyMajor','companyFair'].forEach(id=>$(id).value='');$('companyStatus').value='approved';$('companyActivity').value=b.dataset.companyQuick==='approved'?'':b.dataset.companyQuick;applyCompanyFilters();});
    $('previousCompanies').onclick=()=>{companyPage--;renderCompanyDirectory();};$('nextCompanies').onclick=()=>{companyPage++;renderCompanyDirectory();};
    const activity=new URLSearchParams(location.search).get('connections');if(['zero','connected','1-5','6-20','21-plus','recent'].includes(activity)){$('companyActivity').value=activity;$('companyStatus').value='approved';}
    const view=v=>{const approvals=v==='approvals';$('employerAnalytics').hidden=approvals;$('employerApprovalSection').hidden=!approvals;document.querySelectorAll('[data-employer-view]').forEach(b=>b.classList.toggle('active',b.dataset.employerView===v));};
    $('employerViewTabs').onclick=e=>{const b=e.target.closest('[data-employer-view]');if(b)view(b.dataset.employerView);};
    view(new URLSearchParams(location.search).get('view')==='approvals'?'approvals':'analytics');
    $('refreshApprovals').addEventListener('click',load);window.addEventListener('tapid-employer-approval-updated',load);
  }else{
    $('refreshWorkspace').onclick=load;$('logoutBtn').onclick=async()=>{await tapid.client.auth.signOut();sessionStorage.removeItem('tapid-university-explicit-login');location.replace('university-login.html');};
  }
  if(mode==='students'){
    $('connectionDimension').onchange=()=>{selectedCollege='';connectionCharts();};
    $('backToColleges').onclick=()=>{selectedCollege='';connectionCharts();};
    document.addEventListener('click',e=>{const b=e.target.closest('[data-college-drill]');if(b){selectedCollege=b.dataset.collegeDrill;connectionCharts();}});
    document.addEventListener('click',e=>{const b=e.target.closest('[data-directory-dimension]');if(!b)return;const ids={major:'studentMajor',year:'studentYear',college:'studentCollege'};const id=ids[b.dataset.directoryDimension];if(!id)return;['studentCollege','studentMajor','studentYear','studentState','studentSearch'].forEach(key=>$(key).value='');$(id).value=b.dataset.directoryValue;page=0;loadDirectory();$('studentDirectory').scrollIntoView({behavior:'smooth',block:'center'});});
    $('clearDirectoryFilters').onclick=()=>{['studentCollege','studentMajor','studentYear','studentState','studentSearch'].forEach(id=>$(id).value='');page=0;loadDirectory();};
    const initial=new URLSearchParams(location.search).get('state');if([...$('studentState').options].some(x=>x.value===initial))$('studentState').value=initial;
    let timer;const change=()=>{page=0;clearTimeout(timer);loadDirectory();};
    $('studentSearch').oninput=()=>{clearTimeout(timer);directorySequence++;$('printDirectory').disabled=true;timer=setTimeout(change,250);};
    ['studentCollege','studentMajor','studentYear','studentState'].forEach(id=>$(id).onchange=change);
    $('previousStudents').onclick=()=>{page--;loadDirectory();};$('nextStudents').onclick=()=>{page++;loadDirectory();};
    $('printDirectory').onclick=()=>{document.body.classList.add('directory-print');$('printScope').textContent=admin.school_name+' · '+$('directoryScope').textContent+' · '+$('directoryPage').textContent+' · Generated '+generated.toLocaleString('en-US',{timeZone:'America/Los_Angeles'})+' PT';window.print();};
    $('addStudents').onclick=()=>{$('studentSignupLink').value=tapid.siteUrl('signup.html');$('copyMessage').textContent='';$('addStudentsDialog').showModal();};
    $('closeAddStudents').onclick=()=>$('addStudentsDialog').close();
    $('copySignupLink').onclick=async()=>{try{await navigator.clipboard.writeText($('studentSignupLink').value);$('copyMessage').textContent='Signup link copied.';}catch{$('studentSignupLink').select();$('copyMessage').textContent='Select the link and press Ctrl+C or Command+C.';}};
  }
  load();
})();
