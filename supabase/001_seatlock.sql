create table public.events(id text primary key,owner uuid not null,title text not null,description text not null,category text not null,location text not null,starts bigint not null,capacity integer not null check(capacity between 1 and 1000),status text not null default 'open',theme integer not null default 0,kind text not null default 'event',created bigint not null);
create table public.bookings(id text primary key,event text references public.events(id) on delete cascade not null,"user" uuid not null,name text not null,email text not null,status text not null check(status in ('held','waiting','confirmed','expired','cancelled')),expires bigint not null default 0,created bigint not null,checked integer not null default 0,unique(event,"user"));
create index booking_event_status on public.bookings(event,status,created,id);
alter table public.events enable row level security;
alter table public.bookings enable row level security;
revoke all on public.events,public.bookings from anon,authenticated;
create function public.seatlock_upkeep(eid text,t bigint) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare slots integer;
begin
 perform 1 from events where id=eid for update;
 update bookings set status='expired' where event=eid and status='held' and expires<=t;
 select greatest(0,e.capacity-(select count(*) from bookings b where b.event=eid and b.status in ('held','confirmed'))) into slots from events e where e.id=eid and e.status='open' and e.starts>t;
 if slots>0 then update bookings set status='held',expires=t+300000 where id in(select id from bookings where event=eid and status='waiting' order by created,id limit slots);end if;
end $$;
revoke all on function public.seatlock_upkeep(text,bigint) from public,anon,authenticated;
create function public.seatlock(p jsonb default '{}') returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare u uuid:=auth.uid();a text:=coalesce(p->>'action','data');t bigint:=floor(extract(epoch from clock_timestamp())*1000);eid text:=p->>'id';e events%rowtype;b bookings%rowtype;x jsonb:=p->'event';nm text;em text;cap integer;st bigint;eid2 text;outdata jsonb;
begin
 perform pg_advisory_xact_lock(812733001);
 if u is null then raise exception 'Sign in to continue.' using errcode='28000';end if;
 select coalesce(nullif(raw_user_meta_data->>'display_name',''),split_part(email,'@',1),'Member'),coalesce(email,'') into nm,em from auth.users where id=u;
 if a='seed' or (a='data' and not exists(select 1 from events where kind='event')) then
  insert into events(id,owner,title,description,category,location,starts,capacity,theme,created) values
  ('demo-build',u,'Build something that matters.','A hands-on product engineering workshop. Take an idea from a blank page to a working prototype. Bring your laptop and your curiosity.','Workshop','DTU · Innovation Lab',t+604800000,48,0,t),
  ('demo-ai',u,'Beyond the prompt','Explore practical machine learning, evaluation and the systems behind useful AI. A talk followed by an open Q&A.','Talk','DTU · Main Auditorium',t+864000000,120,1,t),
  ('demo-design',u,'Design meets code','An evening of interfaces, interaction design and thoughtful frontend engineering. Build a small experience with fellow creators.','Meetup','DTU · Design Studio',t+1036800000,30,2,t),
  ('demo-hack',u,'The midnight build','A focused hack session for makers. Form a small team, choose a challenge and ship a working solution together.','Hackathon','DTU · Computer Centre',t+1296000000,60,3,t) on conflict do nothing;
 elsif a in ('create','edit') then
  if x is null or coalesce(length(trim(x->>'title')),0) not between 1 and 100 or coalesce(length(x->>'description'),3001)>3000 or coalesce(length(trim(x->>'location')),0) not between 1 and 160 or coalesce(x->>'category','') not in('Workshop','Talk','Meetup','Hackathon') or coalesce(x->>'capacity','') !~ '^[0-9]+$' then raise exception 'Enter a valid title, description, category, location and capacity.';end if;
  cap:=(x->>'capacity')::integer;st:=(x->>'starts')::bigint;
  if cap not between 1 and 1000 or st is null or st<t+60000 then raise exception 'Use a future date and capacity from 1–1,000.';end if;
  if a='create' then insert into events(id,owner,title,description,category,location,starts,capacity,theme,created) values(gen_random_uuid()::text,u,trim(x->>'title'),x->>'description',x->>'category',trim(x->>'location'),st,cap,floor(random()*4)::int,t);
  else
   select * into e from events where id=eid for update;
   if e.owner is distinct from u or e.status<>'open' then raise exception 'Only the organizer can edit an open event.';end if;
   perform seatlock_upkeep(eid,t);
   if cap<(select count(*) from bookings where event=eid and status in('held','confirmed')) then raise exception 'Capacity is below active reservations.';end if;
   update events set title=trim(x->>'title'),description=x->>'description',category=x->>'category',location=trim(x->>'location'),starts=st,capacity=cap where id=eid;
  end if;
 elsif a not in ('data','seed') then
  if a='lab' then raise exception 'Use the dedicated reliability test endpoint.';end if;
  select * into e from events where id=eid for update;
  if not found then raise exception 'Event not found.';end if;
  perform seatlock_upkeep(eid,t);
  if a in('attendees','checkin','close') then
   if e.owner<>u then raise exception 'Only the event organizer can do this.';end if;
   if a='attendees' then return coalesce((select jsonb_agg(to_jsonb(q) order by q.created,q.id) from bookings q where event=eid),'[]');
   elsif a='checkin' then
    update bookings set checked=case when (p->>'checked')::boolean then 1 else 0 end where event=eid and id=p->>'booking' and status='confirmed' and e.status='open';
    if not found then raise exception 'This ticket is not valid for check-in.';end if;return '{"ok":true}';
   else update events set status='cancelled' where id=eid;update bookings set status='cancelled',checked=0 where event=eid and status in('held','waiting','confirmed');end if;
  elsif a in('reserve','wait') then
   if e.status<>'open' or e.starts<=t then raise exception 'Registration is closed for this event.';end if;
   select * into b from bookings where event=eid and "user"=u;
   if b.id is null or b.status in('cancelled','expired') then
    select e.capacity-count(*) into cap from bookings where event=eid and status in('held','confirmed');
    insert into bookings(id,event,"user",name,email,status,expires,created) values(gen_random_uuid()::text,eid,u,nm,em,case when cap>0 then 'held' else 'waiting' end,case when cap>0 then t+300000 else 0 end,t)
    on conflict(event,"user") do update set status=excluded.status,expires=excluded.expires,created=excluded.created,checked=0,name=excluded.name,email=excluded.email;
   end if;
  elsif a='confirm' then
   update bookings set status='confirmed',expires=0 where event=eid and "user"=u and status='held' and expires>t and e.status='open' and e.starts>t;
   if not found and not exists(select 1 from bookings where event=eid and "user"=u and status='confirmed') then raise exception 'Your hold expired. Reserve again to continue.';end if;
  elsif a='cancel' then update bookings set status='cancelled',checked=0 where event=eid and "user"=u and status in('held','waiting','confirmed');perform seatlock_upkeep(eid,t);
  else raise exception 'Unknown action.';end if;
 end if;
 -- Stable lock order keeps concurrent refreshes from deadlocking.
 for eid2 in select id from events where kind='event' order by id loop perform seatlock_upkeep(eid2,t);end loop;
 select jsonb_build_object('user',jsonb_build_object('userId',u,'displayName',nm,'email',em),'serverTime',t,
 'events',coalesce((select jsonb_agg(to_jsonb(q) order by q.starts) from(select ev.*,(select count(*) from bookings bk where bk.event=ev.id and status='confirmed') confirmed,(select count(*) from bookings bk where bk.event=ev.id and status='held') held,(select count(*) from bookings bk where bk.event=ev.id and status='waiting') waiting from events ev where kind='event')q),'[]'),
 'bookings',coalesce((select jsonb_agg(to_jsonb(q) order by q.created desc) from(select bk.*,(select count(*) from bookings w where w.event=bk.event and w.status='waiting' and (w.created,w.id)<=(bk.created,bk.id)) position from bookings bk where "user"=u)q),'[]')) into outdata;
 return outdata;
