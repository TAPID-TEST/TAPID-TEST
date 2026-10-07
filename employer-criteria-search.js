(function(root){
 const escape=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 root.TapIDExperienceSearch={
  evidenceHtml(result){if(!result)return '';return `<span class="experience-work-count">${result.matching_work_entries} matching work ${result.matching_work_entries===1?'entry':'entries'} · ${result.matches.length} ${result.matches.length===1?'criterion':'criteria'} found</span>`+result.matches.map(match=>`<span class="experience-evidence"><strong>${escape(match.label)}</strong>${match.sources.slice(0,2).map(source=>`<small>${escape(source.kind)} · ${escape(source.title)}${source.organization?' · '+escape(source.organization):''}</small><small>“${escape(source.quote)}”</small>`).join('')}${match.source_count>2?`<small>+${match.source_count-2} more matching entries</small>`:''}</span>`).join('');},
  init({client,onResults}){
   const $=id=>document.getElementById(id),form=$('experienceSearchForm');if(!form)return;
   const input=$('experienceQuery'),button=$('experienceSearchSubmit'),status=$('experienceSearchStatus'),chips=$('experienceCriteria'),reset=$('experienceSearchReset'),mode=$('experienceMatchMode');
   let generation=0,criteria=[],lastQuery='';
   const clear=()=>{generation++;criteria=[];lastQuery='';chips.innerHTML='';status.textContent='Searches public work entries and skills in your connections.';status.dataset.error='false';reset.hidden=true;input.value='';button.disabled=false;button.textContent='Find experience';onResults(null);};
   const search=async event=>{
    event?.preventDefault();const query=input.value.trim();if(query.length<3){status.textContent='Describe the work experience you need.';status.dataset.error='true';return;}
    const mine=++generation;button.disabled=true;button.textContent='Searching…';status.dataset.error='false';status.textContent='Finding documented experience…';chips.innerHTML='';reset.hidden=false;onResults(null);
    try{
     const body=query===lastQuery&&criteria.length?{criteria,mode:mode.value==='auto'?'all':mode.value}:{query,mode:mode.value};
     const response=await client.functions.invoke('search-student-experience',{body});
     if(mine!==generation)return;
     if(response.error){let message='AI search is unavailable. Check the function deployment and your session.';try{const payload=await response.error.context?.json();if(payload?.error)message=payload.error;}catch{}throw new Error(message);}
     const data=response.data;if(!data||!Array.isArray(data.results)||!Array.isArray(data.criteria))throw new Error('Search returned an unexpected response.');
     criteria=data.criteria.map(x=>x.key);lastQuery=query;if(data.mode)mode.value=data.mode;
     chips.innerHTML=data.criteria.map(x=>`<span>${escape(x.label)}</span>`).join('');
     status.textContent=data.message||`${data.results.length} matching ${data.results.length===1?'student':'students'} across ${data.searched} active public profiles · ${data.mode==='any'?'Any':'All'} criteria · Most matching work entries first`;
     onResults(new Map(data.results.map(x=>[x.student_id,x])));
    }catch(error){if(mine===generation){criteria=[];lastQuery='';status.textContent=error.message;status.dataset.error='true';onResults(null);}}
    finally{if(mine===generation){button.disabled=false;button.textContent='Find experience';}}
   };
   form.addEventListener('submit',search);reset.onclick=clear;
   document.querySelectorAll('[data-experience-example]').forEach(b=>b.onclick=()=>{input.value=b.dataset.experienceExample;input.focus();});
   input.addEventListener('input',()=>{if(button.disabled||(lastQuery&&input.value.trim()!==lastQuery)){generation++;criteria=[];lastQuery='';chips.innerHTML='';status.textContent='Search again to apply your edited criteria.';onResults(null);button.disabled=false;button.textContent='Find experience';}});
  }
 };
})(typeof window==='undefined'?globalThis:window);
