import { create } from 'zustand'
import type { User } from '@supabase/supabase-js'
import { supabase } from '../lib/supabase/client'

export type Profile = { id: string; family_id: string; role: 'PARENT' | 'CHILD'; display_name: string; username: string | null; avatar: string; xp: number; is_active: boolean }
type AuthState = { user: User | null; profile: Profile | null; loading: boolean; setUser: (user: User | null) => void; refreshProfile: () => Promise<void>; signOut: () => Promise<void> }

export const useAuthStore = create<AuthState>((set, get) => ({
  user: null, profile: null, loading: true,
  setUser: (user) => set({ user, loading: !!user, ...(user ? {} : { profile: null, loading: false }) }),
  refreshProfile: async () => {
    const user = get().user ?? (await supabase.auth.getUser()).data.user
    if (!user) { set({ user: null, profile: null, loading: false }); return }
    set({ user, loading: true })
    const { data, error } = await supabase.from('profiles').select('id,family_id,role,display_name,username,avatar,xp,is_active').eq('id', user.id).single()
    if (error) { set({ user, profile: null, loading: false }); return }
    set({ user, profile: data as Profile, loading: false })
  },
  signOut: async () => { await supabase.auth.signOut(); set({ user: null, profile: null, loading: false }) },
}))

export function onAuthStateChange(callback: () => void) {
  const { data } = supabase.auth.onAuthStateChange((_event, session) => {
    useAuthStore.getState().setUser(session?.user ?? null)
    window.setTimeout(callback, 0)
  })
  return () => data.subscription.unsubscribe()
}
