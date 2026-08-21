(function setupNativePush(){
  const isNative=()=>Boolean(window.Capacitor?.isNativePlatform?.());
  const plugin=()=>window.Capacitor?.Plugins?.PushNotifications;
  let started=false,pendingConversation=localStorage.getItem('aura67_pending_push_conversation')||'';

  async function openConversation(conversationId){
    if(!conversationId)return;
    if(!window.AURA_SESSION||typeof window.openDirectConversationById!=='function'){
      pendingConversation=conversationId;
      localStorage.setItem('aura67_pending_push_conversation',conversationId);
      return;
    }
    pendingConversation='';localStorage.removeItem('aura67_pending_push_conversation');
    await window.openDirectConversationById(conversationId);
  }

  async function registerToken(token){
    if(!window.AURA_SESSION||!token)return;
    const{error}=await window.auraSupabase.rpc('register_mobile_push_token',{p_token:token,p_platform:'android',p_device_info:navigator.userAgent});
    if(error&&!/register_mobile_push_token|schema cache/i.test(error.message))console.warn('Token push não registrado.',error);
  }

  async function start(){
    if(started||!isNative()||!plugin())return;started=true;
    const api=plugin();
    await api.addListener('registration',event=>registerToken(event.value));
    await api.addListener('registrationError',event=>console.warn('Falha ao registrar push.',event));
    await api.addListener('pushNotificationReceived',()=>{if(typeof refreshChatUnread==='function')refreshChatUnread()});
    await api.addListener('pushNotificationActionPerformed',event=>openConversation(event.notification?.data?.conversationId||event.notification?.data?.conversation_id));
    await api.createChannel?.({id:'aura-messages',name:'Mensagens',description:'Novas mensagens recebidas na Aura',importance:4,visibility:1,vibration:true,sound:'default'});
    let permission=await api.checkPermissions();if(permission.receive==='prompt')permission=await api.requestPermissions();
    if(permission.receive==='granted')await api.register();
    if(pendingConversation)await openConversation(pendingConversation);
  }

  document.addEventListener('aura:session-ready',()=>start().catch(error=>console.warn('Push nativo indisponível.',error)));
  document.addEventListener('aura:chat-ready',()=>{if(pendingConversation)openConversation(pendingConversation)});
  if(window.AURA_SESSION)start().catch(error=>console.warn('Push nativo indisponível.',error));
  window.AuraNativePush={start,openConversation};
})();
