let currentProfile;
let draftAvatarUrl = '';
let draftCoverUrl = '';
let themeSaveTimer;
const accountPopover = document.querySelector('#accountPopover');
const designBackdrop = document.querySelector('#designBackdrop');
const profileEditorBackdrop = document.querySelector('#profileEditorBackdrop');
const AURA_CLASSES = [
  { name: 'Centelha', min: 0, icon: '✦', unlock: 'Perfil e avatar' },
  { name: 'Despertar', min: 100, icon: '◉', unlock: 'Detalhes especiais no perfil' },
  { name: 'Explorador', min: 500, icon: '◇', unlock: 'Cores e degradês personalizados' },
  { name: 'Influenciador', min: 1500, icon: '↗', unlock: 'Imagem de capa personalizada' },
  { name: 'Guardião', min: 3500, icon: '⬡', unlock: 'Layouts exclusivos' },
  { name: 'Luminar', min: 7000, icon: '☼', unlock: 'Efeitos visuais especiais' },
  { name: 'Aura 67', min: 15000, icon: '♛', unlock: 'Identidade lendária Aura 67' }
];
const MAX_AURA_LEVEL = 67;
const MAX_AURA_CLASS_POINTS = 15000;

function initials(name = 'Pessoa Aura') { return name.split(/\s+/).slice(0, 2).map((part) => part[0]).join('').toUpperCase(); }
function mediaUrl(path) { return path ? window.auraSupabase.storage.from('profile-media').getPublicUrl(path).data.publicUrl : ''; }
function safeText(value = '') { const node = document.createElement('span'); node.textContent = value; return node.innerHTML; }
function shiftColor(hex, amount) {
  const value = hex.replace('#', '');
  const channels = [0, 2, 4].map((index) => Math.max(0, Math.min(255, parseInt(value.slice(index, index + 2), 16) + amount)));
  return `#${channels.map((channel) => channel.toString(16).padStart(2, '0')).join('')}`;
}

function applyGlobalTheme(color = '#7657ec') {
  localStorage.setItem('aura67_last_theme', color);
  const dark = shiftColor(color, -70);
  const light = shiftColor(color, 115);
  const soft = `${color}1f`;
  const root = document.documentElement.style;
  root.setProperty('--purple', color);
  root.setProperty('--purple-dark', dark);
  root.setProperty('--theme-dark', dark);
  root.setProperty('--theme-soft', soft);
  root.setProperty('--app-background', `linear-gradient(145deg,${light}33,#f5f3f7 42%,${color}12)`);
  root.setProperty('--hero-gradient', `linear-gradient(115deg,${light}aa 0%,${color}25 52%,#e9f7f3 100%)`);
  root.setProperty('--accent-gradient', `linear-gradient(135deg,${light},${color}66)`);
  root.setProperty('--dark-gradient', `radial-gradient(circle at 75% 20%,${light}55,transparent 28%),linear-gradient(120deg,${dark},${shiftColor(color,-35)} 62%,${color})`);
}

function profileCacheKey(userId) { return `aura67_profile_${userId}`; }
function readCachedProfile(userId) { try { return JSON.parse(localStorage.getItem(profileCacheKey(userId)) || 'null'); } catch { return null; } }
function cacheProfile(userId, profile) { localStorage.setItem(profileCacheKey(userId), JSON.stringify(profile)); }
function preloadProfileMedia(profile) {
  const urls = [profile.avatar_url, profile.cover_url].filter(Boolean).map(mediaUrl);
  const preload = Promise.all(urls.map((url) => new Promise((resolve) => { const image = new Image(); image.onload = image.onerror = resolve; image.src = url; })));
  return Promise.race([preload, new Promise((resolve) => setTimeout(resolve, 2000))]);
}

function classFor(points = 0) { return [...AURA_CLASSES].reverse().find((level) => points >= level.min) || AURA_CLASSES[0]; }
function auraLevelFor(points = 0) { return Math.min(MAX_AURA_LEVEL, Math.floor((Math.max(0, points) / MAX_AURA_CLASS_POINTS) * (MAX_AURA_LEVEL - 1)) + 1); }

