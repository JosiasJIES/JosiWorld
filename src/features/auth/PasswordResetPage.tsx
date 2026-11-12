import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { ArrowRight, LockKeyhole, PiggyBank, ShieldCheck, Sparkles } from 'lucide-react'
import { z } from 'zod'
import { supabase } from '../../lib/supabase/client'

const passwordSchema = z.string().min(8, 'Usa al menos 8 caracteres.')

export function PasswordResetPage() {
  const [checking, setChecking] = useState(true)
  const [hasSession, setHasSession] = useState(false)
  const [password, setPassword] = useState('')
  const [confirmation, setConfirmation] = useState('')
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')
  const [busy, setBusy] = useState(false)
  const navigate = useNavigate()

  useEffect(() => {
    let active = true
    void supabase.auth.getSession().then(({ data, error: sessionError }) => {
      if (!active) return
      setHasSession(Boolean(data.session))
      if (sessionError) setError(sessionError.message)
      setChecking(false)
    })
    return () => { active = false }
  }, [])

  async function submit(event: FormEvent) {
    event.preventDefault(); setError(''); setMessage('')
    const parsed = passwordSchema.safeParse(password)
    if (!parsed.success) { setError(parsed.error.issues[0].message); return }
    if (password !== confirmation) { setError('Las contraseñas no coinciden.'); return }
    setBusy(true)
    try {
      const { error: updateError } = await supabase.auth.updateUser({ password })
      if (updateError) throw updateError
      await supabase.auth.signOut()
      setMessage('Tu contraseña quedó actualizada. Ya puedes iniciar sesión.')
      window.setTimeout(() => navigate('/login', { replace: true }), 900)
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'No se pudo actualizar la contraseña.')
    } finally {
      setBusy(false)
    }
  }

  return <main className="auth-shell">
    <section className="auth-visual">
      <div className="brand"><span className="brand-mark"><PiggyBank size={22} /></span> mi banquito</div>
      <div className="auth-visual-copy"><span className="eyebrow light"><Sparkles size={14} /> RECUPERA TU ACCESO</span><h1>Tu espacio<br />te espera.</h1><p>Elige una contraseña nueva y continúa con tus metas y aventuras familiares.</p></div>
      <div className="visual-footer"><ShieldCheck size={16} /> Una economía virtual, segura y familiar</div>
    </section>
    <section className="auth-form-wrap"><div className="auth-form">
      <div className="mobile-brand brand"><span className="brand-mark"><PiggyBank size={20} /></span> mi banquito</div>
      <div className="auth-heading"><span className="eyebrow"><LockKeyhole size={14} /> NUEVA CONTRASEÑA</span><h2>Recupera tu cuenta</h2><p>Escribe y confirma tu nueva contraseña.</p></div>
      {checking ? <div className="notice">Validando el enlace…</div> : !hasSession ? <>
        <div className="notice error">Este enlace ya venció o no es válido. Solicita uno nuevo desde la pantalla de inicio.</div>
        <Link className="button primary full" to="/login">Volver a iniciar sesión <ArrowRight size={17} /></Link>
      </> : <form onSubmit={submit} className="form-stack">
        <label>Nueva contraseña<input type="password" value={password} onChange={(event) => setPassword(event.target.value)} placeholder="Mínimo 8 caracteres" autoComplete="new-password" /></label>
        <label>Confirma la contraseña<input type="password" value={confirmation} onChange={(event) => setConfirmation(event.target.value)} placeholder="Escríbela de nuevo" autoComplete="new-password" /></label>
        {error && <div className="notice error">{error}</div>}{message && <div className="notice success">{message}</div>}
        <button className="button primary full" disabled={busy}>{busy ? 'Guardando…' : 'Guardar contraseña'}<ArrowRight size={17} /></button>
      </form>}
    </div></section>
  </main>
}
