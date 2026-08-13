(async function protectApplication() {
  if (!window.AURA_SUPABASE_CONFIGURED) return;
  const { data } = await window.auraSupabase.auth.getSession();
  if (!data.session) {
    window.location.replace('login.html');
    return;
  }
  window.AURA_SESSION = data.session;
  const name = data.session.user.user_metadata?.full_name || data.session.user.email?.split('@')[0] || 'Pessoa Aura';
  const initials = name.split(/\s+/).slice(0, 2).map((part) => part[0]).join('').toUpperCase();
  document.querySelectorAll('.sidebar-profile strong').forEach((element) => { element.textContent = name; });
  document.querySelectorAll('.sidebar-profile .avatar').forEach((element) => { element.textContent = initials; });
  const welcomeName = document.querySelector('#welcomeName');
  if (welcomeName) welcomeName.textContent = name.split(/\s+/)[0];
  document.dispatchEvent(new CustomEvent('aura:session-ready', { detail: data.session }));
})();
