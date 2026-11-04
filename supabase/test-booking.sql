begin;
do $$
declare u uuid:=gen_random_uuid();v uuid:=gen_random_uuid();eid text;d jsonb;t bigint:=floor(extract(epoch from now())*1000);failed boolean;labid text;i integer;
begin
insert into auth.users(id,email,raw_user_meta_data) values(u,'seatlock-test-a@example.invalid','{"display_name":"A"}'),(v,'seatlock-test-b@example.invalid','{"display_name":"B"}');
perform set_config('request.jwt.claim.sub',u::text,true);
d:=public.seatlock(jsonb_build_object('action','create','event',jsonb_build_object('title','Test','description','','location','Test','category','Workshop','capacity',1,'starts',t+86400000)));
select id into eid from events where owner=u and title='Test';
perform public.seatlock(jsonb_build_object('action','reserve','id',eid));
perform public.seatlock(jsonb_build_object('action','reserve','id',eid));
if (select count(*) from bookings where event=eid)<>1 then raise exception 'Duplicate reservation';end if;
perform set_config('request.jwt.claim.sub',v::text,true);
perform public.seatlock(jsonb_build_object('action','reserve','id',eid));
if (select status from bookings where event=eid and "user"=v)<>'waiting' then raise exception 'Waitlist failed';end if;
failed:=false;begin perform public.seatlock(jsonb_build_object('action','attendees','id',eid));exception when others then failed:=true;end;if not failed then raise exception 'Authorization failed';end if;
perform set_config('request.jwt.claim.sub',u::text,true);
perform public.seatlock(jsonb_build_object('action','confirm','id',eid));
perform public.seatlock(jsonb_build_object('action','cancel','id',eid));
if (select status from bookings where event=eid and "user"=v)<>'held' then raise exception 'Promotion failed';end if;
update bookings set expires=t-1000 where event=eid and "user"=v;
perform public.seatlock('{}');
if (select status from bookings where event=eid and "user"=v)<>'expired' then raise exception 'Expiry failed';end if;
perform public.seatlock(jsonb_build_object('action','close','id',eid));
failed:=false;begin perform public.seatlock(jsonb_build_object('action','reserve','id',eid));exception when others then failed:=true;end;if not failed then raise exception 'Closed event accepted booking';end if;
-- Reliability test runs the same bounded capacity rule and cleans up.
d:=public.seatlock_lab('{"action":"start"}');labid:=d->>'id';
for i in 0..79 loop perform public.seatlock_lab(jsonb_build_object('action','attempt','id',labid,'index',i));end loop;
d:=public.seatlock_lab(jsonb_build_object('action','finish','id',labid));
if (d->>'accepted')::int<>10 or (d->>'oversold')::int<>0 then raise exception 'Lab capacity violated';end if;
-- JWT subject alone must not grant access after an account is deleted.
perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
failed:=false;begin perform public.seatlock('{}');exception when invalid_authorization_specification then failed:=true;end;
if not failed then raise exception 'Deleted account accepted';end if;
failed:=false;begin perform public.seatlock_lab('{"action":"start"}');exception when invalid_authorization_specification then failed:=true;end;
if not failed then raise exception 'Deleted account accepted by lab';end if;
end $$;
rollback;
select 'PASS: duplicate prevention, capacity, waitlist, promotion, expiry, ownership, closure' result;