end $$;
revoke all on function public.seatlock(jsonb) from public,anon;
grant execute on function public.seatlock(jsonb) to authenticated;
create function public.seatlock_lab(p jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare u uuid:=auth.uid();eid text:=p->>'id';e events%rowtype;n integer;i integer;t bigint:=floor(extract(epoch from clock_timestamp())*1000);
begin
 if u is null then raise exception 'Sign in to continue.';end if;
 if p->>'action'='start' then
  delete from events where owner=u and kind='lab' and created<t-600000;
  if exists(select 1 from events where owner=u and kind='lab') then raise exception 'A reliability test is already running. Retry after it finishes.';end if;
  eid:='lab-'||gen_random_uuid();insert into events values(eid,u,'Isolated stress test','','Workshop','',t+86400000,10,'open',0,'lab',t);return jsonb_build_object('id',eid);
 end if;
 select * into e from events where id=eid and kind='lab' and owner=u for update;
 if not found then raise exception 'Test not found.';end if;
 if p->>'action'='attempt' then
  i:=(p->>'index')::int;if i not between 0 and 79 then raise exception 'Invalid attempt';end if;
  select count(*) into n from bookings where event=eid;
  if n<10 then insert into bookings values(gen_random_uuid()::text,eid,md5(eid||':'||i)::uuid,'Synthetic '||i,'','held',t+300000,t,0) on conflict(event,"user") do nothing;return '{"accepted":true}';end if;
  return '{"accepted":false}';
 elsif p->>'action'='finish' then
  select count(*) into n from bookings where event=eid;delete from events where id=eid;
  return jsonb_build_object('accepted',n,'capacity',10,'oversold',greatest(0,n-10));
 else raise exception 'Unknown test action.';end if;
end $$;
revoke all on function public.seatlock_lab(jsonb) from public,anon;
grant execute on function public.seatlock_lab(jsonb) to authenticated;
