import { useRef, useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { NavLink, useLocation, useNavigate } from 'react-router-dom'
import { BarChart3, BookOpen, Camera, Coins, Gift, Home, LogOut, Menu, PiggyBank, Settings, ShieldCheck, Sparkles, Users, Wallet, X } from 'lucide-react'
import { useAuthStore } from '../../stores/auth'
import { supabase } from '../../lib/supabase/client'
import { WorkspacePage } from '../../features/dashboard/WorkspacePage'
import { ProfileAvatar } from '../../features/dashboard/ProfileAvatar'
import { profilePhotoPath } from '../../features/dashboard/profileAvatarUtils'

const parentLinks = [
  { path: '/parent/dashboard', label: 'Resumen', icon: Home }, { path: '/parent/children', label: 'Mis hijos', icon: Users },
  { path: '/parent/tasks', label: 'Rutinas y extras', icon: BookOpen }, { path: '/parent/diary', label: 'Diario', icon: BookOpen }, { path: '/parent/rewards', label: 'Recompensas', icon: Gift },
  { path: '/parent/approvals', label: 'Aprobaciones', icon: ShieldCheck }, { path: '/parent/finances', label: 'Finanzas', icon: BarChart3 }, { path: '/parent/settings', label: 'Configuraciones', icon: Settings },
]
const childLinks = [
  { path: '/child/home', label: 'Mi banquito', icon: Home }, { path: '/child/tasks', label: 'Mis tareas', icon: BookOpen }, { path: '/child/diary', label: 'Mi diario', icon: BookOpen },
  { path: '/child/store', label: 'La tiendita', icon: Gift }, { path: '/child/savings', label: 'Mis metas', icon: PiggyBank },
  { path: '/child/movements', label: 'Movimientos', icon: Wallet }, { path: '/child/achievements', label: 'Mis logros', icon: Sparkles }, { path: '/child/settings', label: 'Configuraciones', icon: Settings },
]
const displayDate = new Intl.DateTimeFormat('es-MX',{weekday:'long',day:'numeric',month:'long'}).format(new Date())
const titles: Record<string, string> = { dashboard:'Resumen', children:'Mis hijos', tasks:'Rutinas y extras', diary:'Diario', rewards:'Recompensas', approvals:'Aprobaciones', finances:'Finanzas', settings:'Configuraciones', home:'Mi banquito', store:'La tiendita', savings:'Mis metas', movements:'Movimientos', achievements:'Mis logros' }
const formatMoney = (amount:number) => new Intl.NumberFormat('es-MX').format(amount)
async function optimizeAvatarImage(file:File){
  if(!['image/jpeg','image/png','image/webp'].includes(file.type))throw new Error('Elige una imagen JPG, PNG o WebP.')
  if(file.size>15*1024*1024)throw new Error('La imagen original debe pesar menos de 15 MB.')
  const bitmap=await createImageBitmap(file)
  const scale=Math.min(1,512/Math.max(bitmap.width,bitmap.height))
  const canvas=document.createElement('canvas')
  canvas.width=Math.max(1,Math.round(bitmap.width*scale));canvas.height=Math.max(1,Math.round(bitmap.height*scale))
  const context=canvas.getContext('2d')
  if(!context){bitmap.close();throw new Error('No se pudo preparar la imagen.')}
  context.fillStyle='#ffffff';context.fillRect(0,0,canvas.width,canvas.height);context.drawImage(bitmap,0,0,canvas.width,canvas.height);bitmap.close()
  for(const quality of [0.86,0.72,0.58,0.45]){
    const blob=await new Promise<Blob>((resolve,reject)=>canvas.toBlob(value=>value?resolve(value):reject(new Error('No se pudo comprimir la imagen.')),'image/jpeg',quality))
    if(blob.size<=480*1024)return blob
  }
  throw new Error('La imagen no se pudo reducir lo suficiente. Prueba con otra foto.')
}
type ChildBalance = { child_id:string; available_balance:number; savings_balance:number }
type FamilyCurrency = { currency_name:string; currency_symbol:string }
type LevelSettings = { level_xp_step:number }

export function DashboardLayout({ role }: { role: 'PARENT' | 'CHILD' }) {
  const profile = useAuthStore((s) => s.profile)
  const signOut = useAuthStore((s) => s.signOut)
  const refreshProfile = useAuthStore((s)=>s.refreshProfile)
  const queryClient=useQueryClient()
  const [mobileOpen, setMobileOpen] = useState(false)
  const [photoBusy,setPhotoBusy]=useState(false)
  const [photoMessage,setPhotoMessage]=useState('')
  const photoInput=useRef<HTMLInputElement>(null)
  const balanceQuery = useQuery({queryKey:['balances',profile?.family_id],enabled:role==='CHILD'&&!!profile,queryFn:async()=>{const {data,error}=await supabase.from('child_balances').select('*').eq('family_id',profile!.family_id);if(error)throw error;return data as ChildBalance[]}})
  const currencyQuery = useQuery({queryKey:['family',profile?.family_id],enabled:role==='CHILD'&&!!profile,queryFn:async()=>{const {data,error}=await supabase.from('families').select('*').eq('id',profile!.family_id).single();if(error)throw error;return data as FamilyCurrency}})
  const levelQuery = useQuery({queryKey:['settings',profile?.family_id],enabled:role==='CHILD'&&!!profile,queryFn:async()=>{const {data,error}=await supabase.from('app_settings').select('level_xp_step').eq('family_id',profile!.family_id).single();if(error)throw error;return data as LevelSettings}})
  const progressQuery = useQuery({queryKey:['nav-child-xp',profile?.id],enabled:role==='CHILD'&&!!profile,refetchInterval:10000,queryFn:async()=>{const {data,error}=await supabase.from('profiles').select('xp').eq('id',profile!.id).single();if(error)throw error;return data.xp as number}})
  const location = useLocation(); const navigate = useNavigate()
  const section = location.pathname.split('/')[2] ?? (role === 'PARENT' ? 'dashboard' : 'home')
  const links = role === 'PARENT' ? parentLinks : childLinks
  const ownBalance = balanceQuery.data?.find((balance)=>balance.child_id===profile?.id) ?? {available_balance:0,savings_balance:0}
  const xp = progressQuery.data ?? profile?.xp ?? 0
  const levelStep = Number(levelQuery.data?.level_xp_step ?? 100)
  const level = Math.floor(xp/levelStep)+1
  async function uploadProfilePhoto(file:File){
    if(!profile)return
    setPhotoBusy(true);setPhotoMessage('')
    const previousPath=profilePhotoPath(profile.avatar)
    let newPath=''
    try{
      const optimized=await optimizeAvatarImage(file)
      newPath=`${profile.family_id}/${profile.id}/avatar.jpg`
      const {error:uploadError}=await supabase.storage.from('avatars').upload(newPath,optimized,{upsert:true,contentType:'image/jpeg',cacheControl:'0'})
      if(uploadError)throw uploadError
      const {error:profileError}=await supabase.rpc('update_my_avatar' as never,{avatar_path:newPath} as never)
      if(profileError){if(newPath!==previousPath)await supabase.storage.from('avatars').remove([newPath]);throw profileError}
      await refreshProfile()
      if(previousPath&&previousPath!==newPath)await supabase.storage.from('avatars').remove([previousPath])
      if(previousPath)queryClient.removeQueries({queryKey:['profile-avatar-url',previousPath]})
      setPhotoMessage('Foto de perfil actualizada.')
    }catch(error){setPhotoMessage(error instanceof Error?error.message:'No se pudo subir la foto.')}
    finally{setPhotoBusy(false);if(photoInput.current)photoInput.current.value=''}
  }
  return <div className={`app-shell ${role === 'CHILD' ? 'child-mode' : ''}`}>
    <aside className={`sidebar ${mobileOpen ? 'open' : ''}`}>
      <div className="sidebar-brand"><span className="brand-mark"><PiggyBank size={21} /></span><span>mi banquito<small>finanzas en familia</small></span><button className="icon-button close-menu" onClick={() => setMobileOpen(false)} aria-label="Cerrar menú"><X /></button></div>
      <div className="profile-card"><div className="profile-photo-picker"><ProfileAvatar avatar={profile?.avatar} name={profile?.display_name??'Perfil'} className="sidebar-avatar" genericFallback/></div><div className="profile-card-copy"><strong>{profile?.display_name ?? 'Mi espacio'}</strong></div></div>
      <span className="nav-caption">{role === 'PARENT' ? 'TU FAMILIA' : 'TU AVENTURA'}</span>
      <nav>{links.map(({ path, label, icon: Icon }) => <NavLink key={path} to={path} onClick={() => setMobileOpen(false)} className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}><Icon size={18} strokeWidth={1.8} /><span>{label}</span></NavLink>)}</nav>
      <div className="sidebar-bottom"><button className="nav-link logout" onClick={async () => { await signOut(); navigate('/login') }}><LogOut size={18} /><span>Cerrar sesión</span></button></div>
    </aside>
    {mobileOpen && <button className="sidebar-scrim" onClick={() => setMobileOpen(false)} aria-label="Cerrar menú" />}
    <main className="main-column"><header className={`topbar ${role==='CHILD'?'child-topbar':''}`}>
      <div className="topbar-main"><button className="icon-button mobile-menu" onClick={() => setMobileOpen(true)} aria-label="Abrir menú"><Menu /></button><div><span className="breadcrumb">Mi espacio <span>›</span></span><h1>{titles[section] ?? 'Mi espacio'}</h1></div></div>
      {role==='CHILD'&&<div className="child-nav-stats" aria-label="Resumen de tu cuenta">
        <div className="nav-stat" title={`${currencyQuery.data?.currency_name ?? 'JEX'} total · Disponible y ahorrado`}><i><Coins size={17}/></i><span><small>{currencyQuery.data?.currency_name ?? 'JEX'} total</small><strong>{formatMoney(Number(ownBalance.available_balance)+Number(ownBalance.savings_balance))}</strong></span></div>
        <div className="nav-stat" title="Disponible para tus decisiones"><i><Coins size={17}/></i><span><small>Disponible</small><strong>{formatMoney(Number(ownBalance.available_balance))}</strong></span></div>
        <div className="nav-stat gold" title="Ahorrado en tus metas"><i><PiggyBank size={17}/></i><span><small>En tus metas</small><strong>{formatMoney(Number(ownBalance.savings_balance))}</strong></span></div>
        <div className="nav-stat lilac" title={`${xp%levelStep} de ${levelStep} XP para el siguiente nivel`}><i><Sparkles size={17}/></i><span><small>Nivel · {xp%levelStep}/{levelStep} XP</small><strong>{level}</strong></span></div>
      </div>}
      <div className="topbar-actions"><span className="date-chip">{displayDate}</span><ProfileAvatar avatar={profile?.avatar} name={profile?.display_name??'Perfil'} className="small topbar-avatar" genericFallback/></div>
    </header>{section === 'settings' && <div className="content-wrap profile-settings"><section className="panel"><div className="panel-heading"><div><h3>Mi foto de perfil</h3><p>Elige la foto que aparecerá en tu espacio.</p></div></div><div className="profile-settings-controls"><ProfileAvatar avatar={profile?.avatar} name={profile?.display_name??'Perfil'} className="child-avatar" genericFallback/><input ref={photoInput} className="sr-only" aria-label="Elegir foto de perfil" type="file" accept="image/jpeg,image/png,image/webp" disabled={photoBusy} onChange={event=>{const file=event.target.files?.[0];if(file)void uploadProfilePhoto(file)}}/><button type="button" className="button primary" onClick={()=>photoInput.current?.click()} disabled={photoBusy}><Camera size={18}/>{photoBusy?'Subiendo…':'Cambiar foto'}</button></div>{photoMessage&&<p role="status" className="notice">{photoMessage}</p>}</section></div>}{!(role === 'CHILD' && section === 'settings') && <WorkspacePage role={role} section={section} />}</main>
  </div>
}


