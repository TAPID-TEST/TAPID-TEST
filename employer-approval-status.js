function renderEmployerApproval(recruiter,refresh){
  const root=document.getElementById('employerApprovalNotice');if(!root)return;
  const approved=recruiter.verification_status==='verified',declined=recruiter.verification_status==='rejected';
  root.hidden=approved;root.innerHTML='';
  if(approved)return;
  const copy=document.createElement('div'),title=document.createElement('strong'),detail=document.createElement('p');
  title.textContent=declined?'University approval declined':'University approval in review';
  detail.textContent=declined?(recruiter.review_reason||'Contact the university career-services team.'):(recruiter.requested_school||'Your university')+' · '+recruiter.recruiter_email;
  const progress=document.createElement('div');progress.className='approval-progress';
  ['Account created','University review','Recruiting access'].forEach((text,i)=>{const span=document.createElement('span');span.textContent=text;if(i===1)span.className='active';progress.appendChild(span);});
  copy.append(title,detail,progress);const button=document.createElement('button');button.type='button';button.className='btn btn-secondary';button.textContent='Check status';button.onclick=async()=>{button.disabled=true;try{await refresh();}finally{button.disabled=false;}};
  root.append(copy,button);
}
