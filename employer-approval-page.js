(function(){
'use strict';const $=id=>document.getElementById(id);let user,recruiter,checking=false;
async function check(initial=false){
  if(checking)return;checking=true;$('checkStatus').disabled=true;
  try{
    if(!user){user=await tapid.requireUser();if(!user)return;}
    recruiter=await TapIDEmployerAccess.recruiterFor(user);
    if(recruiter.verification_status==='verified'){location.replace('employer-dashboard.html');return;}
    const rejected=recruiter.verification_status==='rejected';$('statusBadge').textContent=rejected?'Needs attention':'In review';$('statusTitle').textContent=rejected?'Your approval request was declined.':'Your account is ready for university review.';
    $('statusCopy').textContent=rejected?'Review the university’s message below and contact its career services team about the next step.':`${recruiter.requested_school||'Your university'} is reviewing your employer account. You can keep your recruiter details up to date here.`;
    $('reviewReason').hidden=!rejected;$('reviewReason').textContent=recruiter.review_reason||'Contact the university career services team for more information.';
    $('universityName').textContent=recruiter.requested_school||'University';$('workEmail').textContent=user.email;
    if(initial){$('recruiterName').value=recruiter.recruiter_name||'';$('recruiterTitle').value=recruiter.title||'';$('recruiterPhone').value=recruiter.phone||'';}
    const company=await tapid.client.from('companies').select('name').eq('id',recruiter.company_id).single();if(company.error)throw company.error;$('companyName').textContent=company.data.name;$('saveProfile').disabled=false;
    if(!initial)tapid.setMessage($('message'),rejected?'Your request needs attention.':'Your account is still in review.','success');
  }catch(e){tapid.setMessage($('message'),e.message||'Could not check approval status.','error');}
  finally{checking=false;$('checkStatus').disabled=false;}
}
$('checkStatus').onclick=()=>check();
$('profileForm').onsubmit=async e=>{e.preventDefault();if(!user||!recruiter)return;tapid.setBusy($('saveProfile'),true,'Saving…');try{const r=await tapid.client.from('employer_recruiters').update({recruiter_name:$('recruiterName').value.trim(),title:$('recruiterTitle').value.trim()||null,phone:$('recruiterPhone').value.trim()||null,updated_at:new Date().toISOString()}).eq('user_id',user.id);if(r.error)throw r.error;tapid.setMessage($('message'),'Recruiter details saved.','success');}catch(e){tapid.setMessage($('message'),e.message,'error');}finally{tapid.setBusy($('saveProfile'),false);}};
$('logoutBtn').onclick=async()=>{await tapid.client.auth.signOut();location.replace('employer-login.html');};check(true);
})();
