let auraActions = [];
let completedActionIds = new Set();
let activeHabitCategory = 'all';
let pendingOnly = false;
let pendingProofIds = new Set();
let proofAction = null;
const categoryNames = { all:'Todas as ações', health:'Saúde', mental:'Mental', home:'Casa e organização', finance:'Vida financeira', productivity:'Produtividade', social:'Social', special:'Missões especiais' };
const difficultyNames = { easy:'Fácil', medium:'Média', hard:'Difícil', special:'Especial' };

function todaySaoPaulo() {
  return new Intl.DateTimeFormat('en-CA', { timeZone:'America/Sao_Paulo', year:'numeric', month:'2-digit', day:'2-digit' }).format(new Date());
}

function escapeHabitText(value='') { const element=document.createElement('span'); element.textContent=value; return element.innerHTML; }

function filteredActions() {
  const term=document.querySelector('#habitSearch').value.trim().toLocaleLowerCase('pt-BR');
  return auraActions.filter((action) => (activeHabitCategory==='all'||action.category===activeHabitCategory) && (!term||`${action.title} ${action.description}`.toLocaleLowerCase('pt-BR').includes(term)) && (!pendingOnly||!completedActionIds.has(action.id)));
}

function renderHabits() {
  const actions=filteredActions();
  document.querySelector('#habitsHeading').textContent=categoryNames[activeHabitCategory];
  document.querySelector('#habitsCount').textContent=`${actions.length} ${actions.length===1?'ação disponível':'ações disponíveis'}`;
  document.querySelector('#habitsGrid').innerHTML=actions.length?actions.map((action)=>{const pending=pendingProofIds.has(action.id);const done=completedActionIds.has(action.id);return `<article class="habit-card ${done?'completed':''} ${pending?'pending-proof':''}" data-action-id="${action.id}"><span class="habit-icon">${escapeHabitText(action.icon)}</span><span class="habit-copy"><strong>${escapeHabitText(action.title)}</strong><small>${escapeHabitText(action.description||'')}</small><span class="habit-meta"><span>${difficultyNames[action.difficulty]}</span><b>+${action.xp} XP</b>${action.proof_mode==='photo_required'?'<span class="proof-badge">📷 Foto</span>':action.proof_mode==='photo_optional'?'<span class="proof-badge">📷 Opcional</span>':''}</span></span><button class="complete-habit" type="button" ${(done||pending)?'disabled':''}>${done?'✓':pending?'⌛':action.proof_mode==='photo_required'?'📷':'＋'}</button></article>`}).join(''):'<div class="habits-loading">Nenhuma ação encontrada neste filtro.</div>';
  document.querySelectorAll('.complete-habit:not(:disabled)').forEach((button)=>button.addEventListener('click',()=>completeHabit(Number(button.closest('.habit-card').dataset.actionId))));
}

function updateTodaySummary(completions) {
  const count=completions.length;
  const xp=completions.reduce((sum,item)=>sum+item.base_xp+item.bonus_xp,0);
  document.querySelector('#todayCompleted').textContent=count;
  document.querySelector('#todayXp').textContent=xp;
  document.querySelector('#comboCount').textContent=`${count%3}/3`;
  document.querySelector('#dailyProgress').style.width=`${Math.min(100,(count/5)*100)}%`;
}

async function loadHabits() {
  if (!window.auraSupabase||!window.AURA_SESSION) return;
  const [{data:catalog,error:catalogError},{data:completions,error:completionError},{data:proofs,error:proofError}]=await Promise.all([
    window.auraSupabase.from('actions_catalog').select('id,slug,category,title,description,icon,xp,difficulty,proof_mode').eq('active',true).order('category').order('xp'),
    window.auraSupabase.from('action_completions').select('action_id,base_xp,bonus_xp').eq('completed_on',todaySaoPaulo()),
    window.auraSupabase.from('action_proofs').select('action_id,status').eq('submitted_on',todaySaoPaulo())
  ]);
  if (catalogError) { document.querySelector('#habitsGrid').innerHTML='<div class="habits-loading">O catálogo ainda precisa ser ativado no Supabase pela migration 004.</div>'; return; }
  if (completionError) console.error(completionError);
  if (proofError) console.error(proofError);
  auraActions=catalog||[];
  completedActionIds=new Set((completions||[]).map((item)=>item.action_id));
  pendingProofIds=new Set((proofs||[]).filter((item)=>item.status==='pending').map((item)=>item.action_id));
  updateTodaySummary(completions||[]);
  renderHabits();
}

function showXp(result) {
  const pop=document.createElement('div'); pop.className='xp-pop';
  pop.innerHTML=`<strong>+${result.earned_xp+result.bonus_xp} XP</strong><small>${result.bonus_xp?`Combo de 3! +${result.bonus_xp} bônus`:'Sua Aura ficou mais forte'}</small>`;
  document.body.appendChild(pop); setTimeout(()=>pop.remove(),1900);
}

