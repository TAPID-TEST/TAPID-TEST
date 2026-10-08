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
 P.companyActivityMatches=function(e,activity){const n=P.num(e.connections);return !activity||activity==='zero'&&n===0||activity==='connected'&&n>0||activity==='1-5'&&n>=1&&n<=5||activity==='6-20'&&n>=6&&n<=20||activity==='21-plus'&&n>=21||activity==='recent'&&P.num(e.connections_30_days)>0;};
 P.filterCompanies=function(rows,{search='',status='',activity='',major='',event='',sort='connections'}={}){const filtered=rows.filter(e=>(!search||String(e.name||'').toLowerCase().includes(search.trim().toLowerCase()))&&(!status||e.status===status)&&P.companyActivityMatches(e,activity)&&(!major||(e.majors||[]).some(g=>g.label===major&&P.num(g.connections)>0))&&(!event||(e.eventKeys||[]).includes(event)));return filtered.sort((a,b)=>(sort==='name'?0:sort==='students'?P.num(b.students)-P.num(a.students):sort==='recent'?(Date.parse(b.last_connection_at)||0)-(Date.parse(a.last_connection_at)||0):P.num(b.connections)-P.num(a.connections))||String(a.name||'').localeCompare(String(b.name||'')));};
 P.companyDistribution=function(rows){return [['zero','Zero connections'],['1-5','1–5 connections'],['6-20','6–20 connections'],['21-plus','21+ connections']].map(([key,label])=>({key,label,value:rows.filter(e=>P.companyActivityMatches(e,key)).length}));};
})(typeof globalThis!=='undefined'?globalThis:this);
