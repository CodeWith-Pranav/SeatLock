import {createClient} from '@supabase/supabase-js';
export const supabase=createClient('https://zwzeuapkvcndessfniqm.supabase.co','sb_publishable_4FCWjIBvh-ZMiWfLuFA1Ww_RsC4aQzi');
export async function authHeaders(){const {data:{session}}=await supabase.auth.getSession();return session?{Authorization:`Bearer ${session.access_token}`}:{Authorization:''};}