function renderProgression(points = 0) {
  const currentIndex = AURA_CLASSES.findIndex((level) => level === classFor(points));
  const current = AURA_CLASSES[currentIndex];
  const next = AURA_CLASSES[currentIndex + 1];
  const progress = next ? ((points - current.min) / (next.min - current.min)) * 100 : 100;
  document.querySelector('#currentClassIcon').textContent = current.icon;
  document.querySelector('#currentClassName').textContent = `${current.name} · Nível ${auraLevelFor(points)}`;
  document.querySelector('#currentPoints').textContent = points.toLocaleString('pt-BR');
  document.querySelector('#evolutionProgress').style.width = `${Math.max(0, Math.min(100, progress))}%`;
  document.querySelector('#nextClassName').textContent = next?.name || 'Classe máxima';
  document.querySelector('#pointsToNext').textContent = next ? (next.min - points).toLocaleString('pt-BR') : '0';
  document.querySelector('#nextUnlock').textContent = next?.unlock || 'Você desbloqueou toda a jornada';
  document.querySelector('#classMessage').textContent = next ? `Continue evoluindo para alcançar ${next.name}.` : 'Sua Aura alcançou uma presença lendária.';
  document.querySelector('#classRoad').innerHTML = AURA_CLASSES.map((level, index) => `<article class="class-step ${index === currentIndex ? 'reached' : index > currentIndex ? 'locked' : ''}"><span>${level.icon}</span><p><strong>${level.name}</strong><small>${level.unlock}</small></p><b>${level.min.toLocaleString('pt-BR')} pts ${index <= currentIndex ? '✓' : '🔒'}</b></article>`).join('');
  document.querySelector('#overviewTrajectory').innerHTML = AURA_CLASSES.map((level,index)=>`<article class="${index<currentIndex?'passed':index===currentIndex?'current':'locked'}"><span>${level.icon}</span><div><strong>${level.name}</strong><small>${level.min.toLocaleString('pt-BR')} pontos</small></div>${index<=currentIndex?'<b>✓</b>':'<b>○</b>'}</article>`).join('');
}

function applyDesignLocks(points = 0, founder = false) {
  const locks = [
    { input: document.querySelector('#designColor'), min: founder ? 0 : 500, text: 'Liberado na classe Explorador · 500 pontos' },
    { input: document.querySelector('#coverUpload'), min: 1500, text: 'Liberado na classe Influenciador · 1.500 pontos' }
  ];
  locks.forEach(({ input, min, text }) => {
    input.disabled = points < min;
    const label = input.closest('label');
    label.classList.toggle('locked-control', points < min);
    if (points < min) label.dataset.lock = `🔒 ${text}`; else delete label.dataset.lock;
  });
}

