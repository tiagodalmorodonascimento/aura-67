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
  plugins.App?.addListener?.('backButton', ({ canGoBack }) => {
    const visibleOverlay = [
      '#searchOverlay:not([hidden])','#notificationBackdrop:not([hidden])','#accountPopover:not([hidden])',
      '#publicProfileBackdrop:not([hidden])','#designBackdrop:not([hidden])','#profileEditorBackdrop:not([hidden])',
      '#modalBackdrop:not([hidden])','#habitConfirmBackdrop:not([hidden])'
    ].some((selector) => document.querySelector(selector));
    if (visibleOverlay) { history.back(); return; }
    if (canGoBack && location.pathname.endsWith('/app.html')) { history.back(); return; }
    plugins.App.minimizeApp?.();
  });
})();
