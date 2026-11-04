"""Integration checks execute the application's actual SQL against SQLite."""
import sqlite3,json,unittest,tempfile,os,concurrent.futures
Q=json.load(open('lib/queries.json'))
SQL=open('drizzle/0000_salty_swarm.sql').read().replace('--> statement-breakpoint','')
class Reservations(unittest.TestCase):
 def setUp(self):
  self.file=tempfile.mktemp();self.c=sqlite3.connect(self.file);self.c.executescript(SQL);self.c.execute("INSERT INTO events VALUES('e','owner','Test','','Workshop','Room',1000000,3,'open',0,'event',0)");self.c.commit()
 def tearDown(self):self.c.close();os.remove(self.file)
 def reserve(self,user,t=100):
  with sqlite3.connect(self.file,timeout=20) as c:
   c.execute(Q['reserve'],(user,'u'+user,'Name','e@x',t+300,t,'e',t,t));return c.total_changes
 def wait(self,user,t=100):
  self.c.execute(Q['wait'],(user,'u'+user,'Name','e@x',t,'e',t,t));self.c.commit()
 def upkeep(self,t):
  self.c.execute(Q['expire'],('e',t));self.c.execute(Q['promote'],(t+300,'e','e',t,'e','e',t));self.c.commit()
 def test_concurrent_capacity(self):
  with concurrent.futures.ThreadPoolExecutor(max_workers=24) as pool:r=list(pool.map(self.reserve,map(str,range(80))))
  self.assertEqual(sum(r),3)
 def test_duplicate_does_not_extend(self):
  self.reserve('a');self.reserve('a',150)
  self.assertEqual(self.c.execute('SELECT COUNT(*),expires FROM bookings').fetchone(),(1,400))
 def test_expiry_and_fifo(self):
  for u in ['a','b','c']:self.reserve(u)
  self.wait('w1',110);self.wait('w2',120);self.wait('w3',130);self.wait('w4',140)
  self.upkeep(401)
  self.assertEqual(self.c.execute("SELECT id FROM bookings WHERE status='held' ORDER BY id").fetchall(),[('w1',),('w2',),('w3',)])
  self.assertEqual(self.c.execute("SELECT status FROM bookings WHERE id='w4'").fetchone()[0],'waiting')
 def test_no_queue_jumping(self):
  for u in ['a','b','c']:self.reserve(u)
  self.wait('w',110);self.c.execute("UPDATE bookings SET status='cancelled' WHERE id='a'");self.c.commit()
  self.assertEqual(self.reserve('new'),0)
  self.upkeep(120);self.assertEqual(self.c.execute("SELECT status FROM bookings WHERE id='w'").fetchone()[0],'held')
 def test_expired_confirmation_rejected(self):
  self.reserve('a');self.c.execute(Q['confirm'],('e','ua',401,'e',401));self.assertEqual(self.c.execute("SELECT status FROM bookings").fetchone()[0],'held')
 def test_confirm_idempotent(self):
  self.reserve('a')
  for _ in range(2):self.c.execute(Q['confirm'],('e','ua',120,'e',120))
  self.assertEqual(self.c.execute('SELECT COUNT(*),status FROM bookings').fetchone(),(1,'confirmed'))
 def test_cancelled_event_rejects(self):
  self.c.execute("UPDATE events SET status='cancelled'");self.c.commit();self.assertEqual(self.reserve('a'),0)
 def test_rebook_cancelled(self):
  self.reserve('a');self.c.execute("UPDATE bookings SET status='cancelled'");self.c.commit();self.reserve('a',200)
  self.assertEqual(self.c.execute('SELECT COUNT(*),status,expires FROM bookings').fetchone(),(1,'held',500))
 def test_started_event_rejects(self):self.assertEqual(self.reserve('a',1000001),0)
 def test_confirmed_seat_survives_expiry(self):
  self.reserve('a');self.c.execute(Q['confirm'],('e','ua',120,'e',120));self.c.commit();self.upkeep(500)
  self.assertEqual(self.c.execute('SELECT status FROM bookings').fetchone()[0],'confirmed')
if __name__=='__main__':unittest.main(verbosity=2)