async function loadProfile(session) {
  const fallbackName = session.user.user_metadata?.full_name || session.user.email?.split('@')[0] || 'Pessoa Aura';
  const cachedProfile = readCachedProfile(session.user.id);
  if (cachedProfile?.theme_color) applyGlobalTheme(cachedProfile.theme_color);
  let { data, error } = await window.auraSupabase.from('profiles').select('full_name,username,bio,avatar_url,cover_url,theme_color,aura_points,member_number').eq('id', session.user.id).maybeSingle();
  if (error && /member_number/i.test(error.message)) {
    ({ data, error } = await window.auraSupabase.from('profiles').select('full_name,username,bio,avatar_url,cover_url,theme_color,aura_points').eq('id', session.user.id).maybeSingle());
  }
  if (error && /(cover_url|theme_color|aura_points)/i.test(error.message)) {
    ({ data, error } = await window.auraSupabase.from('profiles').select('full_name,username,bio,avatar_url').eq('id', session.user.id).maybeSingle());
  }
  currentProfile = { full_name: fallbackName, username: '', bio: '', avatar_url: '', cover_url: '', aura_points: 0, member_number: null, theme_color: '#7657ec', ...(cachedProfile || {}), ...(data || {}) };
  if (error) console.error('Aura 67: não foi possível carregar todos os campos do perfil.', error.message);
  cacheProfile(session.user.id, currentProfile);
  await preloadProfileMedia(currentProfile);
  applyGlobalTheme(currentProfile.theme_color);
  renderProgression(currentProfile.aura_points || 0);
  const isFounder = currentProfile.member_number && currentProfile.member_number <= 1000;
  applyDesignLocks(currentProfile.aura_points || 0, isFounder);
  document.querySelector('#founderChip').hidden = !isFounder;
  if (isFounder) document.querySelector('#founderNumber').textContent = currentProfile.member_number;
  document.querySelector('#accountName').textContent = currentProfile.full_name;
  document.querySelector('#accountEmail').textContent = session.user.email;
  const profileAvatarUrl = currentProfile.avatar_url ? mediaUrl(currentProfile.avatar_url) : '';
  const accountAvatar = document.querySelector('#accountAvatar');
  accountAvatar.style.backgroundImage = profileAvatarUrl ? `url('${profileAvatarUrl}')` : '';
  accountAvatar.textContent = profileAvatarUrl ? '' : initials(currentProfile.full_name);
  document.querySelectorAll('.sidebar-profile strong').forEach((element) => { element.textContent = currentProfile.full_name; });
  document.querySelectorAll('.sidebar-profile .avatar').forEach((element) => {
    element.style.backgroundImage = profileAvatarUrl ? `url('${profileAvatarUrl}')` : '';
    element.textContent = profileAvatarUrl ? '' : initials(currentProfile.full_name);
  });
  document.querySelector('#welcomeName').textContent = currentProfile.full_name.split(/\s+/)[0];
  document.querySelectorAll('.current-user .member strong').forEach((element) => { element.innerHTML = `${safeText(currentProfile.full_name)} <b>Você</b>`; });
  document.querySelectorAll('.podium-card.is-you>strong').forEach((element) => { element.innerHTML = `${safeText(currentProfile.full_name)} <b>Você</b>`; });
  document.querySelectorAll('.current-user-name').forEach((element) => { element.textContent = currentProfile.full_name; });
  document.querySelectorAll('.current-user-points').forEach((element) => { element.textContent = (currentProfile.aura_points || 0).toLocaleString('pt-BR'); });
  document.querySelectorAll('.current-user .member-avatar,.podium-card.is-you .podium-avatar').forEach((element) => { element.textContent = initials(currentProfile.full_name); });
  const currentRow = document.querySelector('.leader-row.current-user');
  if (currentRow) { currentRow.dataset.week = String(currentProfile.aura_points || 0); currentRow.dataset.month = String(currentProfile.aura_points || 0); }
  document.querySelector('#designName').value = currentProfile.full_name || '';
  document.querySelector('#designUsername').value = currentProfile.username || '';
  document.querySelector('#designBio').value = currentProfile.bio || '';
  document.querySelector('#designColor').value = currentProfile.theme_color || '#7657ec';
  document.querySelectorAll('#themeSwatches button').forEach((item) => item.classList.toggle('selected', item.dataset.color === document.querySelector('#designColor').value.toLowerCase()));
  updatePreview();
  document.body.classList.remove('aura-booting');
  document.querySelector('#auraBoot')?.setAttribute('hidden', '');
  document.dispatchEvent(new CustomEvent('aura:profile-ready', { detail: currentProfile }));
}

function updatePreview() {
  const name = document.querySelector('#designName').value || currentProfile?.full_name || 'Pessoa Aura';
  const color = document.querySelector('#designColor').value;
  applyGlobalTheme(color);
  document.querySelector('#previewName').textContent = name;
  document.querySelector('#previewUsername').textContent = `@${document.querySelector('#designUsername').value || 'seuusuario'}`;
  document.querySelector('#previewBio').textContent = document.querySelector('#designBio').value || 'Transformando intenção em impacto.';
  document.querySelector('#previewScore').textContent = (currentProfile?.aura_points || 0).toLocaleString('pt-BR');
  document.querySelector('#previewAvatar').textContent = initials(name);
  const coverUrl = draftCoverUrl || (currentProfile?.cover_url ? mediaUrl(currentProfile.cover_url) : '');
  const avatarUrl = draftAvatarUrl || (currentProfile?.avatar_url ? mediaUrl(currentProfile.avatar_url) : '');
  document.querySelector('#previewCover').style.background = coverUrl ? `url('${coverUrl}') center/cover no-repeat` : `linear-gradient(120deg,#2d2537,${color})`;
  document.querySelector('#previewAvatar').style.backgroundImage = avatarUrl ? `url('${avatarUrl}')` : '';
  if (avatarUrl) document.querySelector('#previewAvatar').textContent = '';
}

