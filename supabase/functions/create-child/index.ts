import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    if (req.method !== 'POST') return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders })
    const authorization = req.headers.get('Authorization')
    if (!authorization) return Response.json({ error: 'Sign in required' }, { status: 401, headers: corsHeaders })

    const url = Deno.env.get('SUPABASE_URL')!
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const caller = createClient(url, anonKey, { global: { headers: { Authorization: authorization } } })
    const { data: { user }, error: authError } = await caller.auth.getUser()
    if (authError || !user) return Response.json({ error: 'Invalid session' }, { status: 401, headers: corsHeaders })

    const admin = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } })
    const { data: parent, error: profileError } = await admin.from('profiles').select('family_id, role').eq('id', user.id).single()
    if (profileError || parent?.role !== 'PARENT') return Response.json({ error: 'Only a parent can create child accounts' }, { status: 403, headers: corsHeaders })

    const body = await req.json()
    const displayName = String(body.displayName ?? '').trim().slice(0, 80)
    const username = String(body.username ?? '').trim().toLowerCase()
    const password = String(body.password ?? '')
    const avatar = String(body.avatar ?? '🦊').slice(0, 16)
    const birthDate = body.birthDate ? String(body.birthDate) : null
    if (displayName.length < 2 || !/^[a-z0-9_]{3,24}$/.test(username) || password.length < 8) {
      return Response.json({ error: 'Usa un nombre, usuario (3–24 letras o números) y contraseña de al menos 8 caracteres.' }, { status: 400, headers: corsHeaders })
    }

    const { data: invite, error: inviteError } = await admin.from('child_invites').insert({
      family_id: parent.family_id, username, display_name: displayName, avatar, birth_date: birthDate,
    }).select('token').single()
    if (inviteError) return Response.json({ error: inviteError.code === '23505' ? 'Ese nombre de usuario ya está ocupado.' : inviteError.message }, { status: 400, headers: corsHeaders })

    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email: `${username}@kids.mibanquito.invalid`,
      password,
      email_confirm: true,
      user_metadata: { child_invite_token: invite.token },
    })
    if (createError) {
      await admin.from('child_invites').delete().eq('token', invite.token)
      return Response.json({ error: createError.message }, { status: 400, headers: corsHeaders })
    }
    return Response.json({ id: created.user.id, displayName, username, avatar }, { status: 201, headers: corsHeaders })
  } catch (error) {
    return Response.json({ error: error instanceof Error ? error.message : 'Unexpected error' }, { status: 500, headers: corsHeaders })
  }
})
