import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

const corsHeaders = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' }
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders })
  try {
    const authorization = req.headers.get('Authorization')
    if (!authorization) return Response.json({ error: 'Sign in required' }, { status: 401, headers: corsHeaders })
    const url = Deno.env.get('SUPABASE_URL')!
    const caller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: authorization } } })
    const { data: { user } } = await caller.auth.getUser()
    if (!user) return Response.json({ error: 'Invalid session' }, { status: 401, headers: corsHeaders })
    const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { autoRefreshToken: false, persistSession: false } })
    const { data: parent } = await admin.from('profiles').select('family_id,role').eq('id', user.id).single()
    const body = await req.json(); const childId = String(body.childId ?? ''); const password = String(body.password ?? '')
    if (parent?.role !== 'PARENT') return Response.json({ error: 'Solo un padre puede restablecer el acceso.' }, { status: 403, headers: corsHeaders })
    if (password.length < 8) return Response.json({ error: 'La contraseña debe tener al menos 8 caracteres.' }, { status: 400, headers: corsHeaders })
    const { data: child } = await admin.from('profiles').select('id').eq('id', childId).eq('family_id', parent.family_id).eq('role', 'CHILD').single()
    if (!child) return Response.json({ error: 'No encontramos ese perfil de tu familia.' }, { status: 404, headers: corsHeaders })
    const { error } = await admin.auth.admin.updateUserById(child.id, { password })
    if (error) return Response.json({ error: error.message }, { status: 400, headers: corsHeaders })
    return Response.json({ success: true }, { headers: corsHeaders })
  } catch (error) { return Response.json({ error: error instanceof Error ? error.message : 'Unexpected error' }, { status: 500, headers: corsHeaders }) }
})
