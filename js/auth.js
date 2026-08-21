const AUTH_KEY = 'aura67_demo_users';
const supabaseClient = window.auraSupabase;
const environmentNote = document.querySelector('#environmentNote');
let pendingEmail = '';
let pendingPassword = '';
const recoveryLinkSignal=location.hash.includes('type=recovery')||new URLSearchParams(location.search).get('type')==='recovery';
if(recoveryLinkSignal){sessionStorage.setItem('aura67_password_recovery','pending');window.location.replace(`redefinir-senha.html${location.search}${location.hash}`)}
if(supabaseClient){supabaseClient.auth.onAuthStateChange((event)=>{if(event!=='PASSWORD_RECOVERY')return;sessionStorage.setItem('aura67_password_recovery','pending');window.location.replace(`redefinir-senha.html${location.search}${location.hash}`)})}

const feedbackStyles = document.createElement('link');
feedbackStyles.rel = 'stylesheet'; feedbackStyles.href = 'css/action-feedback.css?v=35'; document.head.appendChild(feedbackStyles);
const feedbackCleanupStyles=document.createElement('link');feedbackCleanupStyles.rel='stylesheet';feedbackCleanupStyles.href='css/feedback-cleanup.css?v=36';document.head.appendChild(feedbackCleanupStyles);
document.body.insertAdjacentHTML('beforeend','<div class="action-confirm-backdrop" id="resetConfirmBackdrop" hidden><section class="action-confirm" role="dialog" aria-modal="true" aria-labelledby="resetConfirmTitle"><div class="action-confirm-icon">✉</div><h2 id="resetConfirmTitle">Enviar link de recuperação?</h2><p>Enviaremos um e-mail seguro para você criar uma nova senha.</p><strong class="action-confirm-email" id="resetConfirmEmail"></strong><div class="action-confirm-buttons"><button type="button" id="resetConfirmCancel">Cancelar</button><button class="action-confirm-primary" type="button" id="resetConfirmSend">Sim, enviar link</button></div></section></div><div class="action-feedback" id="authFeedback" role="status" aria-live="polite"></div>');
let authFeedbackTimer;
function showAuthFeedback(title,message,kind='success'){const panel=document.querySelector('#authFeedback');clearTimeout(authFeedbackTimer);panel.className=`action-feedback ${kind}`;panel.innerHTML=`<span class="action-feedback-icon">${kind==='error'?'!':'✓'}</span><span><strong></strong><small></small></span><button class="action-feedback-close" type="button" aria-label="Fechar">×</button>`;panel.querySelector('strong').textContent=title;panel.querySelector('small').textContent=message;panel.querySelector('button').onclick=()=>panel.classList.remove('show');requestAnimationFrame(()=>panel.classList.add('show'));authFeedbackTimer=setTimeout(()=>panel.classList.remove('show'),4200)}
function confirmPasswordReset(email){return new Promise((resolve)=>{const backdrop=document.querySelector('#resetConfirmBackdrop');document.querySelector('#resetConfirmEmail').textContent=email;backdrop.hidden=false;const finish=(answer)=>{backdrop.hidden=true;resolve(answer)};document.querySelector('#resetConfirmCancel').onclick=()=>finish(false);document.querySelector('#resetConfirmSend').onclick=()=>finish(true);backdrop.onclick=(event)=>{if(event.target===backdrop)finish(false)};document.querySelector('#resetConfirmSend').focus()})}

async function skipEntryWhenAuthenticated() {
  if (!supabaseClient) return;
  if(recoveryLinkSignal||sessionStorage.getItem('aura67_password_recovery')==='pending')return;
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
  box.textContent = '';
  box.classList.remove('success');
  if (message && !success) showAuthFeedback('Verifique os dados', message, 'error');
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
  setMessage('');
  showAuthFeedback('Conta criada','Seu espaço Aura está pronto para começar.');
  setTimeout(() => window.location.replace('app.html'), 1100);
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
    if (error) { setMessage(''); showAuthFeedback('Não foi possível entrar','Confira o e-mail e a senha informados.','error'); return; }
    setMessage('');
    showAuthFeedback('Login confirmado','Bem-vindo de volta. Sua jornada está pronta.');
    setTimeout(() => window.location.replace(postLoginDestination()), 1100);
    return;
  }
  const users = JSON.parse(localStorage.getItem(AUTH_KEY) || '[]');
  const passwordHash = await demoHash(password.value);
  const user = users.find((entry) => entry.email === email.value.trim().toLowerCase() && entry.demoPasswordHash === passwordHash);
  if (!user) { setMessage(''); showAuthFeedback('Não foi possível entrar','Conta não encontrada ou senha incorreta.','error'); return; }
  sessionStorage.setItem('aura67_session', JSON.stringify({ name: user.name, email: user.email }));
  setMessage('');
  showAuthFeedback('Login confirmado','Bem-vindo de volta. Sua jornada está pronta.');
  setTimeout(() => window.location.replace(postLoginDestination()), 1100);
});

document.querySelector('#forgotLink')?.addEventListener('click', async (event) => {
  event.preventDefault();
  if (!supabaseClient) { setMessage('Configure o Supabase para ativar a recuperação por e-mail.'); return; }
  const email = document.querySelector('#loginEmail');
  if (!email.validity.valid) { fieldError(email, 'Informe seu e-mail primeiro.'); return; }
  if (!await confirmPasswordReset(email.value.trim().toLowerCase())) return;
  setMessage('Enviando link de recuperação…', true);
  const { error } = await supabaseClient.auth.resetPasswordForEmail(email.value.trim().toLowerCase(), { redirectTo: redirectUrl('redefinir-senha.html') });
  setMessage('');
  showAuthFeedback(error?'Não foi possível enviar':'E-mail enviado',error?error.message:'Confira sua caixa de entrada e também a pasta de spam.',error?'error':'success');
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
