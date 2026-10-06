(function(){
'use strict';
const $=id=>document.getElementById(id),escape=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let fairs=[],companies=[],roster=[],fairId=null,dirty=false,saving=false,review=null;
function message(text,type='success'){tapid.setMessage($('pageMessage'),text,type);}
function markDirty(){dirty=true;$('dirtyStatus').textContent='Unsaved changes';updateSummary();}
function updateSummary(){const name=$('fairName').value.trim()||'New career fair';$('saveFair').textContent=$('fairPublished').checked?'Save & show to students':'Save draft';$('saveSummary').textContent=`${name} · ${roster.length} ${roster.length===1?'company':'companies'} · ${$('fairPublished').checked?'Visible to students':'Draft'}`;}
function match(row){const exact=companies.filter(c=>c.name.trim().toLowerCase()===row.name.trim().toLowerCase());if(exact.length===1&&!row.company_id)row.company_id=exact[0].id;return row;}
function renderRoster(){
  $('rosterCount').textContent=`${roster.length} ${roster.length===1?'company':'companies'}`;$('rosterEmpty').hidden=roster.length>0;
  $('roster').innerHTML=roster.length?`<table><thead><tr><th>Company</th><th>TapID account</th><th></th></tr></thead><tbody>${roster.map((r,i)=>`<tr><td><strong>${escape(r.name)}</strong>${r.external_id?`<span class="company-status">${escape(r.external_id)}</span>`:''}</td><td><select data-company-index="${i}" aria-label="Match ${escape(r.name)}"><option value="" ${r.company_id?'disabled':''}>Not linked yet</option>${companies.map(c=>`<option value="${escape(c.id)}" ${String(c.id)===String(r.company_id)?'selected':''}>${escape(c.name)}</option>`).join('')}</select></td><td>${r.saved?'<span class="subtle">Saved</span>':`<button class="remove-company" type="button" data-remove-index="${i}" aria-label="Remove ${escape(r.name)}">Remove</button>`}</td></tr>`).join('')}</tbody></table>`:'';
  $('roster').querySelectorAll('[data-remove-index]').forEach(b=>b.onclick=()=>{roster.splice(Number(b.dataset.removeIndex),1);markDirty();renderRoster();});
  $('roster').querySelectorAll('[data-company-index]').forEach(s=>s.onchange=()=>{roster[Number(s.dataset.companyIndex)].company_id=s.value?Number(s.value):null;markDirty();});updateSummary();
}
function renderList(){
  $('fairList').innerHTML=fairs.length?fairs.map(f=>`<button type="button" class="fair-list-item ${f.id===fairId?'active':''}" data-fair-id="${escape(f.id)}"><strong>${escape(f.name)}</strong><small>${escape(f.start_local?f.start_local.slice(0,10):'Date to be announced')} · ${f.published?'Visible':'Draft'}</small></button>`).join(''):'<p class="subtle">Your first fair will appear here.</p>';
  $('fairList').querySelectorAll('[data-fair-id]').forEach(b=>b.onclick=()=>{if(saving)return;if(dirty&&!window.confirm('Discard unsaved changes and open this fair?'))return;openFair(fairs.find(f=>String(f.id)===b.dataset.fairId));});
}
function dismissImport(){review=null;$('importReview').hidden=true;$('companyCsv').value='';}
function openFair(f){
  fairId=f?.id??null;roster=(f?.companies||[]).map(r=>({...r,saved:true}));$('fairForm').reset();
  $('fairName').value=f?.name||'';$('fairStart').value=f?.start_local||'';$('fairEnd').value=f?.end_local||'';$('fairLocation').value=f?.location||'';$('fairDescription').value=f?.description||'';$('fairPublished').checked=Boolean(f?.published);
  $('editorTitle').textContent=f?'Edit career fair':'New career fair';dirty=false;$('dirtyStatus').textContent='';dismissImport();
  $('viewFairReport').hidden=!f?.published;if(f)$('viewFairReport').href=`university-fairs.html?fair=${encodeURIComponent('fair:'+f.id)}`;renderList();renderRoster();
}
async function load(){
  const result=await tapid.client.rpc('university_fair_setup_list');if(result.error)throw result.error;
  fairs=result.data.fairs||[];companies=result.data.companies||[];
  $('knownCompanies').innerHTML=companies.map(c=>`<option value="${escape(c.name)}"></option>`).join('');renderList();
}
$('newFair').onclick=()=>{if(saving)return;if(dirty&&!window.confirm('Discard unsaved changes and start a new fair?'))return;openFair(null);$('fairName').focus();};
$('refreshFairs').onclick=async()=>{if(saving)return;if(dirty){message('Save your changes before refreshing.','error');return;}try{await load();openFair(fairs.find(f=>f.id===fairId)||null);}catch(e){message(e.message,'error');}};
$('fairForm').addEventListener('input',e=>{if(e.target.id!=='companyName'&&e.target.id!=='companyCsv')markDirty();});
$('addCompany').onclick=()=>{const name=$('companyName').value.trim();if(!name){$('companyName').focus();return;}if(roster.length>=2000){message('A fair can have up to 2,000 companies in this editor.','error');return;}if(roster.some(r=>r.name.toLowerCase()===name.toLowerCase())){message('This company is already in the list.','error');return;}roster.push(match({name,external_id:'',company_id:null,saved:false}));$('companyName').value='';markDirty();renderRoster();};
$('companyName').addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();$('addCompany').click();}});
$('companyTemplate').onclick=()=>{const blob=new Blob(['company_name,external_employer_id\r\nExample Company,\r\n'],{type:'text/csv;charset=utf-8'}),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='tapid-company-list-template.csv';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};
$('dismissImport').onclick=dismissImport;
$('companyCsv').onchange=async e=>{const file=e.target.files[0];if(!file)return;try{if(file.size>5*1024*1024)throw new Error('Choose a CSV smaller than 5 MB.');review=TapIDFairImport.review(await file.text(),roster);$('importReview').hidden=false;$('importStats').textContent=`${review.valid.length} ready to add · ${review.duplicates} duplicates skipped · ${review.errors.length} rows need attention`;$('importErrors').textContent=review.errors.slice(0,8).join(' ') + (review.errors.length>8?' More errors in the CSV.':'');$('importRows').innerHTML=`<table><tbody>${review.valid.slice(0,20).map(r=>`<tr><td>${escape(r.name)}</td><td>${escape(r.external_id)}</td></tr>`).join('')}</tbody></table>${review.valid.length>20?'<p class="subtle">Showing the first 20 companies.</p>':''}`;$('applyImport').disabled=!review.valid.length;}catch(error){dismissImport();message(error.message,'error');}};
$('applyImport').onclick=()=>{if(!review)return;const current=new Set(roster.map(r=>r.name.toLowerCase())),add=review.valid.filter(r=>!current.has(r.name.toLowerCase()));if(roster.length+add.length>2000){message('Keep the company list to 2,000 companies or fewer.','error');return;}roster.push(...add.map(match));dismissImport();markDirty();renderRoster();message(`${add.length} companies added to the list. Save the fair to finish.`);};
$('fairForm').onsubmit=async e=>{
  e.preventDefault();if(saving)return;if(review){message('Add or discard the import preview before saving.','error');$('importReview').scrollIntoView({behavior:'smooth'});return;}
  if($('companyName').value.trim()){message('Click Add company to include the company you entered.','error');$('companyName').focus();return;}
  if($('fairEnd').value&&(!$('fairStart').value||$('fairEnd').value<$('fairStart').value)){message('End time must follow the start time.','error');return;}
  saving=true;const controls=[...$('fairForm').querySelectorAll('input,textarea,select,button')];controls.forEach(c=>c.disabled=true);$('newFair').disabled=true;$('refreshFairs').disabled=true;tapid.setBusy($('saveFair'),true,'Saving…');
  try{
    await requireUniversityCardAccess();const r=await tapid.client.rpc('university_save_fair_setup',{p_fair_id:fairId,p_name:$('fairName').value.trim(),p_start_local:$('fairStart').value||null,p_end_local:$('fairEnd').value||null,p_location:$('fairLocation').value.trim(),p_description:$('fairDescription').value.trim(),p_published:$('fairPublished').checked,p_companies:roster.map(r=>({name:r.name,external_id:r.external_id||'',company_id:r.company_id||null}))});
    if(r.error)throw r.error;fairId=r.data.fair_id;dirty=false;roster.forEach(r=>r.saved=true);$('dirtyStatus').textContent='Saved';
    try{await load();openFair(fairs.find(f=>f.id===fairId));}catch(error){renderRoster();renderList();message(`Fair saved. The list could not refresh: ${error.message}`,'error');return;}
    message(`Fair saved${r.data.published?' and visible to students':' as a draft'}. ${r.data.companies_saved} companies in the list.`);
  }catch(error){message(error.message||'Could not save. Your changes are still in the form.','error');}
  finally{saving=false;controls.forEach(c=>c.disabled=false);$('newFair').disabled=false;$('refreshFairs').disabled=false;tapid.setBusy($('saveFair'),false);updateSummary();}
};
window.addEventListener('beforeunload',e=>{if(dirty&&!saving){e.preventDefault();e.returnValue='';}});
$('logoutBtn').onclick=async()=>{if(saving)return;if(dirty&&!window.confirm('Discard unsaved changes and log out?'))return;dirty=false;await tapid.client.auth.signOut();location.replace('university-login.html');};
(async()=>{try{const context=await requireUniversityCardAccess();$('schoolName').textContent=context.admin.school_name;attachUniversitySessionNotice(context.user.id);await load();$('setupLoading').hidden=true;$('setupWorkspace').hidden=false;$('newFair').disabled=false;const requested=new URLSearchParams(location.search).get('fair');openFair(fairs.find(f=>String(f.id)===requested)||null);}catch(error){$('setupLoading').hidden=true;message(error.message,'error');}})();
})();
