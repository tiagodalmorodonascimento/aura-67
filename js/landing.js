let installPrompt;
const installButton = document.querySelector('#installButton');

window.addEventListener('beforeinstallprompt', (event) => {
  event.preventDefault();
  installPrompt = event;
  installButton.hidden = false;
});

installButton.addEventListener('click', async () => {
  if (!installPrompt) return;
  installPrompt.prompt();
  await installPrompt.userChoice;
  installPrompt = null;
  installButton.hidden = true;
});

document.querySelector('#waitlistForm').addEventListener('submit', (event) => {
  event.preventDefault();
  const email = document.querySelector('#waitlistEmail').value.trim();
  const entries = JSON.parse(localStorage.getItem('aura67_waitlist') || '[]');
  if (!entries.includes(email)) entries.push(email);
  localStorage.setItem('aura67_waitlist', JSON.stringify(entries));
  const message = document.querySelector('#waitlistMessage');
  message.textContent = 'Você entrou na lista! Avisaremos sobre o lançamento.';
  message.classList.add('success');
  event.currentTarget.reset();
});

if ('serviceWorker' in navigator) window.addEventListener('load', () => navigator.serviceWorker.register('./service-worker.js'));

async function reflectSession() {
  if (!window.auraSupabase) return;
  const { data } = await window.auraSupabase.auth.getSession();
  if (!data.session) return;
  window.location.replace('app.html');
  return;
  const action = document.querySelector('#sessionAction');
  action.textContent = 'Abrir minha Aura';
  action.href = 'app.html';
  document.querySelectorAll('a[href="cadastro.html"]').forEach((link) => {
    link.href = 'app.html';
    if (link.classList.contains('primary-cta')) link.childNodes[0].textContent = 'Continuar minha jornada ';
  });
}

reflectSession();
window.addEventListener('pageshow', reflectSession);
