let profileOnboardingPreviewUrl='';

function normalizeOnboardingUsername(value=''){return value.trim().toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/\s+/g,'')}

function showProfileOnboarding(profile){
  const backdrop=document.querySelector('#profileOnboardingBackdrop');
  if(profile.username&&profile.avatar_url){backdrop.hidden=true;return}
  document.querySelector('#profileOnboardingUsername').value=profile.username||'';
  const preview=document.querySelector('#profileOnboardingPreview');
  if(profile.avatar_url){preview.style.backgroundImage=`url('${mediaUrl(profile.avatar_url)}')`;preview.textContent=''}
  backdrop.hidden=false;
  document.body.style.overflow='hidden';
  setTimeout(()=>document.querySelector(profile.username?'#profileOnboardingFile':'#profileOnboardingUsername').focus(),50);
}

document.querySelector('#profileOnboardingUsername').addEventListener('input',event=>{
  event.target.value=normalizeOnboardingUsername(event.target.value);
  document.querySelector('#profileOnboardingError').textContent='';
});

document.querySelector('#profileOnboardingFile').addEventListener('change',event=>{
  const file=event.target.files?.[0],preview=document.querySelector('#profileOnboardingPreview');if(!file)return;
  if(!['image/jpeg','image/png','image/webp'].includes(file.type)){event.target.value='';document.querySelector('#profileOnboardingError').textContent='Escolha uma imagem JPG, PNG ou WebP.';return}
  if(file.size>5*1024*1024){event.target.value='';document.querySelector('#profileOnboardingError').textContent='A foto deve ter no máximo 5 MB.';return}
  if(profileOnboardingPreviewUrl)URL.revokeObjectURL(profileOnboardingPreviewUrl);
  profileOnboardingPreviewUrl=URL.createObjectURL(file);preview.style.backgroundImage=`url('${profileOnboardingPreviewUrl}')`;preview.textContent='';
  document.querySelector('#profileOnboardingError').textContent='';
});

document.querySelector('#profileOnboardingForm').addEventListener('submit',async event=>{
  event.preventDefault();
  const username=normalizeOnboardingUsername(document.querySelector('#profileOnboardingUsername').value),fileInput=document.querySelector('#profileOnboardingFile'),error=document.querySelector('#profileOnboardingError'),modal=document.querySelector('.profile-onboarding'),button=document.querySelector('#profileOnboardingSubmit');
  if(username.length<3||!/^[a-z0-9._]+$/.test(username)){error.textContent='Use de 3 a 30 caracteres: letras, números, ponto ou _.';return}
  if(!fileInput.files?.[0]&&!currentProfile?.avatar_url){error.textContent='Escolha uma foto para concluir seu perfil.';return}
  let uploaded='';modal.classList.add('is-saving');button.textContent='Preparando seu perfil…';error.textContent='';
  try{
    uploaded=await uploadProfileFile(fileInput,'avatar');
    const updates={username,updated_at:new Date().toISOString()};if(uploaded)updates.avatar_url=uploaded;
    const{error:updateError}=await window.auraSupabase.from('profiles').update(updates).eq('id',window.AURA_SESSION.user.id);if(updateError)throw updateError;
    if(profileOnboardingPreviewUrl)URL.revokeObjectURL(profileOnboardingPreviewUrl);profileOnboardingPreviewUrl='';
    await loadProfile(window.AURA_SESSION);document.querySelector('#profileOnboardingBackdrop').hidden=true;document.body.style.overflow='';showToast('Sua identidade inicial está pronta.','success','Bem-vindo à Aura');
  }catch(saveError){if(uploaded)await window.auraSupabase.storage.from('profile-media').remove([uploaded]);error.textContent=/duplicate|unique|username/i.test(saveError.message)?'Este nome de usuário já está em uso. Escolha outro.':'Não foi possível concluir seu perfil. Tente novamente.'}
  finally{modal.classList.remove('is-saving');button.innerHTML='Entrar na minha Aura <span>→</span>'}
});

document.addEventListener('aura:profile-ready',event=>showProfileOnboarding(event.detail));