async function openPublicProfile(person) {
  if (person.lifetime_points != null) person = { ...person, aura_points: person.lifetime_points };
  const color = person.theme_color || '#7657ec';
  const dark = shiftColor(color, -65);
  const backdrop = document.querySelector('#publicProfileBackdrop');
  const cover = document.querySelector('#publicProfileCover');
  backdrop.style.setProperty('--viewed-color', color);
  backdrop.style.setProperty('--viewed-dark', dark);
  backdrop.style.setProperty('--viewed-gradient', `linear-gradient(120deg,${dark},${color})`);
  cover.style.background = person.cover_url ? `url('${mediaUrl(person.cover_url)}') center/cover no-repeat` : `linear-gradient(120deg,${dark},${color})`;
  const avatar = document.querySelector('#publicProfileAvatar');
  avatar.style.backgroundImage = person.avatar_url ? `url('${mediaUrl(person.avatar_url)}')` : '';
  avatar.textContent = person.avatar_url ? '' : initials(person.full_name);
  document.querySelector('#publicProfileName').textContent = person.full_name;
  document.querySelector('#publicProfileUsername').textContent = `@${person.username || 'perfil-aura'}`;
  document.querySelector('#publicProfileBio').textContent = person.bio || 'Esta pessoa está construindo sua jornada Aura.';
  document.querySelector('#publicProfileScore').textContent = (person.aura_points || 0).toLocaleString('pt-BR');
  const viewedClass = classFor(person.aura_points || 0);
  document.querySelector('#publicClassIcon').textContent = viewedClass.icon;
  document.querySelector('#publicClassName').textContent = viewedClass.name;
  document.querySelector('#publicMemberNumber').textContent = person.member_number ? `#${person.member_number}` : '—';
  document.querySelector('#publicFounderBadge').hidden = !(person.member_number && person.member_number <= 1000);
  const { count } = await window.auraSupabase.from('profiles').select('id', { count: 'exact', head: true }).gt('aura_points', person.aura_points || 0);
  document.querySelector('#publicProfilePosition').textContent = count == null ? '—' : `${count + 1}º`;
  window.AURA_VIEWED_PROFILE_ID = person.id;
  window.AURA_VIEWED_PROFILE = person;
  document.querySelector('#publicProfileMessage').hidden = person.id === window.AURA_SESSION?.user?.id;
  document.dispatchEvent(new CustomEvent('aura:public-profile-opened', { detail: { profileId: person.id } }));
  backdrop.hidden = false;
  document.body.style.overflow = 'hidden';
}

document.querySelector('#publicProfileMessage').addEventListener('click', async () => {
  const person = window.AURA_VIEWED_PROFILE;
  if (!person || person.id === window.AURA_SESSION?.user?.id || typeof openDirectChat !== 'function') return;
  document.querySelector('#publicProfileBackdrop').hidden = true;
  document.body.style.overflow = '';
  await openDirectChat(person);
});

async function uploadProfileFile(input, folder) {
  const file = input.files[0];
  if (!file) return null;
  if (file.size > 5 * 1024 * 1024) throw new Error('A imagem deve ter no máximo 5 MB.');
  const extension = file.name.split('.').pop().toLowerCase();
  const path = `${window.AURA_SESSION.user.id}/${folder}-${Date.now()}.${extension}`;
  const { error } = await window.auraSupabase.storage.from('profile-media').upload(path, file, { upsert: true });
  if (error) throw error;
  return path;
}

function honorFrameClass(points = 0) {
  if (points >= 500) return 'honor-legendary';
  if (points >= 200) return 'honor-exemplary';
  if (points >= 75) return 'honor-elevated';
  if (points >= 20) return 'honor-recognized';
  return 'honor-initial';
}

