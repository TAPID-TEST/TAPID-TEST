(function(root){
  'use strict';
  const DAY=86400000;
  const stages=[['connected','Connections'],['contacted','Employer activity'],['interview','Interview reached'],['offer','Offer extended'],['accepted_offer','Offer accepted'],['internship','Internship confirmed'],['job','Hired']];
  const employerStages=new Set(['contacted','screening','interview','offer','accepted_offer','internship','job']);
  const stamp=v=>v?Date.parse(v):NaN;
  const pct=(n,d)=>d?Math.round(n/d*100):null;
  const dateKey=v=>{if(!Number.isFinite(stamp(v)))return '';const parts=new Intl.DateTimeFormat('en-US',{timeZone:'America/Los_Angeles',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date(v));const get=t=>parts.find(p=>p.type===t).value;return `${get('year')}-${get('month')}-${get('day')}`;};
  function observed(row){
    const values=(Array.isArray(row.milestones)?row.milestones:[]).filter(x=>Number.isFinite(stamp(x.at)));
    if(Number.isFinite(stamp(row.connected_at)))values.push({stage:'connected',at:row.connected_at});
    if(Number.isFinite(stamp(row.first_follow_up_at)))values.push({stage:'contacted',at:row.first_follow_up_at});
    // Only the current stage is known if historical capture was absent.
    if(row.candidate_status&&Number.isFinite(stamp(row.updated_at)))values.push({stage:row.candidate_status,at:row.updated_at});
    return values;
  }
  function scope(rows,filters={}){
    return rows.filter(r=>(!filters.event||r.event_key===filters.event)&&(!filters.employer||String(r.company_id)===filters.employer)&&(!filters.major||r.major===filters.major)&&(!filters.year||r.school_year===filters.year)&&(!filters.from||dateKey(r.connected_at)>=filters.from)&&(!filters.through||dateKey(r.connected_at)<=filters.through));
  }
  function summarize(rows,days=0,now=Date.now()){
    const reached=Object.fromEntries(stages.map(([s])=>[s,0])),current={},delays=[];
    let mature=0,stale=0;
    for(const row of rows){
      const start=stamp(row.connected_at),cutoff=days?Math.min(now,start+days*DAY):now;
      if(!days||start+days*DAY<=now)mature++;
      const marks=observed(row).filter(x=>stamp(x.at)>=start&&stamp(x.at)<=cutoff);
      const unique=new Set(marks.map(x=>x.stage));
      if([...unique].some(stage=>employerStages.has(stage)))unique.add('contacted');
      for(const [s]of stages)if(unique.has(s))reached[s]++;
      const status=row.candidate_status==='follow_up'?'connected':['internship','accepted_offer'].includes(row.candidate_status)?'offer':row.candidate_status||'connected';current[status]=(current[status]||0)+1;
      const first=stamp(row.first_follow_up_at);
      if(Number.isFinite(first)&&first>=start&&first<=cutoff)delays.push((first-start)/DAY);
      const anyEmployerActivity=observed(row).some(x=>employerStages.has(x.stage)&&stamp(x.at)>=start&&stamp(x.at)<=now);
      if(!Number.isFinite(first)&&!anyEmployerActivity&&now-start>=7*DAY)stale++;
    }
    delays.sort((a,b)=>a-b);
    const median=delays.length?(delays[Math.floor((delays.length-1)/2)]+delays[Math.ceil((delays.length-1)/2)])/2:null;
    return {connections:rows.length,students:new Set(rows.map(r=>r.student_key).filter(Boolean)).size,employers:new Set(rows.map(r=>r.company_id).filter(x=>x!=null)).size,reached,current,mature,stale,median,coverage:pct(reached.contacted,rows.length)};
  }
  function breakdown(rows,field,days,now){
    const groups=new Map();
    for(const row of rows){const id=String(row[field]??'Unspecified');if(!groups.has(id))groups.set(id,[]);groups.get(id).push(row);}
    return [...groups].map(([key,values])=>({key,label:field==='company_id'?(values[0].company_name||'Unnamed employer'):key,...summarize(values,days,now)})).sort((a,b)=>b.connections-a.connections||a.label.localeCompare(b.label));
  }
  function leaderboard(rows,kind='employers'){
    const groups=new Map();
    for(const row of rows){const key=kind==='employers'?String(row.company_id??''):row.student_key;if(!key)continue;
      if(!groups.has(key))groups.set(key,{key,label:kind==='employers'?(row.company_name||'Unnamed employer'):(row.student_name||'Student '+key.slice(0,6)),peers:new Set(),connections:new Set()});
      const g=groups.get(key),peer=kind==='employers'?row.student_key:String(row.company_id??'');if(!peer)continue;g.peers.add(peer);g.connections.add(peer+':'+row.event_key);
    }
    const list=[...groups.values()].map(g=>({key:g.key,label:g.label,connections:g.connections.size,reached:g.peers.size})).sort((a,b)=>b.connections-a.connections||a.label.localeCompare(b.label));
    let rank=0,last=-1;return list.map((g,i)=>{if(g.connections!==last){rank=i+1;last=g.connections;}return {...g,rank};});
  }
  async function loadReport(client){let result=await client.rpc('university_fair_report_v2');let legacy=false;if(result.error?.code==='PGRST202'){legacy=true;result=await client.rpc('university_fair_report');}if(result.error)throw result.error;if(!result.data||!Array.isArray(result.data.rows)||!Array.isArray(result.data.events))throw new Error('Career-fair report returned an unexpected response.');return {data:result.data,legacy};}
  const api={stages,stamp,pct,dateKey,observed,scope,summarize,breakdown,leaderboard,loadReport};
  if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.FairReport=api;
})(typeof globalThis!=='undefined'?globalThis:this);

(function(root){
  'use strict';
  const num=value=>Math.max(0,Number(value)||0);
  const rate=(n,d)=>d>0?Math.round(n/d*100):null;
  function employerSummary(employers){
    return {companies:employers.length,approved:employers.filter(e=>e.status==='approved').length,
      pending:employers.filter(e=>e.status==='pending').length,declined:employers.filter(e=>e.status==='declined').length,
      active:employers.filter(e=>num(e.connections)>0).length,
      approvedActive:employers.filter(e=>e.status==='approved'&&num(e.connections)>0).length,
      pendingRecruiters:employers.reduce((n,e)=>n+num(e.pending_recruiters),0),
      recruiters:employers.reduce((n,e)=>n+num(e.recruiters),0)};
  }
  function setupStates(students){return [
    {label:'Confirm email',value:num(students.unconfirmed),color:'#d5ddd3'},
    {label:'Finish basics',value:num(students.setup_needed),color:'#acc3a9'},
    {label:'Activate profile',value:num(students.ready_to_activate),color:'#73a581'},
    {label:'Active profile',value:num(students.public_active),color:'#15533a'}
  ];}
  function compactGroups(groups,limit=8){
    const sorted=groups.slice().sort((a,b)=>num(b.accounts)-num(a.accounts)||a.label.localeCompare(b.label));
    if(sorted.length<=limit)return sorted;
    return [...sorted.slice(0,limit-1),{label:'Other majors',accounts:sorted.slice(limit-1).reduce((n,g)=>n+num(g.accounts),0)}];
  }
  const api={num,rate,employerSummary,setupStates,compactGroups};
  if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.UniversityPopulation=api;
})(typeof globalThis!=='undefined'?globalThis:this);

// Engagement charts retain every group. Small majors are never hidden in "Other".
(function(root){
 const P=typeof module!=='undefined'&&module.exports?module.exports:root.UniversityPopulation;
 P.engagementGroups=function(rows,dimension,college=''){
  const totals=new Map();
  for(const row of rows||[]){if(college&&row.college!==college)continue;
   const label=row[dimension]||'Not set';const group=totals.get(label)||{label,accounts:0,connected:0,connections:0};
   for(const key of ['accounts','connected','connections'])group[key]+=P.num(row[key]);totals.set(label,group);
  }
  return [...totals.values()].sort((a,b)=>b.connections-a.connections||a.label.localeCompare(b.label));
 };
 P.engagedEmployers=employers=>employers.filter(e=>e.status==='approved');
 P.recentEmployers=employers=>employers.filter(e=>P.num(e.connections_30_days)>0);
})(typeof globalThis!=='undefined'?globalThis:this);

(function(root){
 const P=typeof module!=='undefined'&&module.exports?module.exports:root.UniversityPopulation;
 P.companyActivityMatches=function(e,activity){const n=P.num(e.connections);return !activity||activity==='zero'&&n===0||activity==='connected'&&n>0||activity==='1-5'&&n>=1&&n<=5||activity==='6-20'&&n>=6&&n<=20||activity==='21-plus'&&n>=21||['100-plus','250-plus','500-plus','1000-plus'].includes(activity)&&n>=Number(activity.split('-')[0])||activity==='recent'&&P.num(e.connections_30_days)>0;};
 P.filterCompanies=function(rows,{search='',status='',activity='',major='',event='',sort='connections'}={}){const filtered=rows.filter(e=>(!search||String(e.name||'').toLowerCase().includes(search.trim().toLowerCase()))&&(!status||status==='all'||e.status===status)&&P.companyActivityMatches(e,activity)&&(!major||(e.majors||[]).some(g=>g.label===major&&P.num(g.connections)>0))&&(!event||(e.eventKeys||[]).includes(event)));return filtered.sort((a,b)=>(sort==='name'?0:sort==='students'?P.num(b.students)-P.num(a.students):sort==='recent'?(Date.parse(b.last_connection_at)||0)-(Date.parse(a.last_connection_at)||0):P.num(b.connections)-P.num(a.connections))||String(a.name||'').localeCompare(String(b.name||'')));};
 P.companyDistribution=function(rows){return [['zero','Zero connections'],['1-5','1–5 connections'],['6-20','6–20 connections'],['21-plus','21+ connections']].map(([key,label])=>({key,label,value:rows.filter(e=>P.companyActivityMatches(e,key)).length}));};
})(typeof globalThis!=='undefined'?globalThis:this);

(function(root){
  'use strict';
  const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const number=v=>Number(v||0).toLocaleString();
  function kpis(items){return items.map(x=>{const content=`<strong>${esc(x.value)}</strong><span>${esc(x.label)}</span>`;return x.href?`<a class="report-kpi kpi-link" href="${esc(x.href)}">${content}</a>`:`<article class="report-kpi">${content}</article>`;}).join('');}
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

(function(root){
 const U=root.UniversityUI;
 // Native buttons keep chart navigation available to keyboard and touch users.
 U.categoryBars=function(items,unit='connections'){
  if(!items.length)return '<div class="report-empty">No student accounts yet</div>';
  const max=Math.max(...items.map(x=>Number(x.value)||0),1);
  return '<div class="category-chart" role="group" aria-label="Connections by category">'+items.map(x=>{
   const value=Math.max(0,Number(x.value)||0),attrs=x.college!=null?`data-college-drill="${U.esc(x.college)}"`:x.filter?`data-directory-dimension="${U.esc(x.filter.dimension)}" data-directory-value="${U.esc(x.filter.value)}"`:'';
   return `<button type="button" class="category-column" ${attrs} aria-label="${U.esc(x.label)}: ${U.number(value)} ${U.esc(unit)}"><span class="category-plot"><span class="category-bar" style="height:${value/max*100}%"><strong>${U.number(value)}</strong></span></span><span class="category-label">${U.esc(x.label)}</span></button>`;
  }).join('')+'</div>';
 };
})(typeof globalThis!=='undefined'?globalThis:this);

(function(root){
 const U=root.UniversityUI;
 U.companyDetails=function(company,{outcomes={reached:{}},events=[],lastConnection='—',expanded=false,available=true}={}){
  const num=v=>U.number(v),stat=(label,value)=>`<div class="company-detail-stat"><strong>${U.esc(value)}</strong><span>${U.esc(label)}</span></div>`;
  const outcome=v=>available?num(v):'—';
  const majors=(company.majors||[]).filter(g=>Number(g.connections)>0);
  const count=new Set(majors.map(g=>g.label).filter(label=>label&&!/^(not set|unspecified|unclassified major)$/i.test(label))).size;
  return `<details class="company-directory-entry"${expanded?' open':''}><summary><span class="company-directory-identity"><strong>${U.esc(company.name)}</strong><span class="workspace-status ${U.esc(company.status)}">${U.esc(company.status)}</span></span><span><strong>${num(company.students)}</strong><span>Students reached</span></span><span><strong>${num(company.connections)}</strong><span>Connections</span></span><span><strong>${num(count)}</strong><span>Majors reached</span></span><span class="company-expand-action"><span class="company-view-label">View analytics</span><span class="company-hide-label">Hide analytics</span><span class="company-entry-chevron" aria-hidden="true">⌄</span></span></summary><div class="company-detail-body"><div class="company-detail-heading"><h3>${U.esc(company.name)}</h3><span>Last connection · ${U.esc(lastConnection)}</span></div><div class="company-detail-stats">${stat('Recruiter accounts',num(company.recruiters))}${stat('Approved recruiters',num(company.approved_recruiters))}${stat('Pending recruiter requests',num(company.pending_recruiters))}${stat('Majors reached',num(count))}${stat('Career-fair sources',num(company.events))}</div><div class="company-detail-grid"><section><h4>Connections by major</h4>${majors.length?U.volumeBars(majors.map(g=>({label:g.label,value:g.connections}))):'<p class="directory-prompt">No major connections recorded.</p>'}</section><section><h4>Last 30 days</h4><div class="company-detail-stats">${stat('New connections',num(company.connections_30_days))}${stat('Students reached',num(company.students_30_days))}</div><h4>Recorded outcomes</h4><div class="company-detail-stats">${stat('Interviews',outcome(outcomes.reached.interview))}${stat('Offers extended',outcome(outcomes.reached.offer))}${stat('Offers accepted',outcome(outcomes.reached.accepted_offer))}${stat('Internships confirmed',outcome(outcomes.reached.internship))}${stat('Hires',outcome(outcomes.reached.job))}</div></section></div><section><h4>Career-fair activity</h4>${!available?'<p class="directory-prompt">Fair outcomes are unavailable. Refresh to retry.</p>':events.length?U.table(['Career fair','Date','Students reached','Connections','Interviews','Offers'],events.map(e=>[U.esc(e.name),U.esc(e.date),num(e.students),num(e.connections),num(e.reached.interview),num(e.reached.offer)])):'<p class="directory-prompt">No career-fair connections recorded.</p>'}</section></div></details>`;
 };
})(typeof globalThis!=='undefined'?globalThis:this);

(function(){
  'use strict';
  const $=id=>document.getElementById(id),U=UniversityUI,P=UniversityPopulation,M=FairReport,mode=document.body.dataset.workspace;
  let population=null,fair={rows:[],events:[]},admin=null,generated=null,page=0,directorySequence=0,directoryTotal=0,loadSequence=0,selectedCollege='',companyPage=0,fairDataAvailable=true;
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
      {label:'Company accounts',value:U.number(summary.companies),href:'university-employers.html?status=all#employerDirectory'},
      {label:'Companies with connections',value:U.number(active),href:'university-employers.html?connections=connected#employerDirectory'},
      {label:'Students reached',value:U.number(population.students.approved_employers_students),detail:'Each student counted once across approved companies'},
      {label:'Connection participation',value:pct(active,companies.length),href:'university-employers.html?connections=connected#employerDirectory'}
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
      return U.companyDetails(e,{outcomes,events,lastConnection:date(e.last_connection_at),expanded:rows.length===1,available:fairDataAvailable});
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
      const results=await Promise.all(calls.map(call=>Promise.resolve(call).catch(error=>({error}))));if(token!==loadSequence)return;
      if(results[0].error)throw results[0].error;if(mode!=='employers'&&results[1]?.error)throw results[1].error;
      population=results[0].data;if(!population?.students||population.engagement_version!==1)throw new Error('Run tapid_engagement_analytics.sql to enable the new engagement analytics.');
      fairDataAvailable=!results[1]?.error;fair=results[1]?.data||{rows:[],events:[]};generated=new Date(population.generated_at);heading();
      if(mode==='overview')overview();if(mode==='students'){students();await loadDirectory();}if(mode==='employers')employers();
      if($('workspaceContent'))$('workspaceContent').hidden=false;
      $('printWorkspace').disabled=false;if(mode!=='students')tapid.setMessage($('pageMessage'),mode==='employers'&&!fairDataAvailable?'Employer totals loaded. Detailed fair outcomes are unavailable; refresh to retry.':'',!fairDataAvailable?'error':undefined);
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
    $('previousCompanies').onclick=()=>{companyPage--;renderCompanyDirectory();};$('nextCompanies').onclick=()=>{companyPage++;renderCompanyDirectory();};
    const activity=new URLSearchParams(location.search).get('connections');if(['zero','connected','100-plus','250-plus','500-plus','1000-plus','recent'].includes(activity)){$('companyActivity').value=activity;$('companyStatus').value='approved';}
    const status=new URLSearchParams(location.search).get('status');if(status==='all')$('companyStatus').value='all';
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
