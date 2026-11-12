import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders })
  try {
    const { username, password } = await req.json()
    const normalizedUsername = String(username ?? '').trim().toLowerCase()
    if (!/^[a-z0-9_]{3,24}$/.test(normalizedUsername) || typeof password !== 'string') {
      return Response.json({ error: 'Usuario o contraseña incorrectos.' }, { status: 400, headers: corsHeaders })
    }
    const url = Deno.env.get('SUPABASE_URL')!
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { autoRefreshToken: false, persistSession: false } })
    const { data: child } = await admin.from('profiles').select('id,is_active').eq('username', normalizedUsername).eq('role', 'CHILD').maybeSingle()
    if (!child?.is_active) return Response.json({ error: 'Usuario o contraseña incorrectos.' }, { status: 401, headers: corsHeaders })
    const publicClient = createClient(url, anonKey, { auth: { autoRefreshToken: false, persistSession: false } })
    const { data, error } = await publicClient.auth.signInWithPassword({ email: `${normalizedUsername}@kids.mibanquito.invalid`, password })
    if (error || !data.session) return Response.json({ error: 'Usuario o contraseña incorrectos.' }, { status: 401, headers: corsHeaders })
    return Response.json({ access_token: data.session.access_token, refresh_token: data.session.refresh_token, expires_in: data.session.expires_in, token_type: 'bearer' }, { headers: corsHeaders })
  } catch (error) {
    return Response.json({ error: error instanceof Error ? error.message : 'Unexpected error' }, { status: 500, headers: corsHeaders })
  }
})
