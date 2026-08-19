(function setupNativeAura() {
  const capacitor = window.Capacitor;
  if (!capacitor?.isNativePlatform?.()) return;
  document.documentElement.classList.add('aura-native');
  document.querySelectorAll('[data-social="Google"]').forEach((button) => {
    button.disabled = true;
    button.title = 'O login Google será ativado após a configuração nativa do Google/Firebase.';
    button.innerHTML = '<b>G</b> Google — em breve no app';
  });
  const plugins = capacitor.Plugins || {};
  plugins.StatusBar?.setBackgroundColor?.({ color: '#17131f' }).catch(() => {});
  plugins.StatusBar?.setStyle?.({ style: 'DARK' }).catch(() => {});
  function clearOverlayHistory() {
    if (!history.state?.auraOverlay) return;
    const state = { ...history.state };
    delete state.auraOverlay;
    history.replaceState(state, '', location.href);
  }
  function closeTopOverlay() {
    const account = document.querySelector('#accountPopover:not([hidden])');
    if (account) { if (typeof setAccountMenu === 'function') setAccountMenu(false); else account.hidden = true; return true; }
    const notifications = document.querySelector('#notificationBackdrop:not([hidden])');
    if (notifications) { notifications.hidden = true; document.body.style.overflow = ''; clearOverlayHistory(); return true; }
    const search = document.querySelector('#searchOverlay:not([hidden])');
    if (search) { search.hidden = true; document.body.style.overflow = ''; clearOverlayHistory(); return true; }
    const closePairs = [
      ['#dangerBackdrop','#dangerClose'],['#communityReviewBackdrop','#communityReviewClose'],['#identityStudioBackdrop','#identityStudioClose'],
      ['#momentShareBackdrop','#momentShareCancel'],['#habitConfirmBackdrop','#habitConfirmClose'],['#proofBackdrop','#proofClose'],
      ['#emailCheckBackdrop','#emailCheckClose'],['#journeyBackdrop','#journeyClose'],['#publicProfileBackdrop','#publicProfileClose'],
      ['#reminderBackdrop','#reminderClose'],['#profileEditorBackdrop','#profileEditorClose'],['#designBackdrop','#designClose'],
      ['#behaviorBackdrop','#behaviorClose'],['#modalBackdrop','#modalClose']
    ];
    for (const [panelSelector, closeSelector] of closePairs) {
      if (!document.querySelector(`${panelSelector}:not([hidden])`)) continue;
      const close = document.querySelector(closeSelector);
      if (close) close.click(); else document.querySelector(panelSelector).hidden = true;
      return true;
    }
    return false;
  }
  plugins.App?.addListener?.('backButton', () => {
    if (closeTopOverlay()) return;
    if (document.querySelector('#sidebar.open')) { if (typeof toggleMenu === 'function') toggleMenu(false); return; }
    const chatPage = document.querySelector('#chatPage:not([hidden])');
    const chatShell = chatPage?.querySelector('.chat-shell');
    if (chatShell && !chatShell.classList.contains('show-contacts') && typeof showConversationList === 'function') { showConversationList(); return; }
    const dashboard = document.querySelector('#dashboard');
    if (dashboard?.hidden) {
      const home = [...document.querySelectorAll('.nav-item')].find((item) => item.dataset.page === 'Visão geral');
      home?.click();
      return;
    }
    plugins.App.minimizeApp?.();
  });
})();
