'use strict';
let adminPrograms=[],adminStudents=[],selectedAdminStudent=null,adminLookupSequence=0,adminCardBusy=false;
const adminNode=id=>document.getElementById(id);
const adminEscape=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const adminDate=v=>v?new Date(v).toLocaleString('en-US',{timeZone:'America/Los_Angeles'}):'—';
function adminTable(headers,rows){return rows.length?'<table class="report-table"><thead><tr>'+headers.map(h=>'<th scope="col">'+adminEscape(h)+'</th>').join('')+'</tr></thead><tbody>'+rows.map(row=>'<tr>'+row.map(c=>'<td>'+c+'</td>').join('')+'</tr>').join('')+'</tbody></table>':'<p class="directory-prompt">No records found.</p>';}
function renderAdminPrograms(){
 const query=adminNode('programSearch').value.trim().toLowerCase(),college=adminNode('programCollege').value;
 const values=adminPrograms.filter(p=>(!query||p.name.toLowerCase().includes(query))&&(!college||p.college_name===college));
 adminNode('programCount').textContent=values.length+' programs';adminNode('programList').innerHTML=adminTable(['Major','College'],values.map(p=>[adminEscape(p.name),adminEscape(p.college_name||'Unclassified')]));
}
async function loadAdminCatalog(){
 adminPrograms=window.CalPolyPrograms||[];
 // Do not label a Cal Poly catalog as another university's catalog.
 if(!window.TapIDProgramCatalog.isCalPoly(admin.school_name))adminPrograms=[];
 try{adminPrograms=await window.TapIDProgramCatalog.load(admin.school_name);}catch(error){if(!adminPrograms.length){adminNode('programList').textContent='The approved program catalog could not be loaded.';return;}}
 adminNode('programCollege').innerHTML='<option value="">All colleges</option>'+[...new Set(adminPrograms.map(p=>p.college_name).filter(Boolean))].sort().map(c=>'<option value="'+adminEscape(c)+'">'+adminEscape(c)+'</option>').join('');renderAdminPrograms();
}
function clearAdminSelection(){selectedAdminStudent=null;adminNode('selectedCardStudent').hidden=true;adminNode('cardForm').hidden=true;adminNode('issueCardBtn').disabled=true;}
async function lookupAdminStudent(){
 const sequence=++adminLookupSequence,query=adminNode('adminStudentSearch').value.trim();clearAdminSelection();
 if(!query){adminNode('studentLookupResults').textContent='Enter a student name or username.';return;}
 adminNode('findStudentBtn').disabled=true;adminNode('studentLookupResults').textContent='Finding students…';
 try{await requireUniversityCardAccess(user?.id);const result=await tapid.client.rpc('university_admin_card_lookup',{p_search:query});if(result.error)throw result.error;if(sequence!==adminLookupSequence)return;
 adminStudents=result.data?.rows||[];
 adminNode('studentLookupResults').innerHTML=adminStudents.length?adminStudents.map((s,i)=>`<button type="button" class="admin-student-result" data-admin-student="${i}"><span><strong>${adminEscape(s.name)}</strong><small>${adminEscape(s.username||'Username not set')} · ${s.public_active?'Profile active':'Profile not activated'}</small></span><span>${s.cards.length} card${s.cards.length===1?'':'s'} · View →</span></button>`).join('')+(result.data.total>20?'<p class="workspace-caption">Showing 20 matches. Refine your search to find the student.</p>':''):'<p class="directory-prompt">No students at your university match this search.</p>';
 }catch(e){if(sequence===adminLookupSequence)adminNode('studentLookupResults').textContent=e.code==='PGRST202'?'Install the administration SQL update to enable student/card lookup.':e.message||'Lookup failed. Try again.';}
 finally{if(sequence===adminLookupSequence)adminNode('findStudentBtn').disabled=false;}
}
function chooseAdminStudent(index){
 if(adminCardBusy)return;selectedAdminStudent=adminStudents[index];if(!selectedAdminStudent)return;
 adminNode('cardForm').reset();adminNode('cardForm').hidden=true;adminNode('selectedCardStudent').hidden=false;
 adminNode('cardUsername').value=selectedAdminStudent.username||'';
 adminNode('openCardForm').disabled=!selectedAdminStudent.username;
 adminNode('selectedStudentSummary').innerHTML=`<h3>${adminEscape(selectedAdminStudent.name)}</h3><p>${selectedAdminStudent.public_active?'Profile active':'Profile awaiting activation'}${!selectedAdminStudent.username?' · Set a username before issuing a card.':''}</p>`+adminTable(['Card serial','Status','Issued','Activated'],selectedAdminStudent.cards.map(c=>[adminEscape(c.card_serial),adminEscape(c.status),adminEscape(adminDate(c.issued_at)),adminEscape(adminDate(c.activated_at))]));
}
async function loadAdminActivity(){
 adminNode('cardActivity').textContent='Loading card activity…';adminNode('refreshCardActivity').disabled=true;
 try{await requireUniversityCardAccess(user?.id);const result=await tapid.client.rpc('university_admin_card_activity');if(result.error)throw result.error;adminNode('cardActivity').innerHTML=adminTable(['Student','Card serial','Status','Issued','Activated'],(result.data||[]).map(c=>[adminEscape(c.student_name),adminEscape(c.card_serial),adminEscape(c.status),adminEscape(adminDate(c.issued_at)),adminEscape(adminDate(c.activated_at))]));}
 catch(e){adminNode('cardActivity').textContent=e.code==='PGRST202'?'Install the administration SQL update to enable card activity.':e.message||'Card activity could not be loaded.';}
 finally{adminNode('refreshCardActivity').disabled=false;}
}
document.querySelectorAll('[data-admin-panel]').forEach(button=>button.addEventListener('click',()=>{
 document.querySelectorAll('[data-admin-panel]').forEach(b=>{b.classList.toggle('active',b===button);b.setAttribute('aria-pressed',String(b===button));});
 document.querySelectorAll('[data-admin-section]').forEach(s=>s.hidden=s.dataset.adminSection!==button.dataset.adminPanel);
 if(button.dataset.adminPanel==='activity')loadAdminActivity();
}));
adminNode('programSearch').oninput=renderAdminPrograms;adminNode('programCollege').onchange=renderAdminPrograms;
adminNode('studentLookupForm').onsubmit=e=>{e.preventDefault();if(!adminCardBusy)lookupAdminStudent();};
adminNode('adminStudentSearch').oninput=()=>{if(adminCardBusy)return;adminLookupSequence++;clearAdminSelection();adminNode('findStudentBtn').disabled=!adminNode('adminStudentSearch').value.trim();};
adminNode('studentLookupResults').addEventListener('click',e=>{const b=e.target.closest('[data-admin-student]');if(b)chooseAdminStudent(Number(b.dataset.adminStudent));});
adminNode('openCardForm').onclick=()=>{if(!selectedAdminStudent?.username)return;adminNode('cardForm').hidden=false;adminNode('issueCardBtn').disabled=false;adminNode('cardSerial').focus();};
adminNode('closeCardForm').onclick=()=>{if(!adminCardBusy){adminNode('cardForm').hidden=true;adminNode('issueCardBtn').disabled=true;}};
adminNode('refreshCardActivity').onclick=loadAdminActivity;
adminNode('cardForm').addEventListener('submit',async e=>{
 e.preventDefault();const button=adminNode('issueCardBtn');if(button.disabled||adminCardBusy||!selectedAdminStudent)return;
 const username=selectedAdminStudent.username,serial=adminNode('cardSerial').value.trim();if(!serial)return;
 adminCardBusy=true;adminNode('findStudentBtn').disabled=true;tapid.setBusy(button,true,'Issuing…');
 try{await requireUniversityCardAccess(user?.id);if(adminNode('cardUsername').value!==username)throw new Error('Select the student again before issuing a card.');const result=await tapid.client.rpc('issue_tapid_card',{p_username:username,p_card_serial:serial,p_notes:adminNode('cardNotes').value.trim()||null});if(result.error)throw result.error;
 tapid.setMessage(adminNode('message'),`Card ${serial} issued to ${username}. The student can activate it from their Card page.`,'success');adminNode('cardForm').reset();await lookupAdminStudent();}
 catch(e){tapid.setMessage(adminNode('message'),e.message||'Could not issue the card.','error');}
 finally{adminCardBusy=false;tapid.setBusy(button,false);button.disabled=adminNode('cardForm').hidden;adminNode('findStudentBtn').disabled=false;}
});
