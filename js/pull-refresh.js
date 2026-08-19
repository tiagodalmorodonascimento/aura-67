(function setupAuraPullRefresh() {
  if (!('ontouchstart' in window) && !window.Capacitor?.isNativePlatform?.()) return;
  const main = document.querySelector('.main-area');
  if (!main) return;
  const indicator = document.createElement('div');
  indicator.className = 'pull-refresh-indicator';
  indicator.setAttribute('role', 'status');
  indicator.setAttribute('aria-live', 'polite');
  indicator.innerHTML = '<i>↓</i><span>Puxe para atualizar</span>';
  document.body.appendChild(indicator);
  let startY = 0, startX = 0, distance = 0, tracking = false, refreshing = false;
  const overlaysOpen = () => Boolean(document.querySelector('[class*="backdrop"]:not([hidden]),#searchOverlay:not([hidden]),#accountPopover:not([hidden])'));
  const atTop = () => Math.max(document.scrollingElement?.scrollTop || 0, main.scrollTop || 0) <= 0;
  function resetIndicator(delay = 0) {
    setTimeout(() => {
      main.style.removeProperty('--pull-distance');
      main.classList.remove('aura-pulling');
      main.classList.add('aura-pull-release');
      indicator.className = 'pull-refresh-indicator';
      setTimeout(() => main.classList.remove('aura-pull-release'), 260);
    }, delay);
  }
  function currentRefreshTasks() {
    if (!document.querySelector('#identityProfile')?.hidden && typeof loadIdentityProfile === 'function') return [loadIdentityProfile()];
    if (!document.querySelector('#ranking')?.hidden && typeof loadRealRanking === 'function') return [loadRealRanking()];
    if (!document.querySelector('#habits')?.hidden && typeof loadHabits === 'function') return [loadHabits()];
    if (!document.querySelector('#projects')?.hidden && typeof loadProjects === 'function') return [loadProjects()];
    if (!document.querySelector('#chatPage')?.hidden && typeof loadChat === 'function') return [loadChat()];
    if (!document.querySelector('#people')?.hidden && typeof loadAuraPeople === 'function') return [loadAuraPeople()];
    return [
      typeof loadDashboardActivity === 'function' ? loadDashboardActivity() : null,
      typeof loadProjects === 'function' ? loadProjects() : null,
      typeof loadAuraFoundation === 'function' ? loadAuraFoundation() : null,
      typeof loadAuraMoments === 'function' ? loadAuraMoments() : null
    ].filter(Boolean);
  }
  async function refreshCurrentView() {
    refreshing = true;
    indicator.className = 'pull-refresh-indicator visible refreshing';
    indicator.querySelector('span').textContent = 'Atualizando…';
    main.style.setProperty('--pull-distance', '42px');
    try {
      await Promise.allSettled(currentRefreshTasks());
      indicator.className = 'pull-refresh-indicator visible done';
      indicator.querySelector('i').textContent = '✓';
      indicator.querySelector('span').textContent = 'Tudo atualizado';
    } finally {
      refreshing = false;
      resetIndicator(650);
    }
  }
  document.addEventListener('touchstart', (event) => {
    if (refreshing || event.touches.length !== 1 || overlaysOpen() || !atTop()) return;
    startY = event.touches[0].clientY; startX = event.touches[0].clientX; distance = 0; tracking = true;
  }, { passive: true });
  document.addEventListener('touchmove', (event) => {
    if (!tracking || refreshing) return;
    const dy = event.touches[0].clientY - startY, dx = Math.abs(event.touches[0].clientX - startX);
    if (dy <= 0 || dx > dy) { tracking = false; resetIndicator(); return; }
    if (!atTop()) { tracking = false; resetIndicator(); return; }
    event.preventDefault();
    distance = Math.min(105, dy * .46);
    main.classList.add('aura-pulling');
    main.style.setProperty('--pull-distance', `${distance}px`);
    indicator.className = `pull-refresh-indicator visible${distance >= 68 ? ' ready' : ''}`;
    indicator.querySelector('span').textContent = distance >= 68 ? 'Solte para atualizar' : 'Puxe para atualizar';
  }, { passive: false });
  document.addEventListener('touchend', () => {
    if (!tracking) return;
    tracking = false;
    if (distance >= 68) refreshCurrentView(); else resetIndicator();
  }, { passive: true });
  document.addEventListener('touchcancel', () => { tracking = false; if (!refreshing) resetIndicator(); }, { passive: true });
})();
