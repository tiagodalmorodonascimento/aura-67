const CACHE = 'aura67-v53';
const FILES = ['./','./index.html','./login.html','./cadastro.html','./redefinir-senha.html','./app.html','./css/landing.css','./css/auth.css','./css/confirmation.css','./css/password-reset.css','./css/profile.css','./css/profile-extra.css','./css/profile-menu-v2.css','./css/email-check.css','./css/ranking-real.css','./css/theme-v3.css','./css/progression.css','./css/progression-extra.css','./css/habits.css','./css/proof.css','./css/large-ui.css','./css/identity-profile.css','./css/reminders.css','./css/push.css','./css/app-boot.css','./css/action-feedback.css','./css/feedback-cleanup.css','./css/dashboard-live.css','./css/projects.css','./css/behavior.css','./css/chat.css','./css/chat-button.css','./css/chat-page.css','./styles.css','./js/landing.js','./js/auth.js','./js/password-reset.js','./js/supabase-client.js','./js/app-auth.js','./js/profile.js','./js/reminders.js','./js/ranking.js','./js/habits.js','./js/dashboard.js','./js/behavior.js','./js/chat.js','./config/environments.js','./script.js','./manifest.json','./assets/icons/icon.svg'];
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
