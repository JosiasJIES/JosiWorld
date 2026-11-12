import { useState } from 'react'
import type { FormEvent } from 'react'
import { useNavigate } from 'react-router-dom'
import { ArrowRight, PiggyBank, ShieldCheck, Sparkles } from 'lucide-react'
import { z } from 'zod'
import { supabase } from '../../lib/supabase/client'
import { useAuthStore } from '../../stores/auth'

const emailSchema = z.string().email('Escribe un correo válido.')
const passSchema = z.string().min(8, 'Usa al menos 8 caracteres.')
export function LoginPage({ initialMode = 'login' }: { initialMode?: 'login' | 'register' }) {
  const [mode, setMode] = useState<'login' | 'register'>(initialMode)
  const [childMode, setChildMode] = useState(false)
  const [email, setEmail] = useState(''); const [name, setName] = useState(''); const [family, setFamily] = useState(''); const [password, setPassword] = useState('')
  const [error, setError] = useState(''); const [message, setMessage] = useState(''); const [busy, setBusy] = useState(false)
  const navigate = useNavigate(); const refreshProfile = useAuthStore((s) => s.refreshProfile)

  async function submit(event: FormEvent) {
    event.preventDefault(); setError(''); setMessage('')
    const validPassword = passSchema.safeParse(password)
    if (!validPassword.success) { setError(validPassword.error.issues[0].message); return }
    setBusy(true)
    try {
      if (childMode) {
        const { data, error: invokeError } = await supabase.functions.invoke('child-login', { body: { username: email, password } })
        if (invokeError || !data?.access_token) throw new Error(data?.error ?? 'No se pudo iniciar sesión.')
        const { error: sessionError } = await supabase.auth.setSession({ access_token: data.access_token, refresh_token: data.refresh_token })
        if (sessionError) throw sessionError
      } else if (mode === 'register') {
        if (!emailSchema.safeParse(email).success) throw new Error('Escribe un correo válido.')
        if (name.trim().length < 2) throw new Error('Escribe tu nombre.')
        const { data, error: signupError } = await supabase.auth.signUp({ email, password, options: { data: { display_name: name.trim(), family_name: family.trim() || 'Mi familia' } } })
        if (signupError) throw signupError
        if (!data.session) { setMessage('Revisa tu correo para confirmar la cuenta. Después inicia sesión aquí.'); return }
      } else {
        if (!emailSchema.safeParse(email).success) throw new Error('Escribe un correo válido.')
        const { error: loginError } = await supabase.auth.signInWithPassword({ email, password })
        if (loginError) throw loginError
      }
      await refreshProfile()
      navigate(useAuthStore.getState().profile?.role === 'CHILD' ? '/child/home' : '/parent/dashboard')
    } catch (caught) { setError(caught instanceof Error ? caught.message : 'Ocurrió un error.') }
    finally { setBusy(false) }
  }

  return <main className="auth-shell">
    <section className="auth-visual"><div className="brand"><span className="brand-mark"><PiggyBank size={22} /></span> mi banquito</div>
      <div className="auth-visual-copy"><span className="eyebrow light"><Sparkles size={14} /> PEQUEÑOS ASTRONAUTAS, GRANDES SUEÑOS</span><h1>¡Tus sueños<br />van a despegar!</h1><p>Completa tus misiones, reúne monedas y alcanza tus metas. Tu gran aventura empieza con un pequeño paso.</p>
        <img className="space-rocket" src={new URL("../../assets/space-rocket.svg", import.meta.url).href} alt="Cohete viajando entre planetas y estrellas" /></div><div className="visual-footer"><ShieldCheck size={16} /> Una economía virtual, segura y familiar</div>
    </section>
    <section className="auth-form-wrap"><div className="auth-form">
      <div className="mobile-brand brand"><span className="brand-mark"><PiggyBank size={20} /></span> mi banquito</div>
      <div className="auth-heading"><span className="eyebrow">{mode === 'register' && !childMode ? 'EMPIEZA EN FAMILIA' : 'QUÉ BUENO VERTE'}</span><h2>{childMode ? '¡Hola, astronauta!' : mode === 'register' ? 'Crea tu espacio familiar' : 'Entra a tu banquito'}</h2><p>{childMode ? 'Entra con el usuario que te dio tu familia.' : mode === 'register' ? 'Un lugar seguro para aprender juntos.' : 'Tus metas y aventuras te esperan.'}</p></div>
      <div className="auth-tabs"><button className={!childMode ? 'selected' : ''} onClick={() => { setChildMode(false); setMode('login') }}>Mamá o papá</button><button className={childMode ? 'selected' : ''} onClick={() => setChildMode(true)}>Soy niño o niña</button></div>
      <form onSubmit={submit} className="form-stack">
        {!childMode && mode === 'register' && <><label>Tu nombre<input value={name} onChange={(e) => setName(e.target.value)} placeholder="¿Cómo te llamas?" autoComplete="name" /></label><label>Nombre de familia<input value={family} onChange={(e) => setFamily(e.target.value)} placeholder="Familia García" /></label></>}
        <label>{childMode ? 'Tu usuario' : 'Correo electrónico'}<input value={email} onChange={(e) => setEmail(e.target.value)} placeholder={childMode ? 'miusuario' : 'tu@correo.com'} autoComplete={childMode ? 'username' : 'email'} /></label>
        <label>Contraseña<input type="password" value={password} onChange={(e) => setPassword(e.target.value)} placeholder="Mínimo 8 caracteres" autoComplete={mode === 'register' ? 'new-password' : 'current-password'} /></label>
        {error && <div className="notice error">{error}</div>}{message && <div className="notice success">{message}</div>}
        <button className="button primary full" disabled={busy}>{busy ? 'Un momento…' : childMode ? 'Entrar a mi espacio' : mode === 'register' ? 'Crear mi cuenta' : 'Iniciar sesión'}<ArrowRight size={17} /></button>
      </form>
      {!childMode && <div className="auth-switch">{mode === 'login' ? <>¿Primera vez por aquí? <button onClick={() => setMode('register')}>Crea una cuenta</button></> : <>¿Ya tienes cuenta? <button onClick={() => setMode('login')}>Inicia sesión</button></>}</div>}
      {mode === 'login' && !childMode && <button className="text-link" onClick={async () => { if (!emailSchema.safeParse(email).success) { setError('Escribe primero tu correo.'); return }; const { error: resetError } = await supabase.auth.resetPasswordForEmail(email); setError(resetError?.message ?? 'Si el correo está registrado, recibirás un enlace para restablecer tu contraseña.') }}>Olvidé mi contraseña</button>}
    </div></section>
  </main>
}

