/* Shared employer routing; university approval remains a database decision. */
window.TapIDEmployerAccess={
  async recruiterFor(user){
    const r=await tapid.client.from('employer_recruiters').select('*').eq('user_id',user.id).maybeSingle();
    if(r.error)throw r.error;if(r.data)return r.data;
    const meta=user.user_metadata||{};
    if(meta.user_type!=='employer'||!meta.employer_company||!meta.recruiter_name)throw new Error('Sign in with an employer account.');
    const created=await tapid.client.rpc('register_employer',{p_company_name:meta.employer_company,p_recruiter_name:meta.recruiter_name,p_recruiter_email:user.email});
    if(created.error)throw created.error;return created.data;
  },
  route(recruiter){return recruiter.verification_status==='verified'?'employer-dashboard.html':'employer-approval.html';}
};