async function completeHabit(actionId) {
  const selectedAction=auraActions.find((action)=>action.id===actionId);
  if(selectedAction?.proof_mode==='photo_required'){openProofModal(selectedAction);return;}
  const card=document.querySelector(`[data-action-id="${actionId}"]`); const button=card?.querySelector('button'); if(button)button.disabled=true;
  const {data,error}=await window.auraSupabase.rpc('complete_aura_action',{p_action_id:actionId});
  if (error) { if(button)button.disabled=false; showToast(error.message.includes('já concluiu')?'Esta ação já foi concluída hoje.':'Não foi possível concluir a ação.','error'); return; }
  completedActionIds.add(actionId); showXp(data);
  document.querySelector('#todayCompleted').textContent=data.today_count;
  document.querySelector('#comboCount').textContent=`${data.today_count%3}/3`;
  document.querySelector('#habitStreak').textContent=data.streak;
  document.querySelector('#dailyProgress').style.width=`${Math.min(100,(data.today_count/5)*100)}%`;
  const currentXp=Number(document.querySelector('#todayXp').textContent)||0; document.querySelector('#todayXp').textContent=currentXp+data.earned_xp+data.bonus_xp;
  renderHabits();
  if (typeof loadProfile==='function') await loadProfile(window.AURA_SESSION);
}

function openProofModal(action){proofAction=action;document.querySelector('#proofTitle').textContent=action.title;document.querySelector('#proofDescription').textContent=`Envie uma foto clara que ajude a comprovar: ${action.description}`;document.querySelector('#proofFile').value='';document.querySelector('#proofNote').value='';document.querySelector('#proofPreview').hidden=true;document.querySelector('#proofPlaceholder').hidden=false;document.querySelector('#proofMessage').textContent='';document.querySelector('#proofBackdrop').hidden=false;document.body.style.overflow='hidden';}
function closeProofModal(){document.querySelector('#proofBackdrop').hidden=true;document.body.style.overflow='';proofAction=null;}
document.querySelector('#proofClose').addEventListener('click',closeProofModal);
document.querySelector('#proofBackdrop').addEventListener('click',(event)=>{if(event.target.id==='proofBackdrop')closeProofModal();});
document.querySelector('#proofFile').addEventListener('change',(event)=>{const file=event.target.files[0];if(!file)return;if(file.size>8*1024*1024){document.querySelector('#proofMessage').textContent='A imagem deve ter no máximo 8 MB.';event.target.value='';return;}document.querySelector('#proofPreview').src=URL.createObjectURL(file);document.querySelector('#proofPreview').hidden=false;document.querySelector('#proofPlaceholder').hidden=true;});
document.querySelector('#proofSubmit').addEventListener('click',async()=>{const file=document.querySelector('#proofFile').files[0];const message=document.querySelector('#proofMessage');if(!file||!proofAction){message.textContent='Tire ou escolha uma foto para continuar.';return;}const button=document.querySelector('#proofSubmit');button.disabled=true;message.classList.remove('success');message.textContent='Enviando sua comprovação com segurança…';try{const extension=file.name.split('.').pop().toLowerCase();const path=`${window.AURA_SESSION.user.id}/${todaySaoPaulo()}/${proofAction.id}-${Date.now()}.${extension}`;const{error:uploadError}=await window.auraSupabase.storage.from('action-proofs').upload(path,file);if(uploadError)throw uploadError;const{data,error}=await window.auraSupabase.rpc('submit_action_proof',{p_action_id:proofAction.id,p_evidence_path:path,p_note:document.querySelector('#proofNote').value.trim()});if(error)throw error;pendingProofIds.add(proofAction.id);message.classList.add('success');message.textContent=`Comprovação enviada. ${data.pending_xp} XP aguardando validação.`;showToast(message.textContent,'success','Comprovação recebida');renderHabits();setTimeout(closeProofModal,1300);}catch(error){message.textContent=error.message;showToast(error.message,'error');}finally{button.disabled=false;}});

document.querySelectorAll('#categoryTabs button').forEach((button)=>button.addEventListener('click',()=>{ document.querySelectorAll('#categoryTabs button').forEach((item)=>item.classList.toggle('active',item===button)); activeHabitCategory=button.dataset.category; renderHabits(); }));
document.querySelector('#habitSearch').addEventListener('input',renderHabits);
document.querySelector('#onlyPendingButton').addEventListener('click',(event)=>{pendingOnly=!pendingOnly;event.currentTarget.classList.toggle('active',pendingOnly);event.currentTarget.textContent=pendingOnly?'Mostrando pendentes':'Mostrar pendentes';renderHabits();});
document.querySelector('#surpriseButton').addEventListener('click',()=>{const candidates=auraActions.filter((action)=>action.category!=='special'&&!completedActionIds.has(action.id));if(!candidates.length)return;const selected=candidates[Math.floor(Math.random()*candidates.length)];document.querySelector('#surpriseTitle').textContent=`${selected.icon} ${selected.title} · +${selected.xp} XP`;activeHabitCategory='all';document.querySelector('#habitSearch').value=selected.title;document.querySelectorAll('#categoryTabs button').forEach((item)=>item.classList.toggle('active',item.dataset.category==='all'));renderHabits();});
document.addEventListener('aura:session-ready',loadHabits); if(window.AURA_SESSION)loadHabits();
