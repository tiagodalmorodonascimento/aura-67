const AURA_LEGAL_VERSION = '2026-08-18';

function unlockAuraSession(session) {
  window.AURA_SESSION = session;
  const appUrl = `${window.location.pathname}${window.location.hash || '#dashboard'}`;
  window.history.replaceState({ auraBase: true }, '', appUrl);
  window.history.pushState({ auraGuard: true }, '', appUrl);
  window.addEventListener('popstate', (event) => {
    if (event.state?.auraBase) window.history.pushState({ auraGuard: true }, '', `${window.location.pathname}${window.location.hash || '#dashboard'}`);
  });
  const name = session.user.user_metadata?.full_name || session.user.email?.split('@')[0] || 'Pessoa Aura';
  const initials = name.split(/\s+/).slice(0, 2).map((part) => part[0]).join('').toUpperCase();
  document.querySelectorAll('.sidebar-profile strong').forEach((element) => { element.textContent = name; });
  document.querySelectorAll('.sidebar-profile .avatar').forEach((element) => { element.textContent = initials; });
  const welcomeName = document.querySelector('#welcomeName');
  if (welcomeName) welcomeName.textContent = name.split(/\s+/)[0];
  document.dispatchEvent(new CustomEvent('aura:session-ready', { detail: session }));
}

async function requestLegalAcceptance(session) {
  const backdrop = document.querySelector('#legalConsentBackdrop');
  const checkbox = document.querySelector('#legalConsentCheck');
  const button = document.querySelector('#legalConsentButton');
  const message = document.querySelector('#legalConsentMessage');
  const { data, error } = await window.auraSupabase.rpc('has_current_legal_acceptance', {
    p_terms_version: AURA_LEGAL_VERSION,
    p_privacy_version: AURA_LEGAL_VERSION
  });
  if (error) {
    backdrop.hidden = false;
    checkbox.disabled = true;
    message.textContent = /has_current_legal_acceptance|schema cache/i.test(error.message)
      ? 'Execute a migration 030 no Supabase para liberar o aceite.'
      : 'Não foi possível verificar os documentos. Tente novamente em instantes.';
    return;
  }
  if (data) { unlockAuraSession(session); return; }
  backdrop.hidden = false;
  checkbox.addEventListener('change', () => { button.disabled = !checkbox.checked; message.textContent = ''; });
  button.addEventListener('click', async () => {
    if (!checkbox.checked) return;
    button.disabled = true;
    button.textContent = 'Registrando aceite…';
    const { error: acceptError } = await window.auraSupabase.rpc('accept_current_legal_documents', {
      p_terms_version: AURA_LEGAL_VERSION,
      p_privacy_version: AURA_LEGAL_VERSION
    });
    if (acceptError) {
      message.textContent = 'Não foi possível registrar seu aceite. Tente novamente.';
      button.textContent = 'Aceitar e entrar na Aura';
      button.disabled = false;
      return;
    }
    backdrop.hidden = true;
    unlockAuraSession(session);
  });
}

(async function protectApplication() {
  if (!window.AURA_SUPABASE_CONFIGURED) {
    document.body.classList.remove('aura-booting');
    document.querySelector('#auraBoot')?.setAttribute('hidden', '');
    return;
  }
  const { data } = await window.auraSupabase.auth.getSession();
  if (!data.session) { window.location.replace('login.html'); return; }
  await requestLegalAcceptance(data.session);
})();