async function loadIdentityProfile() {
  if (!window.AURA_SESSION) return;
  const { data, error } = await window.auraSupabase.rpc('public_profile_identity', { p_profile_id: window.AURA_SESSION.user.id });
  if (error) { showToast('Não foi possível carregar a identidade. Verifique a migration 007.'); return; }
  const profile = data?.profile || currentProfile;
  if (!profile) return;
  const color = profile.theme_color || '#7657ec';
  const hero = document.querySelector('#identityProfile');
  hero.style.setProperty('--identity-color', color);
  hero.style.setProperty('--identity-dark', shiftColor(color, -70));
  document.querySelector('#identityCover').style.background = profile.cover_url ? `url('${mediaUrl(profile.cover_url)}') center/cover no-repeat` : `linear-gradient(120deg,${shiftColor(color,-70)},${color})`;
  const avatar = document.querySelector('#identityAvatar');
  avatar.style.backgroundImage = profile.avatar_url ? `url('${mediaUrl(profile.avatar_url)}')` : '';
  avatar.textContent = profile.avatar_url ? '' : initials(profile.full_name);
  const frame = document.querySelector('#identityAvatarFrame');
  frame.className = `identity-avatar-frame ${honorFrameClass(profile.honor_points || 0)}`;
  document.querySelector('#identityName').textContent = profile.full_name;
  document.querySelector('#identityUsername').textContent = `@${profile.username || 'defina-seu-usuario'}`;
  document.querySelector('#identityBio').textContent = profile.bio || 'Sua evolução começa aqui.';
  document.querySelector('#identityAuraPoints').textContent = (profile.aura_points || 0).toLocaleString('pt-BR');
  document.querySelector('#identityHonorPoints').textContent = (profile.honor_points || 0).toLocaleString('pt-BR');
  document.querySelector('#identityVisits').textContent = (profile.profile_visit_count || 0).toLocaleString('pt-BR');
  document.querySelector('#identityMember').textContent = profile.member_number ? `#${profile.member_number}` : '—';
  document.querySelector('#identityHonorLevel').textContent = profile.honor_level || 'Honra Inicial';
  const level = classFor(profile.aura_points || 0);
  const levelIndex = AURA_CLASSES.findIndex((item) => item.name === level.name);
  const next = AURA_CLASSES[levelIndex + 1];
  const progress = next ? ((profile.aura_points - level.min) / (next.min - level.min)) * 100 : 100;
  document.querySelector('#identityAuraClass').textContent = `Classe ${level.name} · Nível ${auraLevelFor(profile.aura_points || 0)}`;
  document.querySelector('#identityAuraProgress').style.width = `${Math.max(0, Math.min(100, progress))}%`;
  document.querySelector('#identityNextAura').textContent = next ? `Próxima classe em ${(next.min - profile.aura_points).toLocaleString('pt-BR')} pontos` : 'Classe máxima alcançada';
  const honors = data?.honors || [];
  document.querySelector('#identityHonorCategories').innerHTML = honors.length ? honors.map((honor) => `<span>${safeText(honor.icon)} ${safeText(honor.name)} <b>${honor.count}</b></span>`).join('') : '<span>Nenhuma Honra recebida ainda.</span>';
  const trophies = data?.achievements || [];
  document.querySelector('#identityTrophyCount').textContent = `${trophies.length} ${trophies.length === 1 ? 'conquistado' : 'conquistados'}`;
  document.querySelector('#identityTrophies').innerHTML = trophies.length ? trophies.map((trophy) => `<article class="trophy-item"><span>${safeText(trophy.icon)}</span><div><strong>${safeText(trophy.name)}</strong><small>${safeText(trophy.description)}</small></div></article>`).join('') : '<p>Suas conquistas aparecerão aqui.</p>';
}

function openOwnProfile() {
  window.history.replaceState({ ...(window.history.state || {}), auraView: '#perfil' }, '', '#perfil');
  ['dashboard','ranking','habits','projects','chatPage','people'].forEach((id) => { document.querySelector(`#${id}`).hidden = true; });
  document.querySelector('#identityProfile').hidden = false;
  document.querySelector('#pageTitle').textContent = 'Meu perfil';
  document.querySelectorAll('.nav-item').forEach((item) => item.classList.remove('active'));
  document.querySelectorAll('[data-mobile-page],#mobileProfileButton').forEach((item) => item.classList.toggle('active', item.id === 'mobileProfileButton'));
  if (typeof resetPageScroll === 'function') resetPageScroll();
  else window.scrollTo({ top: 0, left: 0, behavior: 'auto' });
  loadIdentityProfile();
}

