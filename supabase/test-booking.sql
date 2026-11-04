begin;
do $$
declare u uuid:=gen_random_uuid();v uuid:=gen_random_uuid();eid text;d jsonb;t bigint:=floor(extract(epoch from now())*1000);failed boolean;
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
end $$;
rollback;
select 'PASS: duplicate prevention, capacity, waitlist, promotion, expiry, ownership, closure' result;
