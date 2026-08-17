const AUTH_KEY = 'aura67_demo_users';
const supabaseClient = window.auraSupabase;
const environmentNote = document.querySelector('#environmentNote');
let pendingEmail = '';
let pendingPassword = '';

async function skipEntryWhenAuthenticated() {
  if (!supabaseClient) return;
  const { data } = await supabaseClient.auth.getSession();
  if (data.session) window.location.replace(postLoginDestination());
}

skipEntryWhenAuthenticated();
window.addEventListener('pageshow', skipEntryWhenAuthenticated);

if (document.querySelector('#confirmationWaiting')) {
  const confirmationStyles = document.createElement('link');
  confirmationStyles.rel = 'stylesheet';
  confirmationStyles.href = 'css/confirmation.css';
  document.head.appendChild(confirmationStyles);
}

if (environmentNote) {
  environmentNote.textContent = window.AURA_SUPABASE_CONFIGURED
    ? `Ambiente ${window.AURA_ENV === 'production' ? 'de produção' : 'de teste'} conectado com segurança.`
    : 'Modo local: adicione a URL e a chave pública do Supabase para ativar contas reais.';
}

function redirectUrl(path = 'app.html') {
  const base = window.AURA_CURRENT_CONFIG?.siteUrl || window.location.origin;
  return `${base.replace(/\/$/, '')}/${path}`;
}

function postLoginDestination() {
  return new URLSearchParams(window.location.search).get('next') === 'admin' ? 'admin.html' : 'app.html';
}

function showConfirmationWaiting(email) {
  pendingEmail = email;
  document.querySelector('#signupEntry').hidden = true;
  document.querySelector('#confirmationWaiting').hidden = false;
  document.querySelector('#confirmationSuccess').hidden = true;
  document.querySelector('#confirmationEmail').textContent = email;
}

function showConfirmationSuccess() {
  document.querySelector('#signupEntry')?.setAttribute('hidden', '');
  document.querySelector('#confirmationWaiting')?.setAttribute('hidden', '');
  const success = document.querySelector('#confirmationSuccess');
  if (success) success.hidden = false;
}

