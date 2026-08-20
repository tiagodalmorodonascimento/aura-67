let auraPeople=[];
let peopleMode='all';

const peopleEscape=(value='')=>{const node=document.createElement('span');node.textContent=value;return node.innerHTML};
const peopleInitials=(name='Pessoa Aura')=>name.split(/\s+/).slice(0,2).map(part=>part[0]).join('').toUpperCase();

function peopleAvatar(profile){
  const url=profile.avatar_url&&typeof mediaUrl==='function'?mediaUrl(profile.avatar_url):'';
  return url?`<img src="${peopleEscape(url)}" alt="" loading="lazy" decoding="async">`:peopleEscape(peopleInitials(profile.full_name));
}

function renderPeople(term=''){
  const normalized=term.trim().toLocaleLowerCase('pt-BR');
  const rows=auraPeople.filter(person=>!normalized||person.full_name?.toLocaleLowerCase('pt-BR').includes(normalized)||person.username?.toLocaleLowerCase('pt-BR').includes(normalized)||person.bio?.toLocaleLowerCase('pt-BR').includes(normalized));
  document.querySelector('#peopleCount').textContent=auraPeople.length.toLocaleString('pt-BR');
  document.querySelector('#peopleGrid').innerHTML=rows.length?rows.map(person=>{
    const color=/^#[0-9a-f]{6}$/i.test(person.theme_color||'')?person.theme_color:'#7657ec';
    const level=typeof classFor==='function'?classFor(person.aura_points||0):{name:'Centelha',icon:'✦'};
    const own=person.id===window.AURA_SESSION.user.id;
    return `<article class="person-card" data-person-id="${person.id}" style="--person-color:${color}" tabindex="0" role="button" aria-label="Abrir perfil de ${peopleEscape(person.full_name)}"><div class="person-cover"><span class="person-avatar">${peopleAvatar(person)}</span></div><div class="person-body"><div class="person-name"><strong>${peopleEscape(person.full_name)}</strong>${own?'<b>VOCÊ</b>':''}</div><small>@${peopleEscape(person.username||'perfil-aura')}</small><p>${peopleEscape(person.bio||'Construindo sua evolução na Aura.')}</p><div class="person-meta"><span><b>${level.icon} ${level.name}</b>Classe atual</span><span><b>Nível ${typeof auraLevelFor==='function'?auraLevelFor(person.aura_points||0):1}</b>de 67</span><span><b>${Number(person.aura_points||0).toLocaleString('pt-BR')}</b>pontos</span></div>${own?'':`<button class="person-message" data-message-person="${person.id}" type="button">Conversar <span>→</span></button>`}</div></article>`;
  }).join(''):`<div class="people-empty">${peopleMode==='following'?'Você ainda não segue ninguém. Use a busca para encontrar pessoas e construir seu círculo.':'Nenhum perfil encontrado com essa busca.'}</div>`;
}

function renderPeopleMode(){
  const following=peopleMode==='following';
  document.querySelector('#peopleKicker').textContent=following?'SEU CÍRCULO':'COMUNIDADE AURA';
  document.querySelector('#peopleTitle').innerHTML=following?'Pessoas que você segue.<br><em>Trajetórias escolhidas.</em>':'Encontre pessoas.<br><em>Conheça trajetórias.</em>';
  document.querySelector('#peopleDescription').textContent=following?'Acompanhe quem inspira sua jornada, abra perfis ou continue uma conversa.':'Descubra identidades, celebre evoluções e encontre inspiração sem transformar cada relação em competição.';
  document.querySelector('#peopleCountLabel').textContent=following?'pessoas seguidas':'perfis encontrados';
}

async function loadAuraPeople(){
  if(!window.AURA_SESSION)return;
  renderPeopleMode();
  const grid=document.querySelector('#peopleGrid');
  grid.innerHTML=`<div class="people-empty">${peopleMode==='following'?'Carregando as pessoas que você segue…':'Encontrando pessoas da comunidade…'}</div>`;
  const result=peopleMode==='following'
    ?await window.auraSupabase.rpc('get_my_following')
    :await window.auraSupabase.from('profiles').select('id,full_name,username,bio,avatar_url,cover_url,theme_color,aura_points,member_number').order('created_at',{ascending:false}).limit(60);
  const{data,error}=result;
  if(error){grid.innerHTML=`<div class="people-empty">${peopleMode==='following'?'Execute a migration 040 no Supabase para visualizar quem você segue.':'Não foi possível carregar a comunidade agora.'}</div>`;return}
  auraPeople=(data||[]).filter(person=>peopleMode!=='following'||person.id!==window.AURA_SESSION.user.id);
  renderPeople(document.querySelector('#peopleSearch').value);
}

document.querySelector('#peopleSearch').addEventListener('input',event=>renderPeople(event.target.value));
document.querySelector('#peopleRefresh').addEventListener('click',loadAuraPeople);
document.querySelector('#followingNav').addEventListener('click',()=>{peopleMode='following';document.querySelector('#peopleSearch').value='';loadAuraPeople()});
document.querySelector('#peopleGrid').addEventListener('click',event=>{
  const card=event.target.closest('[data-person-id]');if(!card)return;
  const person=auraPeople.find(item=>item.id===card.dataset.personId);if(!person)return;
  if(event.target.closest('[data-message-person]')&&typeof openDirectChat==='function'){openDirectChat(person);return}
  if(typeof openPublicProfile==='function')openPublicProfile(person);
});
document.querySelector('#peopleGrid').addEventListener('keydown',event=>{if(!['Enter',' '].includes(event.key))return;event.preventDefault();event.target.closest('[data-person-id]')?.click()});
document.addEventListener('aura:session-ready',loadAuraPeople);
document.addEventListener('aura:follow-changed',()=>{if(peopleMode==='following')loadAuraPeople()});
if(window.AURA_SESSION)loadAuraPeople();
