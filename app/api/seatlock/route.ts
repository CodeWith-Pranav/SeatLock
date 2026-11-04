export const dynamic='force-dynamic';
export const maxDuration=60;
const base='https://zwzeuapkvcndessfniqm.supabase.co';
const key='sb_publishable_4FCWjIBvh-ZMiWfLuFA1Ww_RsC4aQzi';
const json=(v:unknown,status=200)=>Response.json(v,{status,headers:{'Cache-Control':'no-store'}});
async function handle(req:Request,p:Record<string,unknown>){
 const token=req.headers.get('authorization');if(!token?.startsWith('Bearer '))return json({error:'Sign in to continue.'},401);
 const origin=req.headers.get('origin');if(origin&&origin!==new URL(req.url).origin)return json({error:'Invalid request origin'},403);
 async function rpc(name:string,p:unknown){const r=await fetch(`${base}/rest/v1/rpc/${name}`,{method:'POST',headers:{apikey:key,Authorization:token!,'Content-Type':'application/json'},body:JSON.stringify({p}),cache:'no-store'});const d=await r.json();if(!r.ok)throw Object.assign(new Error(d.message||'Request failed'),{status:r.status});return d;}
 try{
  if(p.action==='lab'){
   const run=await rpc('seatlock_lab',{action:'start'});const start=performance.now();
   const results=await Promise.allSettled(Array.from({length:80},(_,index)=>rpc('seatlock_lab',{action:'attempt',id:run.id,index})));
   const final=await rpc('seatlock_lab',{action:'finish',id:run.id});
   return json({...final,requests:80,rejected:results.filter(r=>r.status==='fulfilled'&&!r.value.accepted).length,errors:results.filter(r=>r.status==='rejected').length,elapsed:Math.round(performance.now()-start)});
  }
  return json(await rpc('seatlock',p));
 }catch(e:any){return json({error:e.message||'Request could not be completed.'},e.status===401?401:400);}
}
export async function GET(req:Request){return handle(req,{});}
export async function POST(req:Request){try{const body=await req.text();if(body.length>20000)return json({error:'Request too large'},413);return handle(req,JSON.parse(body));}catch{return json({error:'Invalid JSON'},400);}}