async function demoHash(value) {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

function setMessage(message, success = false) {
  const box = document.querySelector('#formMessage');
  if (!box) return;
  box.textContent = message;
  box.classList.toggle('success', success);
}

function fieldError(input, message = '') {
  input.classList.toggle('invalid', Boolean(message));
  const error = input.closest('label')?.querySelector('.field-error');
  if (error) error.textContent = message;
}

document.querySelectorAll('.password-toggle').forEach((button) => button.addEventListener('click', () => {
  const input = button.parentElement.querySelector('input');
  input.type = input.type === 'password' ? 'text' : 'password';
  button.setAttribute('aria-label', input.type === 'password' ? 'Mostrar senha' : 'Ocultar senha');
}));

document.querySelectorAll('[data-social]').forEach((button) => button.addEventListener('click', async () => {
  if (!supabaseClient) { setMessage('Configure o Supabase para ativar o login com Google.'); return; }
  const { error } = await supabaseClient.auth.signInWithOAuth({ provider: 'google', options: { redirectTo: redirectUrl() } });
  if (error) setMessage(error.message);
}));

document.querySelector('#signupForm')?.addEventListener('submit', async (event) => {
  event.preventDefault();
  const name = document.querySelector('#signupName');
  const email = document.querySelector('#signupEmail');
  const password = document.querySelector('#signupPassword');
  [name, email, password].forEach((input) => fieldError(input));
  let valid = true;
  if (name.value.trim().length < 2) { fieldError(name, 'Informe seu nome.'); valid = false; }
  if (!email.validity.valid) { fieldError(email, 'Informe um e-mail válido.'); valid = false; }
  if (password.value.length < 8) { fieldError(password, 'Use pelo menos 8 caracteres.'); valid = false; }
  if (!document.querySelector('#terms').checked) { setMessage('Você precisa aceitar os termos para continuar.'); valid = false; }
  if (!valid) return;
  if (supabaseClient) {
    const submit = event.currentTarget.querySelector('[type="submit"]');
    submit.disabled = true;
    setMessage('Criando sua conta…', true);
    const { data, error } = await supabaseClient.auth.signUp({
      email: email.value.trim().toLowerCase(),
      password: password.value,
      options: { data: { full_name: name.value.trim() }, emailRedirectTo: redirectUrl('cadastro.html') }
    });
    submit.disabled = false;
    if (error) { setMessage(error.message); return; }
    if (data.session) {
      showConfirmationSuccess();
    } else {
      pendingPassword = password.value;
      showConfirmationWaiting(email.value.trim().toLowerCase());
    }
    return;
  }
  const users = JSON.parse(localStorage.getItem(AUTH_KEY) || '[]');
  if (users.some((user) => user.email === email.value.trim().toLowerCase())) { setMessage('Este e-mail já possui uma conta neste dispositivo.'); return; }
  users.push({ name: name.value.trim(), email: email.value.trim().toLowerCase(), demoPasswordHash: await demoHash(password.value) });
  localStorage.setItem(AUTH_KEY, JSON.stringify(users));
  sessionStorage.setItem('aura67_session', JSON.stringify({ name: name.value.trim(), email: email.value.trim().toLowerCase() }));
  setMessage('Conta de demonstração criada. Abrindo sua Aura…', true);
  setTimeout(() => window.location.replace('app.html'), 900);
});

document.querySelector('#loginForm')?.addEventListener('submit', async (event) => {
  event.preventDefault();
  const email = document.querySelector('#loginEmail');
  const password = document.querySelector('#loginPassword');
  if (supabaseClient) {
    const submit = event.currentTarget.querySelector('[type="submit"]');
    submit.disabled = true;
    setMessage('Entrando…', true);
    const { error } = await supabaseClient.auth.signInWithPassword({ email: email.value.trim().toLowerCase(), password: password.value });
    submit.disabled = false;
    if (error) { setMessage('E-mail ou senha incorretos, ou conta ainda não confirmada.'); return; }
    setMessage('Login realizado. Abrindo sua Aura…', true);
    setTimeout(() => window.location.replace(postLoginDestination()), 500);
    return;
  }
  const users = JSON.parse(localStorage.getItem(AUTH_KEY) || '[]');
  const passwordHash = await demoHash(password.value);
  const user = users.find((entry) => entry.email === email.value.trim().toLowerCase() && entry.demoPasswordHash === passwordHash);
  if (!user) { setMessage('Conta não encontrada ou senha incorreta. Crie uma conta de demonstração primeiro.'); return; }
  sessionStorage.setItem('aura67_session', JSON.stringify({ name: user.name, email: user.email }));
  setMessage('Login realizado. Abrindo sua Aura…', true);
  setTimeout(() => window.location.replace(postLoginDestination()), 700);
});

document.querySelector('#forgotLink')?.addEventListener('click', async (event) => {
  event.preventDefault();
  if (!supabaseClient) { setMessage('Configure o Supabase para ativar a recuperação por e-mail.'); return; }
  const email = document.querySelector('#loginEmail');
  if (!email.validity.valid) { fieldError(email, 'Informe seu e-mail primeiro.'); return; }
  const { error } = await supabaseClient.auth.resetPasswordForEmail(email.value.trim().toLowerCase(), { redirectTo: redirectUrl('login.html') });
  setMessage(error ? error.message : 'Enviamos as instruções de recuperação para seu e-mail.', !error);
});

document.querySelector('#confirmedButton')?.addEventListener('click', async () => {
  const status = document.querySelector('#confirmationStatus');
  status.innerHTML = '<i></i> Verificando confirmação…';
  if (!pendingEmail || !pendingPassword) {
    status.textContent = 'Abra novamente o link recebido ou entre com sua conta.';
    return;
  }
  const { error } = await supabaseClient.auth.signInWithPassword({ email: pendingEmail, password: pendingPassword });
  if (error) {
    status.innerHTML = '<i></i> Ainda não identificamos a confirmação. Confirme no e-mail e tente novamente.';
    return;
  }
  status.classList.add('success');
  status.innerHTML = '<i></i> E-mail confirmado com sucesso!';
  setTimeout(showConfirmationSuccess, 450);
});

document.querySelector('#resendButton')?.addEventListener('click', async () => {
  const status = document.querySelector('#confirmationStatus');
  const { error } = await supabaseClient.auth.resend({ type: 'signup', email: pendingEmail, options: { emailRedirectTo: redirectUrl('cadastro.html') } });
  status.textContent = error ? error.message : 'Um novo e-mail de confirmação foi enviado.';
  status.classList.toggle('success', !error);
});

document.querySelector('#changeEmailButton')?.addEventListener('click', () => {
  pendingEmail = '';
  pendingPassword = '';
  document.querySelector('#confirmationWaiting').hidden = true;
  document.querySelector('#signupEntry').hidden = false;
});

if (supabaseClient && document.querySelector('#confirmationSuccess')) {
  supabaseClient.auth.onAuthStateChange((event, session) => {
    if (session && (event === 'SIGNED_IN' || event === 'INITIAL_SESSION')) showConfirmationSuccess();
  });
}

if ('serviceWorker' in navigator) window.addEventListener('load', () => navigator.serviceWorker.register('./service-worker.js'));