document.addEventListener('aura:session-ready', (event) => loadProfile(event.detail));
if (window.AURA_SESSION) loadProfile(window.AURA_SESSION);
function setAccountMenu(open) {
  accountPopover.hidden = !open;
  document.documentElement.classList.toggle('account-menu-open', open);
  document.body.classList.toggle('account-menu-open', open);
}
document.querySelector('#profileMenuButton').addEventListener('click', openOwnProfile);
document.querySelector('#mobileProfileButton').addEventListener('click', openOwnProfile);
document.querySelector('#identitySettingsButton').addEventListener('click', () => setAccountMenu(true));
document.querySelector('#openDesignButton').addEventListener('click', () => { setAccountMenu(false); designBackdrop.hidden = false; document.body.style.overflow = 'hidden'; });
document.querySelector('#openProfileEditorButton').addEventListener('click', () => { setAccountMenu(false); profileEditorBackdrop.hidden = false; document.body.style.overflow = 'hidden'; updatePreview(); });
document.querySelector('#accountMenuClose').addEventListener('click', () => setAccountMenu(false));
document.querySelector('#designClose').addEventListener('click', () => { applyGlobalTheme(currentProfile?.theme_color || '#7657ec'); designBackdrop.hidden = true; document.body.style.overflow = ''; });
document.querySelector('#profileEditorClose').addEventListener('click', () => { profileEditorBackdrop.hidden = true; document.body.style.overflow = ''; });
document.querySelector('#publicProfileClose').addEventListener('click', () => { document.querySelector('#publicProfileBackdrop').hidden = true; document.body.style.overflow = ''; });
document.querySelector('#publicProfileBackdrop').addEventListener('click', (event) => { if (event.target.id === 'publicProfileBackdrop') document.querySelector('#publicProfileClose').click(); });
document.querySelector('#evolutionDetailsButton').addEventListener('click', () => { document.querySelector('#journeyBackdrop').hidden = false; document.body.style.overflow = 'hidden'; });
document.querySelector('#overviewJourneyButton').addEventListener('click', () => document.querySelector('#evolutionDetailsButton').click());
document.querySelector('#journeyClose').addEventListener('click', () => { document.querySelector('#journeyBackdrop').hidden = true; document.body.style.overflow = ''; });
document.querySelector('#journeyBackdrop').addEventListener('click', (event) => { if (event.target.id === 'journeyBackdrop') document.querySelector('#journeyClose').click(); });
designBackdrop.addEventListener('click', (event) => { if (event.target === designBackdrop) document.querySelector('#designClose').click(); });
profileEditorBackdrop.addEventListener('click', (event) => { if (event.target === profileEditorBackdrop) document.querySelector('#profileEditorClose').click(); });
['designName','designUsername','designBio','designColor'].forEach((id) => document.querySelector(`#${id}`).addEventListener('input', updatePreview));
document.querySelectorAll('#themeSwatches button').forEach((button) => button.addEventListener('click', () => {
  document.querySelector('#designColor').value = button.dataset.color;
  document.querySelectorAll('#themeSwatches button').forEach((item) => item.classList.toggle('selected', item === button));
  applyGlobalTheme(button.dataset.color);
  scheduleThemeSave();
}));
document.querySelector('#designColor').addEventListener('input', (event) => {
  document.querySelectorAll('#themeSwatches button').forEach((item) => item.classList.toggle('selected', item.dataset.color === event.target.value.toLowerCase()));
  scheduleThemeSave();
});

function scheduleThemeSave(){
  clearTimeout(themeSaveTimer);
  const message=document.querySelector('#designMessage');
  message.style.color='#7d7684';message.textContent='Salvando automaticamente…';
  themeSaveTimer=setTimeout(async()=>{
    const theme_color=document.querySelector('#designColor').value;
    const{error}=await window.auraSupabase.from('profiles').update({theme_color,updated_at:new Date().toISOString()}).eq('id',window.AURA_SESSION.user.id);
    if(error){message.style.color='#b44';message.textContent='Não foi possível salvar automaticamente.';return}
    currentProfile={...currentProfile,theme_color};cacheProfile(window.AURA_SESSION.user.id,currentProfile);message.style.color='#318361';message.textContent='Design atualizado automaticamente ✓';
  },650);
}
function previewProfileFile(input,type){
  const file=input.files?.[0];if(!file)return;
  if(type==='avatar'&&draftAvatarUrl)URL.revokeObjectURL(draftAvatarUrl);
  if(type==='cover'&&draftCoverUrl)URL.revokeObjectURL(draftCoverUrl);
  if(type==='avatar')draftAvatarUrl=URL.createObjectURL(file);else draftCoverUrl=URL.createObjectURL(file);
  updatePreview();
}
document.querySelector('#avatarUpload').addEventListener('change',event=>previewProfileFile(event.target,'avatar'));
document.querySelector('#coverUpload').addEventListener('change',event=>previewProfileFile(event.target,'cover'));

