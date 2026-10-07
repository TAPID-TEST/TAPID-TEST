(function(root){
 'use strict';
 const esc=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 function unread(items){return (items||[]).filter(item=>!item.read_at);}
 function fairDate(fair){return fair.starts_at?new Date(fair.starts_at).toLocaleString(undefined,{timeZone:'America/Los_Angeles',month:'short',day:'numeric',hour:'numeric',minute:'2-digit'}):'Date to be announced';}
 function employerCards(fairs){return fairs.length?fairs.map(f=>`<article class="compact-row"><span class="eyebrow">Listed by the university</span><strong>${esc(f.name)}</strong><small>${esc(fairDate(f))}${f.location?' · '+esc(f.location):''}</small>${f.description?`<p class="subtle">${esc(f.description)}</p>`:''}</article>`).join(''):'<div class="inline-empty">Your company is not listed for an upcoming published fair.</div>';}
 root.TapIDFairUI={unread,fairDate,employerCards};
})(typeof window==='undefined'?globalThis:window);
