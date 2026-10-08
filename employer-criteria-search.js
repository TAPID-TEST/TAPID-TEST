(function(root){
 const escape=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const examplePrompt='Find my top 3 juniors from the Fall Career Fair for a project engineer internship. Compare their field experience, estimating work, Bluebeam skills, and project leadership. Explain each match using examples from their public TapID.';
 const filters=['matchEvent','matchYear','matchMajor','matchStage','matchPriority','matchSearch','matchFavorites','matchAttention'];
 root.TapIDCandidateMatch={
  resultHtml(row){return `<article class="match-card"><div class="match-card-head"><span class="match-position">${row.position}</span><div><h3>${escape(row.name)}</h3><p>${escape([row.major,row.year].filter(Boolean).join(' · '))}</p></div><button class="favorite-toggle" type="button" data-match-favorite="${escape(row.student_id)}" aria-label="Favorite ${escape(row.name)}" aria-pressed="false">☆</button></div>${row.matches?.length?`<div class="match-reasons"><strong>Why this profile matches</strong><p>${escape(row.explanation)}</p></div><div class="match-evidence">${row.matches.map(m=>`<div class="match-criterion"><strong>${escape(m.label)}</strong><small>${m.strength==='direct'?'Supported by a specific example':'Stated in the public profile'}</small>${m.sources?.[0]?.quote?`<p>“${escape(m.sources[0].quote)}”</p>`:''}</div><details><summary>${escape(m.label)} <span>${m.source_count} ${m.source_count===1?'source':'sources'}</span></summary>${m.sources.map(s=>`<div><strong>${escape(s.kind)} · ${escape(s.title)}</strong><blockquote>${escape(s.quote)}</blockquote></div>`).join('')}</details>`).join('')}</div>`:''}${row.missing_criteria?.length?`<p class="match-missing">Not shown in the public profile: ${escape(row.missing_criteria.join(', '))}</p>`:''}<div class="match-actions"><button class="btn btn-primary" type="button" data-match-open="${escape(row.student_id)}">View student</button>${row.has_resume?`<button class="btn btn-secondary" type="button" data-match-resume="${escape(row.student_id)}">View résumé</button>`:''}</div></article>`;},
  init({client,onOpen,onResume,onFavorite,isFavorite}){
   const $=id=>document.getElementById(id),form=$('candidateMatchForm');if(!form)return;
   let hasSearch=false,generation=0,history=[],lastRows=[],shown=25,overrides=new Set();
   const input=$('matchQuery'),button=$('matchSubmit'),status=$('matchStatus'),chips=$('matchCriteria'),results=$('matchResults'),summary=$('matchSummary'),chat=$('matchConversation'),context=$('matchContext'),historyPanel=$('matchHistory');
   input.placeholder=examplePrompt;
   const setBusy=(busy,label='Find candidates')=>{button.disabled=busy;button.textContent=busy?'Thinking…':label;input.disabled=busy;filters.forEach(id=>$(id).disabled=busy);};
   const bubble=(role,text)=>{const item=document.createElement('div');item.className=`match-chat-message ${role}`;const label=document.createElement('strong');label.textContent=role==='user'?'You':'TapID';const message=document.createElement('p');message.textContent=text;item.append(label,message);chat.appendChild(item);chat.scrollTop=chat.scrollHeight;};
   const clear=()=>{generation++;history=[];lastRows=[];hasSearch=false;shown=25;input.value='';chips.innerHTML='';results.innerHTML='';chat.innerHTML='';summary.textContent='';status.textContent='';status.dataset.error='false';context.textContent='New search';historyPanel.hidden=true;historyPanel.open=false;input.placeholder=examplePrompt;$('matchMore').hidden=true;setBusy(false);input.focus();};
   const draw=()=>{results.innerHTML=lastRows.slice(0,shown).map(root.TapIDCandidateMatch.resultHtml).join('');$('matchMore').hidden=shown>=lastRows.length;
    results.querySelectorAll('[data-match-open]').forEach(b=>b.onclick=()=>onOpen(b.dataset.matchOpen));
    results.querySelectorAll('[data-match-resume]').forEach(b=>b.onclick=()=>onResume(b.dataset.matchResume,status));
    results.querySelectorAll('[data-match-favorite]').forEach(b=>{const sync=()=>{const active=isFavorite(b.dataset.matchFavorite);b.textContent=active?'★':'☆';b.setAttribute('aria-pressed',String(active));};sync();b.onclick=async()=>{b.disabled=true;try{await onFavorite(b.dataset.matchFavorite);sync();}finally{b.disabled=false;}};});
   };
   const invoke=async body=>{const response=await client.functions.invoke('search-student-experience',{body});if(response.error){let message='Candidate Match is unavailable. Check that the updated function is deployed.';try{const data=await response.error.context?.json();if(data?.error)message=data.error;}catch{}throw new Error(message);}return response.data;};
   form.onsubmit=async event=>{
    event.preventDefault();const query=input.value.trim();if(query.length<3)return;
    const mine=++generation;setBusy(true);status.textContent='';status.dataset.error='false';bubble('user',query);
    try{
     const data=await invoke({query,follow_up:hasSearch,filter_overrides:[...overrides],history:history.slice(-8),previous_ids:lastRows.map(r=>r.student_id),event:$('matchEvent').value,year:$('matchYear').value,major:$('matchMajor').value,stage:$('matchStage').value,priority:$('matchPriority').value,search:$('matchSearch').value,favorites:$('matchFavorites').checked,attention:$('matchAttention').checked});
     if(mine!==generation)return;if(!data||!Array.isArray(data.results))throw new Error('Unexpected search response. Try again.');
     const selections=[data.filters?.event,data.filters?.year,data.filters?.major,data.filters?.stage,data.filters?.priority,...(data.criteria||[]).map(c=>c.label),data.filters?.require_resume?'Résumé required':null].filter(Boolean);
     const message=data.assistant_message||data.message||`${data.results.length} matches found.`;bubble('assistant',message);
     if(!data.clarification){hasSearch=true;lastRows=data.results;shown=25;chips.innerHTML=selections.map(label=>`<span>${escape(label)}</span>`).join('');summary.textContent=`${lastRows.length} ${lastRows.length===1?'candidate':'candidates'} found`;draw();}
     history.push({query,summary:(message+' Filters and criteria: '+selections.join(', ')).slice(0,900)});history=history.slice(-8);historyPanel.hidden=false;context.textContent=hasSearch?'Refining previous results':'Clarify your search';input.value='';input.placeholder=hasSearch?'Refine these candidates, or clear search to start fresh…':'Answer the question to finish your search…';
     status.textContent=data.unreadable_resumes?`${data.unreadable_resumes} public résumé(s) could not be read. ${data.filters?.require_resume?'Those profiles were excluded.':'Available profile evidence was still reviewed.'}`:data.clarification?message:'';
     if(data.unreadable_documents)status.textContent+=(status.textContent?' ':'')+`${data.unreadable_documents} public attachment(s) could not be read; available profile details were still reviewed.`;
    }catch(error){if(mine===generation){status.textContent=error.message;status.dataset.error='true';bubble('assistant',error.message);}}
    finally{if(mine===generation){setBusy(false);input.focus();}}
   };
   const keys={matchEvent:'event',matchYear:'year',matchMajor:'major',matchStage:'stage',matchPriority:'priority',matchSearch:'search',matchFavorites:'favorites',matchAttention:'attention'};filters.forEach(id=>$(id).addEventListener(id==='matchSearch'?'input':'change',()=>overrides.add(keys[id])));
   $('matchResetFilters').onclick=()=>{filters.forEach(id=>{const n=$(id);if(id==='matchFavorites'||id==='matchAttention')n.checked=false;else n.value='';});overrides=new Set(Object.values(keys));clear();};
   $('matchClear').onclick=clear;$('matchMore').onclick=()=>{shown+=25;draw();};
  }
 };
})(typeof window==='undefined'?globalThis:window);