function validateUsername() {
  const input = document.querySelector('#designUsername');
  const error = document.querySelector('#usernameError');
  const value = input.value.trim();
  let message = '';
  if (value.length < 3) message = 'O nome de usuário precisa ter pelo menos 3 caracteres.';
  else if (!/^[a-z0-9._]+$/.test(value)) message = 'Use somente letras minúsculas sem acento, números, ponto ou _.';
  input.setCustomValidity(message);
  error.textContent = message;
  return !message;
}
document.querySelector('#designUsername').addEventListener('input', validateUsername);

function maskEmail(email){const[local,domain]=email.split('@');const visible=local.slice(0,Math.min(2,local.length));return `${visible}${'•'.repeat(Math.max(3,local.length-visible.length))}@${domain}`;}
function emailProviderUrl(email){const domain=email.split('@')[1]?.toLowerCase();if(domain?.includes('gmail'))return'https://mail.google.com/';if(domain?.includes('outlook')||domain?.includes('hotmail')||domain?.includes('live'))return'https://outlook.live.com/mail/';if(domain?.includes('yahoo'))return'https://mail.yahoo.com/';if(domain?.includes('icloud'))return'https://www.icloud.com/mail/';return'mailto:';}
let passwordResendTimer;
async function sendPasswordEmail(){const email=window.AURA_SESSION.user.email;const button=document.querySelector('#changePasswordButton');button.disabled=true;const{error}=await window.auraSupabase.auth.resetPasswordForEmail(email,{redirectTo:`${window.location.origin}/redefinir-senha.html`});button.disabled=false;if(error){showToast(error.message,'error','Não foi possível enviar');return false;}document.querySelector('#passwordMaskedEmail').textContent=maskEmail(email);document.querySelector('#openEmailProvider').href=emailProviderUrl(email);document.querySelector('#accountPopover').hidden=true;document.querySelector('#emailCheckBackdrop').hidden=false;document.body.style.overflow='hidden';showToast('Confira sua caixa de entrada e a pasta de spam.','success','E-mail enviado');return true;}
function startPasswordResendCountdown(){clearInterval(passwordResendTimer);const button=document.querySelector('#resendPasswordEmail');let seconds=30;button.disabled=true;button.textContent=`Reenviar em ${seconds}s`;passwordResendTimer=setInterval(()=>{seconds-=1;button.textContent=seconds?`Reenviar em ${seconds}s`:'Reenviar e-mail';if(!seconds){clearInterval(passwordResendTimer);button.disabled=false;}},1000);}
document.querySelector('#changePasswordButton').addEventListener('click',async()=>{if(await sendPasswordEmail())startPasswordResendCountdown();});
document.querySelector('#resendPasswordEmail').addEventListener('click',async()=>{if(await sendPasswordEmail())startPasswordResendCountdown();});
document.querySelector('#emailCheckClose').addEventListener('click',()=>{document.querySelector('#emailCheckBackdrop').hidden=true;document.body.style.overflow='';});
document.querySelector('#emailCheckBackdrop').addEventListener('click',(event)=>{if(event.target.id==='emailCheckBackdrop')document.querySelector('#emailCheckClose').click();});
document.querySelector('#logoutButton').addEventListener('click', async () => { localStorage.removeItem(profileCacheKey(window.AURA_SESSION.user.id)); await window.auraSupabase.auth.signOut(); window.location.replace('login.html'); });

