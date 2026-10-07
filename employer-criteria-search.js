(function(root){
 const escape=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 root.TapIDCandidateMatch={
  resultHtml(row){return `<article class="match-card"><div class="match-card-head"><span class="match-position">${row.position}</span><div><h3>${escape(row.name)}</h3><p>${escape([row.major,row.year].filter(Boolean).join(' · '))}</p></div><button class="favorite-toggle" type="button" data-match-favorite="${escape(row.student_id)}" aria-label="Favorite ${escape(row.name)}" aria-pressed="false">☆</button></div><div class="match-reasons"><strong>Why this profile matches</strong><p>${escape(row.explanation)}</p></div><div class="match-evidence">${row.matches.map(m=>`<details><summary>${escape(m.label)} <span>${m.source_count} ${m.source_count===1?'source':'sources'}</span></summary>${m.sources.map(s=>`<div><strong>${escape(s.kind)} · ${escape(s.title)}</strong><blockquote>${escape(s.quote)}</blockquote></div>`).join('')}</details>`).join('')}</div>${row.missing_criteria?.length?`<p class="match-missing">Not documented: ${escape(row.missing_criteria.join(', '))}</p>`:''}<div class="match-actions"><button class="btn btn-primary" type="button" data-match-open="${escape(row.student_id)}">View student</button>${row.has_resume?`<button class="btn btn-secondary" type="button" data-match-resume="${escape(row.student_id)}">View résumé</button>`:''}</div></article>`;},
  init({client,onOpen,onResume,onFavorite,isFavorite}){
   const $=id=>document.getElementById(id),form=$('candidateMatchForm');if(!form)return;
   let generation=0;
   const input=$('matchQuery'),button=$('matchSubmit'),status=$('matchStatus'),chips=$('matchCriteria'),results=$('matchResults'),summary=$('matchSummary');
   const clear=()=>{generation++;input.value='';chips.innerHTML='';results.innerHTML='';summary.textContent='';status.textContent='';status.dataset.error='false';['matchEvent','matchYear','matchMajor','matchStage','matchPriority','matchSearch'].forEach(id=>$(id).value='');['matchFavorites','matchAttention'].forEach(id=>$(id).checked=false);button.disabled=false;button.textContent='Find matches';};
   form.onsubmit=async event=>{
    event.preventDefault();const query=input.value.trim();if(query.length<3)return;
    const mine=++generation;button.disabled=true;button.textContent='Finding matches…';status.textContent='Interpreting your criteria and checking the evidence…';status.dataset.error='false';results.innerHTML='';chips.innerHTML='';summary.textContent='';
    try{
     const response=await client.functions.invoke('search-student-experience',{body:{query,event:$('matchEvent').value,year:$('matchYear').value,major:$('matchMajor').value,stage:$('matchStage').value,priority:$('matchPriority').value,search:$('matchSearch').value,favorites:$('matchFavorites').checked,attention:$('matchAttention').checked}});
     if(mine!==generation)return;
     if(response.error){let message='Candidate Match is unavailable. Check that its Supabase function is deployed.';try{const data=await response.error.context?.json();if(data?.error)message=data.error;}catch{}throw new Error(message);}
     const data=response.data;if(!data||!Array.isArray(data.results))throw new Error('Unexpected search response. Try again.');
     const selections=[data.filters?.event,data.filters?.year,data.filters?.major,...(data.criteria||[]).map(c=>c.label),data.filters?.require_resume?'Résumé text included':null].filter(Boolean);
     chips.innerHTML=selections.map(label=>`<span>${escape(label)}</span>`).join('');
     summary.textContent=data.message||`${data.results.length} of ${data.total_matches||0} matching profiles · ${data.searched} reviewed`;
     status.textContent=data.unreadable_resumes?`${data.unreadable_resumes} public ${data.unreadable_resumes===1?'résumé could':'résumés could'} not be read and were excluded. Scanned PDFs need selectable text.`:'';
     if(!data.results.length){results.innerHTML='<div class="match-empty"><h3>No documented matches yet</h3><p>Try a broader fair, class year, or work requirement.</p></div>';return;}
     results.innerHTML=data.results.map(root.TapIDCandidateMatch.resultHtml).join('');
     results.querySelectorAll('[data-match-open]').forEach(b=>b.onclick=()=>onOpen(b.dataset.matchOpen));
     results.querySelectorAll('[data-match-resume]').forEach(b=>b.onclick=()=>onResume(b.dataset.matchResume,status));
     results.querySelectorAll('[data-match-favorite]').forEach(b=>{const sync=()=>{const active=isFavorite(b.dataset.matchFavorite);b.textContent=active?'★':'☆';b.setAttribute('aria-pressed',String(active));};sync();b.onclick=async()=>{b.disabled=true;try{await onFavorite(b.dataset.matchFavorite);sync();}finally{b.disabled=false;}};});
    }catch(error){if(mine===generation){status.textContent=error.message;status.dataset.error='true';}}
    finally{if(mine===generation){button.disabled=false;button.textContent='Find matches';}}
   };
   $('matchClear').onclick=clear;
   [input,$('matchEvent'),$('matchYear'),$('matchMajor'),$('matchStage'),$('matchPriority'),$('matchSearch'),$('matchFavorites'),$('matchAttention')].forEach(node=>node.addEventListener([input,$('matchSearch')].includes(node)?'input':'change',()=>{generation++;results.innerHTML='';chips.innerHTML='';summary.textContent='';status.textContent='';button.disabled=false;button.textContent='Find matches';}));
  }
 };
})(typeof window==='undefined'?globalThis:window);
