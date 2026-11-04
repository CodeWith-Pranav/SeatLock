"""Run only against local preview. Creates and closes a synthetic event."""
import urllib.request,urllib.error,json,sys,time,uuid,concurrent.futures
base=sys.argv[1].rstrip('/')+'/api/seatlock';owner='test-'+str(uuid.uuid4())
def call(action=None,user=owner,**kw):
 headers={'oai-authenticated-user-id':user,'oai-authenticated-user-email':user+'@example.test','Content-Type':'application/json'}
 data=json.dumps(dict(action=action,**kw)).encode() if action else None
 try:
  with urllib.request.urlopen(urllib.request.Request(base,data=data,headers=headers),timeout=120) as r:return r.status,json.load(r)
 except urllib.error.HTTPError as e:return e.code,json.load(e)
code,d=call('create',event=dict(title='API test fixture',description='Local automated verification',category='Workshop',location='Test',starts=int(time.time()*1000)+86400000,capacity=1));assert code==200,(code,d)
id=next(e['id'] for e in d['events'] if e['owner']==owner)
try:
 code,d=call('reserve',user=owner+'a',id=id);assert code==200;assert next(b for b in d['bookings'] if b['event']==id)['status']=='held'
 code,d=call('reserve',user=owner+'b',id=id);assert code==200;assert next(b for b in d['bookings'] if b['event']==id)['status']=='waiting'
 assert call('attendees',user=owner+'b',id=id)[0]==403
 assert call('close',user=owner+'b',id=id)[0]==403
 assert call('edit',user=owner+'b',id=id,event=dict(title='No',description='',category='Workshop',location='Test',starts=int(time.time()*1000)+86400000,capacity=1))[0]==409
 assert call('confirm',user=owner+'a',id=id)[0]==200
 assert call('confirm',user=owner+'a',id=id)[0]==200
 code,d=call('attendees',id=id);bid=next(b['id'] for b in d if b['user']==owner+'a')
 assert call('checkin',user=owner+'b',id=id,booking=bid,checked=True)[0]==403
 assert call('checkin',id=id,booking=bid,checked=True)[0]==200
 assert call('cancel',user=owner+'a',id=id)[0]==200
 code,d=call(user=owner+'b');assert next(b for b in d['bookings'] if b['event']==id)['status']=='held'
 assert call('confirm',user=owner+'b',id=id)[0]==200
 code,d=call('lab');assert code==200 and d['accepted']==10 and d['oversold']==0 and d['errors']==0,(code,d)
 print('PASS: real D1 API hold, waitlist, confirmation retry, cancellation promotion, ownership, check-in; lab:',d)
finally:call('close',id=id)
