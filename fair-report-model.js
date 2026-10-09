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
