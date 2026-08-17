(async function protectApplication() {
  if (!window.AURA_SUPABASE_CONFIGURED) { document.body.classList.remove('aura-booting'); document.querySelector('#auraBoot')?.setAttribute('hidden', ''); return; }
  const { data } = await window.auraSupabase.auth.getSession();
  if (!data.session) {
    window.location.replace('login.html');
    return;
  }
  window.AURA_SESSION = data.session;
  const appUrl = `${window.location.pathname}${window.location.hash || '#dashboard'}`;
  window.history.replaceState({ auraBase: true }, '', appUrl);
  window.history.pushState({ auraGuard: true }, '', appUrl);
  window.addEventListener('popstate', (event) => {
    if (event.state?.auraBase) window.history.pushState({ auraGuard: true }, '', `${window.location.pathname}${window.location.hash || '#dashboard'}`);
  });
  const name = data.session.user.user_metadata?.full_name || data.session.user.email?.split('@')[0] || 'Pessoa Aura';
  const initials = name.split(/\s+/).slice(0, 2).map((part) => part[0]).join('').toUpperCase();
  document.querySelectorAll('.sidebar-profile strong').forEach((element) => { element.textContent = name; });
  document.querySelectorAll('.sidebar-profile .avatar').forEach((element) => { element.textContent = initials; });
  const welcomeName = document.querySelector('#welcomeName');
  if (welcomeName) welcomeName.textContent = name.split(/\s+/)[0];
  document.dispatchEvent(new CustomEvent('aura:session-ready', { detail: data.session }));
})();
