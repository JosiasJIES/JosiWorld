export const profilePhotoPath = (avatar:string|null|undefined) => avatar?.startsWith('photo:') ? avatar.slice('photo:'.length) : null
