import {env} from 'cloudflare:workers';
import {getChatGPTUser} from '../../chatgpt-auth';
import Q from '../../../lib/queries.json';
export const dynamic='force-dynamic';
async function visitor(){return await getChatGPTUser() || (import.meta.env.DEV ? {userId:'local-preview',displayName:'Preview organizer',email:'preview@example.test'} : null);}
const db=()=>env.DB!;
const prep=(sql:string,...args:any[])=>db().prepare(sql).bind(...args);
const now=()=>Date.now();
const json=(v:any,status=200)=>Response.json(v,{status,headers:{'Cache-Control':'no-store'}});
function upkeep(id:string,t:number){return [prep(Q.expire,id,t),prep(Q.promote,t+300000,id,id,t,id,id,t)];}
function reserve(id:string,u:any,t:number){return prep(Q.reserve,crypto.randomUUID(),u.userId,u.displayName,u.email,t+300000,t,id,t,t);}
async function seed(u:any){
const t=now();const rows=[['demo-build','Build something that matters.','A hands-on product engineering workshop. Take an idea from a blank page to a working prototype. Bring your laptop and your curiosity.','Workshop','DTU · Innovation Lab',7,48,0],['demo-ai','Beyond the prompt','Explore practical machine learning, evaluation and the systems behind useful AI. A talk followed by an open Q&A.','Talk','DTU · Main Auditorium',10,120,1],['demo-design','Design meets code','An evening of interfaces, interaction design and thoughtful frontend engineering. Build a small experience with fellow creators.','Meetup','DTU · Design Studio',12,30,2],['demo-hack','The midnight build','A focused hack session for makers. Form a small team, choose a challenge and ship a working solution together.','Hackathon','DTU · Computer Centre',15,60,3]];
await db().batch(rows.map(r=>prep('INSERT OR IGNORE INTO events(id,owner,title,description,category,location,starts,capacity,theme,created) VALUES(?,?,?,?,?,?,?,?,?,?)',r[0],u.userId,r[1],r[2],r[3],r[4],t+Number(r[5])*86400000,r[6],r[7],t)));
}
async function data(u:any){
const es=await prep("SELECT * FROM events WHERE kind='event' ORDER BY starts").all();
if(es.results.length)await db().batch(es.results.flatMap((e:any)=>upkeep(e.id,now())));
const events=await prep("SELECT e.*, (SELECT COUNT(*) FROM bookings b WHERE b.event=e.id AND b.status='confirmed') confirmed,(SELECT COUNT(*) FROM bookings b WHERE b.event=e.id AND b.status='held' AND b.expires>?) held,(SELECT COUNT(*) FROM bookings b WHERE b.event=e.id AND b.status='waiting') waiting FROM events e WHERE kind='event' ORDER BY starts",now()).all();
const mine=await prep("SELECT b.*, (SELECT COUNT(*) FROM bookings q WHERE q.event=b.event AND q.status='waiting' AND (q.created<b.created OR (q.created=b.created AND q.id<=b.id))) position FROM bookings b WHERE user=? ORDER BY created DESC",u.userId).all();
return {user:u,events:events.results,bookings:mine.results,serverTime:now()};
}
export async function GET(){try{const u=await visitor();if(!u)return json({error:'Please sign in with ChatGPT to continue.'},401);if(!(await prep("SELECT id FROM events WHERE kind='event' LIMIT 1").first()))await seed(u);return json(await data(u));}catch(e){console.error(e);return json({error:'Could not load SeatLock. Please retry.'},500);}}
export async function POST(req:Request){
try{
const origin=req.headers.get('origin');if(origin&&origin!==new URL(req.url).origin)return json({error:'Invalid request origin'},403);
const u=await visitor();if(!u)return json({error:'Sign in to continue.'},401);
const p=await req.json() as any;const t=now();
if(p.action==='seed'){await seed(u);return json(await data(u));}
if(p.action==='create'||p.action==='edit'){
const x=p.event;if(!x||typeof x.title!=='string'||!x.title.trim()||x.title.length>100||typeof x.description!=='string'||x.description.length>3000||typeof x.location!=='string'||!x.location.trim()||x.location.length>160||!['Workshop','Talk','Meetup','Hackathon'].includes(x.category)||!Number.isInteger(x.capacity)||x.capacity<1||x.capacity>1000||!Number.isFinite(x.starts)||x.starts<t+60000)return json({error:'Enter a title, location, future date and capacity from 1–1,000.'},400);
if(p.action==='create')await prep('INSERT INTO events(id,owner,title,description,category,location,starts,capacity,theme,created) VALUES(?,?,?,?,?,?,?,?,?,?)',crypto.randomUUID(),u.userId,x.title.trim(),x.description,x.category,x.location.trim(),x.starts,x.capacity,Math.floor(Math.random()*4),t).run();
else {const r=await prep("UPDATE events SET title=?,description=?,category=?,location=?,starts=?,capacity=? WHERE id=? AND owner=? AND status='open' AND ? >= (SELECT COUNT(*) FROM bookings WHERE event=? AND (status='confirmed' OR (status='held' AND expires>?)))",x.title.trim(),x.description,x.category,x.location.trim(),x.starts,x.capacity,p.id,u.userId,x.capacity,p.id,t).run();if(!r.meta.changes)return json({error:'Cannot edit: capacity is below active reservations, or event is unavailable.'},409);}
return json(await data(u));
}
if(p.action==='lab'){
const id='lab-'+crypto.randomUUID();await prep("INSERT INTO events(id,owner,title,description,category,location,starts,capacity,kind,created) VALUES(?,?,?,'','Workshop','',?,10,'lab',?)",id,u.userId,'Isolated stress test',t+86400000,t).run();
const start=performance.now();try{const results=await Promise.allSettled(Array.from({length:80},(_,i)=>reserve(id,{userId:'synthetic-'+i,displayName:'Synthetic '+i,email:''},t).run()));const elapsed=Math.round(performance.now()-start);const count=await prep('SELECT COUNT(*) n FROM bookings WHERE event=?',id).first<any>();return json({requests:80,capacity:10,accepted:count.n,rejected:results.filter(r=>r.status==='fulfilled'&&!r.value.meta.changes).length,errors:results.filter(r=>r.status==='rejected').length,elapsed,oversold:Math.max(0,count.n-10)});}finally{await db().batch([prep('DELETE FROM bookings WHERE event=?',id),prep('DELETE FROM events WHERE id=?',id)]);}
}
if(typeof p.id!=='string')return json({error:'Event is required.'},400);
const event=await prep('SELECT * FROM events WHERE id=?',p.id).first<any>();if(!event)return json({error:'Event not found.'},404);
if(['attendees','checkin','close'].includes(p.action)){
if(event.owner!==u.userId)return json({error:'Only the event organizer can do this.'},403);
if(p.action==='attendees'){await db().batch(upkeep(p.id,t));return json((await prep('SELECT * FROM bookings WHERE event=? ORDER BY created',p.id).all()).results);}
if(p.action==='checkin'){const r=await prep("UPDATE bookings SET checked=? WHERE event=? AND id=? AND status='confirmed' AND EXISTS(SELECT 1 FROM events WHERE id=? AND status='open')",p.checked?1:0,p.id,p.booking,p.id).run();if(!r.meta.changes)return json({error:'This ticket is not valid for check-in.'},409);return json({ok:true});}
await db().batch([prep("UPDATE events SET status='cancelled' WHERE id=?",p.id),prep("UPDATE bookings SET status='cancelled',checked=0 WHERE event=? AND status IN ('held','waiting','confirmed')",p.id)]);return json(await data(u));
}
await db().batch(upkeep(p.id,t));
if(p.action==='reserve'||p.action==='wait'){
await db().batch([reserve(p.id,u,t),prep(Q.wait,crypto.randomUUID(),u.userId,u.displayName,u.email,t,p.id,t,t)]);
const b=await prep('SELECT * FROM bookings WHERE event=? AND user=?',p.id,u.userId).first<any>();if(!b||!['held','confirmed','waiting'].includes(b.status))return json({error:'Registration is closed for this event.'},409);
}else if(p.action==='confirm'){await prep(Q.confirm,p.id,u.userId,t,p.id,t).run();const b=await prep('SELECT status FROM bookings WHERE event=? AND user=?',p.id,u.userId).first<any>();if(b?.status!=='confirmed')return json({error:'Your hold expired. Reserve again to continue.'},409);
}else if(p.action==='cancel'){await db().batch([prep("UPDATE bookings SET status='cancelled',checked=0 WHERE event=? AND user=? AND status IN ('held','waiting','confirmed')",p.id,u.userId),...upkeep(p.id,t)]);
}else return json({error:'Unknown action.'},400);
return json(await data(u));
}catch(e){console.error(e);return json({error:'Request could not be completed. Please retry; duplicate reservations are prevented.'},500);}}
