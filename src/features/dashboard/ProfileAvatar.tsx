import { useQuery } from '@tanstack/react-query'
import { UserRound } from 'lucide-react'
import { supabase } from '../../lib/supabase/client'
import { profilePhotoPath } from './profileAvatarUtils'

export function ProfileAvatar({avatar,className='',name='Perfil',genericFallback=false}:{avatar:string|null|undefined;className?:string;name?:string;genericFallback?:boolean}){
  const path=profilePhotoPath(avatar)
  const photoQuery=useQuery({queryKey:['profile-avatar-url',path],enabled:!!path,staleTime:45*60*1000,queryFn:async()=>{if(!path)throw new Error('No hay foto de perfil');const {data,error}=await supabase.storage.from('avatars').createSignedUrl(path,3600);if(error)throw error;return data.signedUrl}})
  return <span className={`avatar ${className} ${photoQuery.data?'has-profile-photo':''}`} aria-label={name}>
    {photoQuery.data?<img src={photoQuery.data} alt={name}/>:path||genericFallback||!avatar?<UserRound size={23}/>:avatar}
  </span>
}
