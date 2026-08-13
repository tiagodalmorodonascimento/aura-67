const CACHE = 'aura67-v20';
const FILES = ['./','./index.html','./login.html','./cadastro.html','./redefinir-senha.html','./app.html','./css/landing.css','./css/auth.css','./css/confirmation.css','./css/password-reset.css','./css/profile.css','./css/profile-extra.css','./css/profile-menu-v2.css','./css/email-check.css','./css/ranking-real.css','./css/theme-v3.css','./css/progression.css','./css/progression-extra.css','./css/habits.css','./css/proof.css','./css/large-ui.css','./styles.css','./js/landing.js','./js/auth.js','./js/password-reset.js','./js/supabase-client.js','./js/app-auth.js','./js/profile.js','./js/ranking.js','./js/habits.js','./config/environments.js','./script.js','./manifest.json','./assets/icons/icon.svg'];
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
