import { lazy, Suspense, useEffect, useState } from 'react'
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { onAuthStateChange, useAuthStore } from './stores/auth'
const LoginPage = lazy(async()=>({default:(await import('./features/auth/LoginPage')).LoginPage}))
const DashboardLayout = lazy(()=>import('./app/layouts/DashboardLayout').then((m)=>({default:m.DashboardLayout})))

function Protected({ role }: { role: 'PARENT' | 'CHILD' }) {
  const { profile, loading } = useAuthStore()
  if (loading) return <div className="loading-screen"><span className="spinner" /> Preparando tu banquito…</div>
  if (!profile) return <Navigate to="/login" replace />
  if (profile.role !== role) return <Navigate to={profile.role === 'PARENT' ? '/parent/dashboard' : '/child/home'} replace />
  return <DashboardLayout role={role} />
}

export default function App() {
  const { user, refreshProfile } = useAuthStore()
  const [ready, setReady] = useState(false)
  useEffect(() => onAuthStateChange(() => { void refreshProfile().finally(() => setReady(true)) }), [refreshProfile])
  useEffect(() => { void refreshProfile().finally(() => setReady(true)) }, [refreshProfile])
  if (!ready && user) return <div className="loading-screen"><span className="spinner" /> Preparando tu banquito…</div>
  const home = user ? (useAuthStore.getState().profile?.role === 'CHILD' ? '/child/home' : '/parent/dashboard') : '/login'
  return <BrowserRouter><Suspense fallback={<div className="loading-screen"><span className="spinner"/> Abriendo tu espacio…</div>}><Routes>
    <Route path="/" element={<Navigate to={home} replace />} />
    <Route path="/login" element={user ? <Navigate to={home} replace /> : <LoginPage />} />
    <Route path="/register" element={user ? <Navigate to="/parent/dashboard" replace /> : <LoginPage initialMode="register" />} />
    <Route path="/parent/*" element={<Protected role="PARENT" />} />
    <Route path="/child/*" element={<Protected role="CHILD" />} />
    <Route path="*" element={<Navigate to="/" replace />} />
  </Routes></Suspense></BrowserRouter>
}
