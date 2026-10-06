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
