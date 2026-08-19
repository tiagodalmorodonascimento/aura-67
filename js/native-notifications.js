(function setupAuraNativeNotifications(){
  const isNative=()=>Boolean(window.Capacitor?.isNativePlatform?.());
  const plugin=()=>window.Capacitor?.Plugins?.LocalNotifications;
  const actions=[
    'Beba um copo de água e perceba como seu corpo responde.',
    'Alongue braços, costas e pescoço por dois minutos.',
    'Respire fundo cinco vezes, soltando o ar devagar.',
    'Olhe para algo distante por trinta segundos.',
    'Escolha uma tarefa pequena e faça apenas o primeiro passo.',
    'Caminhe um pouco e retorne com mais presença.'
  ];
  async function permission(request=false){const api=plugin();if(!api)return false;let result=await api.checkPermissions();if(result.display==='prompt'&&request)result=await api.requestPermissions();return result.display==='granted'}
  async function ensureChannel(){const api=plugin();if(!api?.createChannel)return;await api.createChannel({id:'aura-companion',name:'Companheiro Aura',description:'Pequenas ações e lembretes da sua jornada',importance:4,visibility:1,vibration:true})}
  async function status(){if(!isNative()||!plugin())return null;const granted=await permission(false);return granted?'Notificações nativas ativas neste aparelho.':'Toque em Ativar para permitir no Android.'}
  async function test(){if(!isNative()||!plugin())return false;if(!await permission(true))throw new Error('A permissão de notificações não foi concedida.');await ensureChannel();await plugin().schedule({notifications:[{id:67999,title:'Uma pequena ação para agora ✦',body:actions[Math.floor(Math.random()*actions.length)],schedule:{at:new Date(Date.now()+1200)},channelId:'aura-companion',extra:{url:'app.html#habits'}}]});return true}
  function minutes(value){const[hour,minute]=String(value).split(':').map(Number);return hour*60+minute}
  async function scheduleFromForm(){if(!isNative()||!plugin())return;const enabled=document.querySelector('#reminderEnabled')?.checked;if(!enabled){const pending=await plugin().getPending();const notifications=pending.notifications.filter(item=>item.id>=67000&&item.id<67999);if(notifications.length)await plugin().cancel({notifications});return}if(!await permission(false))return;await ensureChannel();const start=minutes(document.querySelector('#reminderWake').value),end=minutes(document.querySelector('#reminderSleep').value),count=Number(document.querySelector('#reminderFrequency').value),days=[...document.querySelectorAll('[name="reminderWeekday"]:checked')].map(item=>Number(item.value));const existing=await plugin().getPending(),old=existing.notifications.filter(item=>item.id>=67000&&item.id<67999);if(old.length)await plugin().cancel({notifications:old});const notifications=[];days.forEach(day=>{for(let slot=0;slot<count;slot++){const point=Math.round(start+((end-start+1440)%1440)*(slot+1)/(count+1))%1440;notifications.push({id:67000+day*20+slot,title:'Companheiro Aura ✦',body:actions[(day+slot)%actions.length],schedule:{on:{weekday:day%7+1,hour:Math.floor(point/60),minute:point%60},repeats:true,allowWhileIdle:true},channelId:'aura-companion',extra:{url:'app.html#habits'}})}});if(notifications.length)await plugin().schedule({notifications})}
  window.AuraNativeNotifications={isAvailable:()=>isNative()&&Boolean(plugin()),status,test,scheduleFromForm};
  document.addEventListener('DOMContentLoaded',()=>document.querySelector('#reminderForm')?.addEventListener('submit',()=>setTimeout(()=>scheduleFromForm().catch(()=>{}),0)));
})();
