const CACHE = 'aura67-v161';
const FILES = ['./','./index.html','./login.html','./cadastro.html','./redefinir-senha.html','./app.html','./css/landing.css','./css/auth.css','./css/confirmation.css','./css/password-reset.css','./css/profile.css','./css/profile-extra.css','./css/profile-menu-v2.css','./css/email-check.css','./css/ranking-real.css','./css/theme-v3.css','./css/progression.css','./css/progression-extra.css','./css/habits.css','./css/proof.css','./css/large-ui.css','./css/identity-profile.css','./css/reminders.css','./css/push.css','./css/app-boot.css','./css/action-feedback.css','./css/feedback-cleanup.css','./css/dashboard-live.css','./css/projects.css','./css/behavior.css','./css/chat.css','./css/chat-button.css','./css/chat-page.css','./css/chat-attachments.css','./css/chat-message-menu.css','./css/color-mode.css','./css/mobile-navigation-v2.css','./css/notification-mobile-layout.css','./css/mobile-landscape-fix.css','./css/motion.css','./css/fireworks.css','./css/moments.css','./styles.css','./js/landing.js','./js/auth.js','./js/password-reset.js','./js/supabase-client.js','./js/app-auth.js','./js/profile.js','./js/reminders.js','./js/ranking.js','./js/habits.js','./js/dashboard.js','./js/behavior.js','./js/chat.js','./js/motion.js','./js/fireworks.js','./js/moments.js','./config/environments.js','./script.js','./manifest.json','./assets/icons/icon.svg'];
FILES.push('./css/aura-foundation.css','./js/aura-foundation.js');
FILES.push('./css/people.css','./js/people.js');
FILES.push('./css/profile-onboarding.css','./js/profile-onboarding.js');
FILES.push('./css/chat-safety.css');
FILES.push('./css/chat-live-polish.css');
FILES.push('./css/chat-conversation-list.css','./css/chat-unread.css','./css/community-moderation-extra.css','./css/community-moderation.css','./css/design-color-wheel.css','./css/design-palette.css','./css/destructive-actions.css','./css/habit-confirmation.css','./css/honor-frames.css','./css/identity-layout-fix.css','./css/identity-studio.css');
FILES.push('./assets/honor-frames/honor-paper.webp','./assets/honor-frames/honor-cotton.webp','./assets/honor-frames/honor-wood.webp','./assets/honor-frames/honor-stone.webp','./assets/honor-frames/honor-iron.webp','./assets/honor-frames/honor-bronze.webp','./assets/honor-frames/honor-silver.webp','./assets/honor-frames/honor-gold.webp','./assets/honor-frames/honor-platinum.webp','./assets/honor-frames/honor-ruby.webp','./assets/honor-frames/honor-emerald.webp','./assets/honor-frames/honor-sapphire.webp','./assets/honor-frames/honor-diamond.webp','./assets/honor-frames/honor-red-diamond.webp');
FILES.push('./assets/honor-frames/honor-diamond-v2.png');
FILES.push('./css/mobile-visual-parity.css');
FILES.push('./js/account-delete.js','./js/color-mode.js','./js/community-moderation.js','./js/design-color-wheel.js','./js/design-palette.js','./js/identity-studio.js');
FILES.push('./termos.html','./privacidade.html','./css/legal.css');
FILES.push('./js/native-app.js');
FILES.push('./css/native-experience.css','./js/pull-refresh.js');
FILES.push('./css/communities.css','./css/community-notifications.css','./js/communities.js');
FILES.push('./css/timed-challenge.css','./js/timed-challenge.js');
FILES.push('./css/social-graph.css','./js/social-graph.js');
FILES.push('./js/honor-frame-interaction.js');
FILES.push('./css/honor-recognition.css','./js/honor-recognition.js');
FILES.push('./css/readability.css');
FILES.push('./css/chat-media-viewer.css');
FILES.push('./js/native-notifications.js');
FILES.push('./js/native-push.js');
self.addEventListener('install', (event) => { self.skipWaiting(); event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(FILES))); });
self.addEventListener('activate', (event) => event.waitUntil(Promise.all([
  caches.keys().then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key)))),
  self.clients.claim()
])));
self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;
  const requestUrl = new URL(event.request.url);
  if (requestUrl.origin !== self.location.origin) return;
  event.respondWith(fetch(event.request).then((response) => {
    if (response.ok) caches.open(CACHE).then((cache) => cache.put(event.request, response.clone()));
    return response;
  }).catch(() => caches.match(`${requestUrl.origin}${requestUrl.pathname}`).then((cached) => cached || (event.request.mode === 'navigate' ? caches.match('./index.html') : Response.error()))));
});
self.addEventListener('push', (event) => {
  let payload = {};
  try { payload = event.data ? event.data.json() : {}; } catch { payload = { body: event.data?.text() }; }
  event.waitUntil(self.registration.showNotification(payload.title || 'Aura 67 ✦', { body: payload.body || 'Uma pequena ação pode transformar o seu dia.', icon: payload.icon || './assets/icons/icon.svg', badge: payload.badge || './assets/icons/icon.svg', tag: payload.tag || 'aura-companion', data: { url: payload.url || './app.html#habits' } }));
});
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const target = new URL(event.notification.data?.url || './app.html', self.location.origin).href;
  event.waitUntil(self.clients.matchAll({type:'window',includeUncontrolled:true}).then((clients) => { const existing=clients.find((client)=>client.url.startsWith(self.location.origin)); if(existing){existing.navigate(target);return existing.focus()} return self.clients.openWindow(target) }));
});
