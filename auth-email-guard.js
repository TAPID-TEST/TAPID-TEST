/* Signup/resend UX protection. Server email limits still require SMTP configuration. */
(function(root){
 const tapid=root.tapid;
 if(!tapid)return;
 const original=tapid.friendlyAuthError.bind(tapid),pending=new Set(),fallback=new Map();
 const prefix='tapid-auth-email-v31:';
 const read=key=>{try{return Number(root.sessionStorage.getItem(prefix+key))||0;}catch{return fallback.get(key)||0;}};
 const write=(key,value)=>{fallback.set(key,value);try{root.sessionStorage.setItem(prefix+key,String(value));}catch{}};
 const emailLimit=e=>e?.code==='over_email_send_rate_limit'||/email.*rate.*limit|rate.*limit.*email/i.test(e?.message||'');
 tapid.friendlyAuthError=error=>{
  if(emailLimit(error))return 'Confirmation emails are temporarily limited. Please try again later. If this continues, contact TapID support. We could not confirm email delivery for this attempt.';
  if(error?.code==='email_address_not_authorized')return 'Confirmation email delivery is not configured for this address yet. Please contact TapID support.';
  if(error?.code==='tapid_email_wait'||error?.code==='tapid_email_pending')return error.message;
  return original(error);
 };
 tapid.requestAuthEmail=async(email,operation)=>{
  const key=String(email||'').trim().toLowerCase();
  if(pending.has(key))throw Object.assign(new Error('A request is already in progress. Please wait for it to finish.'),{code:'tapid_email_pending'});
  const until=Math.max(read(key),read('service')),remaining=Math.ceil((until-Date.now())/1000);
  if(remaining>0)throw Object.assign(new Error('Please wait '+remaining+' seconds before requesting another email. The email service may still be limited after that.'),{code:'tapid_email_wait'});
  pending.add(key);
  try{
   const result=await operation();
   if(emailLimit(result?.error)){write('service',Date.now()+60000);}
   else if(!result?.error){write(key,Date.now()+60000);}
   return result;
  }catch(error){
   if(emailLimit(error))write('service',Date.now()+60000);
   throw error;
  }finally{pending.delete(key);}
 };
})(typeof window==='undefined'?globalThis:window);
