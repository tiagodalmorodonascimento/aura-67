const sidebar = document.querySelector('#sidebar');
const sidebarOverlay = document.querySelector('#sidebarOverlay');
const menuButton = document.querySelector('#menuButton');
const pageTitle = document.querySelector('#pageTitle');
const navItems = document.querySelectorAll('.nav-item');
const modalBackdrop = document.querySelector('#modalBackdrop');
const itemName = document.querySelector('#itemName');
const searchOverlay = document.querySelector('#searchOverlay');
const searchInput = document.querySelector('#searchInput');
const toast = document.querySelector('#toast');

function resetPageScroll() {
  const scroller = document.scrollingElement || document.documentElement;
  scroller.scrollTop = 0;
  document.body.scrollTop = 0;
  document.querySelector('.main-area').scrollTop = 0;
  requestAnimationFrame(() => window.scrollTo({ top: 0, left: 0, behavior: 'auto' }));
}

function toggleMenu(open) {
  sidebar.classList.toggle('open', open);
  sidebarOverlay.classList.toggle('show', open);
  menuButton.setAttribute('aria-expanded', String(open));
}

menuButton.addEventListener('click', () => toggleMenu(!sidebar.classList.contains('open')));
sidebarOverlay.addEventListener('click', () => toggleMenu(false));

navItems.forEach((item) => item.addEventListener('click', (event) => {
  event.preventDefault();
  navItems.forEach((nav) => nav.classList.remove('active'));
  item.classList.add('active');
  pageTitle.textContent = item.dataset.page;
  toggleMenu(false);
  const isRanking = item.dataset.view === 'ranking';
  const isHabits = item.dataset.view === 'habits';
  const isProjects = item.dataset.view === 'projects';
  const isChat = item.dataset.view === 'chat';
  const isPeople = item.dataset.view === 'people';
  document.querySelector('#identityProfile').hidden = true;
  document.querySelector('#dashboard').hidden = isRanking || isHabits || isProjects || isChat || isPeople;
  document.querySelector('#ranking').hidden = !isRanking;
  document.querySelector('#habits').hidden = !isHabits;
  document.querySelector('#projects').hidden = !isProjects;
  document.querySelector('#chatPage').hidden = !isChat;
  document.querySelector('#people').hidden = !isPeople;
  if (item.dataset.page === 'Visão geral') document.querySelector('#dashboard').hidden = false;
  if (isHabits && typeof loadHabits === 'function') loadHabits();
  if (isRanking && typeof loadRealRanking === 'function') loadRealRanking();
  if (isProjects && typeof loadProjects === 'function') loadProjects();
  if (isChat && typeof loadChat === 'function') loadChat();
  if (isPeople && typeof loadAuraPeople === 'function') loadAuraPeople();
  resetPageScroll();
  if (!['Visão geral','Conversas'].includes(item.dataset.page) && !isRanking && !isHabits && !isProjects && !isChat && !isPeople) showToast(`${item.dataset.page}: módulo pronto para você editar.`);
}));

document.querySelector('#earnPointsButton').addEventListener('click', async (event) => {
  if (event.currentTarget.dataset.action === 'invite') {
    const shareData = { title: 'Aura 67', text: 'Venha evoluir comigo na Aura 67 e participe da próxima temporada.', url: `${location.origin}/` };
    try {
      if (navigator.share) await navigator.share(shareData);
      else {
        await navigator.clipboard.writeText(`${shareData.text} ${shareData.url}`);
        showToast('O convite foi copiado. Agora é só enviar para quem você quiser.','success','Convite pronto');
      }
    } catch (error) {
      if (error?.name !== 'AbortError') showToast('Não foi possível abrir o compartilhamento. Tente novamente.','error','Convite não enviado');
    }
    return;
  }
  const activityNav = [...navItems].find((item) => item.dataset.view === 'habits');
  activityNav?.click();
  window.scrollTo({ top: 0, behavior: 'smooth' });
});

document.querySelector('#overviewActivitiesButton')?.addEventListener('click', () => {
  const activityNav = [...navItems].find((item) => item.dataset.view === 'habits');
  activityNav?.click();
  window.scrollTo({ top: 0, behavior: 'smooth' });
});

function openModal() {
  modalBackdrop.hidden = false;
  document.body.style.overflow = 'hidden';
  setTimeout(() => itemName.focus(), 50);
}

function closeModal() {
  modalBackdrop.hidden = true;
  document.body.style.overflow = '';
}

document.querySelector('#mobileCreateButton')?.addEventListener('click', openModal);
document.querySelector('#modalClose').addEventListener('click', closeModal);
modalBackdrop.addEventListener('click', (event) => { if (event.target === modalBackdrop) closeModal(); });

function toggleSearch(open, fromHistory = false) {
  searchOverlay.hidden = !open;
  document.body.style.overflow = open ? 'hidden' : '';
  if (open && history.state?.auraOverlay !== 'search') history.pushState({ ...(history.state || {}), auraOverlay: 'search' }, '', location.href);
  if (!open && !fromHistory && history.state?.auraOverlay === 'search') history.back();
  if (open) setTimeout(() => searchInput.focus(), 50);
}

window.addEventListener('popstate', () => { if (!searchOverlay.hidden) toggleSearch(false, true); });

document.querySelector('#searchButton').addEventListener('click', () => toggleSearch(true));
searchOverlay.addEventListener('click', (event) => { if (event.target === searchOverlay) toggleSearch(false); });

document.addEventListener('keydown', (event) => {
  if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
    event.preventDefault();
    toggleSearch(true);
  }
  if (event.key === 'Escape') {
    if (!searchOverlay.hidden) toggleSearch(false);
    if (!modalBackdrop.hidden) closeModal();
    toggleMenu(false);
  }
});

document.querySelectorAll('.quick-card:not(#quickProjectButton), .text-button').forEach((button) => {
  button.addEventListener('click', () => showToast('Este atalho está pronto para receber sua próxima funcionalidade.'));
});

let toastTimer;
function showToast(message, kind = 'success', title = kind === 'error' ? 'Algo deu errado' : 'Tudo certo') {
  clearTimeout(toastTimer);
  toast.className = `toast action-feedback ${kind}`;
  toast.innerHTML = `<span class="action-feedback-icon">${kind === 'error' ? '!' : '✓'}</span><span><strong></strong><small></small></span><button class="action-feedback-close" type="button" aria-label="Fechar">×</button>`;
  toast.querySelector('strong').textContent = title;
  toast.querySelector('small').textContent = message;
  toast.querySelector('button').onclick = () => toast.classList.remove('show');
  toast.classList.add('show');
  toastTimer = setTimeout(() => toast.classList.remove('show'), 4200);
}

document.querySelectorAll('[data-mobile-page]').forEach((button) => button.addEventListener('click', () => {
  document.querySelector('#mobileProfileButton').classList.remove('active');
  document.querySelectorAll('[data-mobile-page]').forEach((item) => item.classList.toggle('active', item === button));
  const target = [...navItems].find((item) => item.dataset.page === button.dataset.mobilePage);
  target?.click();
}));
