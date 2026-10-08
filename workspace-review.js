(function(root){
 const labels={connected:'New',follow_up:'New',contacted:'Contacted',screening:'Under review',interview:'Interview',offer:'Offer extended',accepted_offer:'Offer accepted',internship:'Internship confirmed',job:'Hired',passed:'Closed'};
 const api={
  stage:s=>labels[s]||s||'New',
  participation:(connected,total)=>total>0?Math.round(connected/total*100):null,
  fairState:(event,now=Date.now())=>{const start=Date.parse(event.date),end=Date.parse(event.ends_at||event.end_at);if(Number.isFinite(end))return end<=now?'completed':Number.isFinite(start)&&start<=now?'in-progress':'upcoming';return Number.isFinite(start)?start<now?'past':'upcoming':'undated';},
  defaultFair:(events,now=Date.now())=>events.filter(e=>['completed','past'].includes(api.fairState(e,now))).sort((a,b)=>Date.parse(b.ends_at||b.end_at||b.date)-Date.parse(a.ends_at||a.end_at||a.date))[0]?.key||'',
  evidenceDetails:row=>(row.matches||[]).map(m=>({label:m.label,strength:m.strength||'stated',sources:(m.sources||[]).slice(0,2).map(s=>({kind:s.kind,title:s.title,quote:s.quote}))})),
  interestSections:doc=>(doc?.entries||[]).find(e=>e.kind==='Career interests')?.fields||{},
  publicHighlights:doc=>(doc?.entries||[]).filter(e=>['Experience','Project'].includes(e.kind)).slice(0,2),
  alertCount:(fairAlerts,messages)=>fairAlerts.length+messages.filter(m=>m.sender_role==='student'&&!m.read_at).length,
  taskCount:(requests,due)=>requests.length+due.length
 };
 root.TapIDReview=api;if(typeof module!=='undefined'&&module.exports)module.exports=api;
})(typeof globalThis!=='undefined'?globalThis:this);
