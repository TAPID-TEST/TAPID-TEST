import { createClient } from 'npm:@supabase/supabase-js@2';
function createHandler({createClient,env,fetch:requestFetch}) {
  const headers={'Access-Control-Allow-Origin':'https://tapidcard.com','Access-Control-Allow-Headers':'authorization, apikey, content-type, x-client-info','Access-Control-Allow-Methods':'POST, OPTIONS'};
  const reply=(status,body)=>new Response(JSON.stringify(body),{status,headers:{...headers,'Content-Type':'application/json'}});
  return async request=>{
    if(request.method==='OPTIONS')return new Response(null,{status:204,headers});
    if(request.method!=='POST')return reply(405,{error:'POST required'});
    let server,job;
    try {
      const authorization=request.headers.get('authorization')||'';
      if(!authorization.startsWith('Bearer '))return reply(401,{error:'Sign in required'});
      server=createClient(env('SUPABASE_URL'),env('SUPABASE_SERVICE_ROLE_KEY'),{auth:{persistSession:false,autoRefreshToken:false}});
      const identity=await server.auth.getUser(authorization.slice(7));
      if(identity.error||!identity.data.user)return reply(401,{error:'Sign in required'});
      const body=await request.json();
      if(typeof body.user_id!=='string'||! /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(body.user_id))return reply(400,{error:'Employer account required'});
      const key=env('RESEND_API_KEY'),from=env('TAPID_APPROVAL_FROM');
      if(!key||!from)return reply(503,{error:'Email service is not configured'});
      // This RPC authorizes the verified university and its employer scope on every attempt.
      const claimed=await server.rpc('claim_employer_approval_email',{p_actor:identity.data.user.id,p_user:body.user_id});
      if(claimed.error)return reply(403,{error:claimed.error.message});
      job=claimed.data;
      if(job.state==='sent')return reply(200,{state:'sent'});
      if(job.state==='sending')return reply(202,{state:'sending'});
      const response=await requestFetch('https://api.resend.com/emails',{method:'POST',headers:{'Authorization':`Bearer ${key}`,'Content-Type':'application/json','Idempotency-Key':`tapid-employer-approval-${job.history_id}`},body:JSON.stringify({from,to:[job.payload.to],subject:'Your TapID employer account is approved',text:`Your employer account has been approved by ${job.payload.school}.\n\nSign in to finish your recruiter profile, connect with students, and continue conversations.\n\nhttps://tapidcard.com/employer-login.html\n\nUse the work email you registered with. This link opens the normal sign-in page.`})});
      const result=await response.json();
      if(!response.ok||!result.id)throw new Error('Email provider did not accept the email');
      const saved=await server.from('employer_approval_email_jobs').update({state:'sent',provider_id:result.id,sent_at:new Date().toISOString(),last_error:null}).eq('history_id',job.history_id);
      if(saved.error)return reply(503,{error:'Email accepted; recording its status needs a retry'});
      return reply(200,{state:'sent'});
    }catch(error){
      if(server&&job?.state==='claimed')await server.from('employer_approval_email_jobs').update({state:'failed',last_error:error.message==='Email service is not configured'?error.message:'Email could not be sent. Try again.'}).eq('history_id',job.history_id);
      return reply(503,{error:error.message==='Email service is not configured'?error.message:'Approval email needs a retry'});
    }
  };
}

Deno.serve(createHandler({createClient,env:name=>Deno.env.get(name),fetch}));