document.querySelector('#designForm').addEventListener('submit', async (event) => {
  event.preventDefault();
  const message = document.querySelector('#designMessage');
  message.textContent = 'Salvando suas cores…';
  try {
    const updates = { theme_color: document.querySelector('#designColor').value, updated_at: new Date().toISOString() };
    const { error } = await window.auraSupabase.from('profiles').update(updates).eq('id', window.AURA_SESSION.user.id);
    if (error) throw error;
    currentProfile = { ...currentProfile, ...updates };
    cacheProfile(window.AURA_SESSION.user.id, currentProfile);
    applyGlobalTheme(updates.theme_color);
    message.style.color = '#318361'; message.textContent = 'Suas cores foram salvas.';
    showToast('As novas cores já estão aplicadas ao seu espaço.','success','Design atualizado');
  } catch (error) { message.textContent = ''; showToast(error.message,'error','Não foi possível salvar'); }
});

document.querySelector('#profileForm').addEventListener('submit', async (event) => {
  event.preventDefault();
  if (!validateUsername()) { document.querySelector('#designUsername').reportValidity(); return; }
  const message = document.querySelector('#profileMessage');
  message.textContent = 'Salvando seu perfil…';
  try {
    const avatar = await uploadProfileFile(document.querySelector('#avatarUpload'), 'avatar');
    const cover = await uploadProfileFile(document.querySelector('#coverUpload'), 'cover');
    const updates = { full_name: document.querySelector('#designName').value.trim(), username: document.querySelector('#designUsername').value.trim().toLowerCase(), bio: document.querySelector('#designBio').value.trim(), updated_at: new Date().toISOString() };
    if (avatar) updates.avatar_url = avatar;
    if (cover) updates.cover_url = cover;
    const { error } = await window.auraSupabase.from('profiles').update(updates).eq('id', window.AURA_SESSION.user.id);
    if (error) {
      if (/duplicate|unique|username/i.test(error.message)) throw new Error('Este nome de usuário já está sendo usado. Escolha outro.');
      throw error;
    }
    currentProfile = { ...currentProfile, ...updates };
    if(draftAvatarUrl)URL.revokeObjectURL(draftAvatarUrl);if(draftCoverUrl)URL.revokeObjectURL(draftCoverUrl);draftAvatarUrl='';draftCoverUrl='';
    await loadProfile(window.AURA_SESSION);
    message.style.color = '#318361'; message.textContent = 'Seu perfil foi salvo com sucesso.';
    showToast('Suas informações e imagens foram atualizadas.','success','Perfil atualizado');
  } catch (error) { message.textContent = ''; showToast(error.message,'error','Não foi possível salvar'); }
});

let searchTimer;
document.querySelector('#searchInput').addEventListener('input', (event) => {
  clearTimeout(searchTimer);
  const term = event.target.value.trim().replace(/[%_,]/g, '');
  if (term.length < 2) { document.querySelector('#peopleResults').innerHTML = '<p>Digite pelo menos 2 caracteres para encontrar pessoas.</p>'; return; }
  searchTimer = setTimeout(async () => {
    const { data, error } = await window.auraSupabase.from('profiles').select('id,full_name,username,bio,avatar_url,cover_url,theme_color,aura_points,member_number').or(`full_name.ilike.%${term}%,username.ilike.%${term}%`).limit(12);
    const results = document.querySelector('#peopleResults');
    if (error || !data?.length) { results.innerHTML = '<p>Nenhuma pessoa encontrada.</p>'; return; }
    results.innerHTML = data.map((person, index) => `<article class="person-result" data-result-index="${index}" tabindex="0"><span class="person-result-avatar"${person.avatar_url ? ` style="background-image:url('${mediaUrl(person.avatar_url)}')"` : ''}>${person.avatar_url ? '' : safeText(initials(person.full_name))}</span><span><strong>${safeText(person.full_name)}</strong><small>@${safeText(person.username || 'perfil-aura')} · ${safeText(person.bio || 'Construindo sua jornada.')}</small></span><b>✦ ${(person.aura_points || 0).toLocaleString('pt-BR')}</b></article>`).join('');
    results.querySelectorAll('.person-result').forEach((element) => {
      const open = () => { document.querySelector('#searchOverlay').hidden = true; openPublicProfile(data[Number(element.dataset.resultIndex)]); };
      element.addEventListener('click', open);
      element.addEventListener('keydown', (keyboardEvent) => { if (keyboardEvent.key === 'Enter') open(); });
    });
  }, 300);
});
