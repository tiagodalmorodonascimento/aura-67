import { createClient } from 'npm:@supabase/supabase-js@2'

const cors={
  'Access-Control-Allow-Origin':'*',
  'Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type',
}
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,'Content-Type':'application/json'}})
const base64url=(value:Uint8Array|string)=>{
  const bytes=typeof value==='string'?new TextEncoder().encode(value):value
  let binary='';for(const byte of bytes)binary+=String.fromCharCode(byte)
  return btoa(binary).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'')
}
const pemBytes=(pem:string)=>Uint8Array.from(atob(pem.replace(/-----[^-]+-----|\s/g,'')),c=>c.charCodeAt(0))

async function firebaseAccessToken(serviceAccount:{client_email:string;private_key:string}){
  const now=Math.floor(Date.now()/1000),header=base64url(JSON.stringify({alg:'RS256',typ:'JWT'})),claims=base64url(JSON.stringify({iss:serviceAccount.client_email,scope:'https://www.googleapis.com/auth/firebase.messaging',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+3600}))
  const key=await crypto.subtle.importKey('pkcs8',pemBytes(serviceAccount.private_key),{name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['sign'])
  const signature=await crypto.subtle.sign('RSASSA-PKCS1-v1_5',key,new TextEncoder().encode(`${header}.${claims}`))
  const assertion=`${header}.${claims}.${base64url(new Uint8Array(signature))}`
  const response=await fetch('https://oauth2.googleapis.com/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion})})
  const payload=await response.json();if(!response.ok)throw new Error(payload.error_description||'Falha na autenticação do Firebase')
  return payload.access_token as string
}

Deno.serve(async(req)=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers:cors})
  if(req.method!=='POST')return json({error:'Método não permitido'},405)
  try{
    const url=Deno.env.get('SUPABASE_URL')!,anon=Deno.env.get('SUPABASE_ANON_KEY')!,service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,authorization=req.headers.get('Authorization')||''
    const userClient=createClient(url,anon,{global:{headers:{Authorization:authorization}}}),admin=createClient(url,service)
    const{data:{user},error:userError}=await userClient.auth.getUser();if(userError||!user)return json({error:'Sessão inválida'},401)
    const{messageId}=await req.json();if(!Number.isInteger(Number(messageId)))return json({error:'Mensagem inválida'},400)
    const{data:message,error:messageError}=await admin.from('direct_messages').select('id,conversation_id,sender_id,content,deleted_at').eq('id',Number(messageId)).maybeSingle()
    if(messageError||!message||message.sender_id!==user.id||message.deleted_at)return json({error:'Mensagem não encontrada'},404)
    const{data:conversation}=await admin.from('direct_conversations').select('user_a,user_b').eq('id',message.conversation_id).single()
    if(!conversation)return json({error:'Conversa não encontrada'},404)
    const recipient=conversation.user_a===user.id?conversation.user_b:conversation.user_a
    const[{data:sender},{data:tokens}]=await Promise.all([
      admin.from('profiles').select('full_name').eq('id',user.id).single(),
      admin.from('mobile_push_tokens').select('id,token').eq('user_id',recipient).eq('active',true),
    ])
    if(!tokens?.length)return json({sent:0})
    const serviceAccount=JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT')||'{}')
    if(!serviceAccount.project_id||!serviceAccount.private_key)throw new Error('FIREBASE_SERVICE_ACCOUNT não configurado')
    const accessToken=await firebaseAccessToken(serviceAccount),title=sender?.full_name||'Nova mensagem',body=message.content.startsWith('Arquivo:')?'Enviou um arquivo':message.content.slice(0,140)
    let sent=0
    for(const device of tokens){
      const response=await fetch(`https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,{method:'POST',headers:{Authorization:`Bearer ${accessToken}`,'Content-Type':'application/json'},body:JSON.stringify({message:{token:device.token,notification:{title,body},data:{type:'direct_message',conversationId:message.conversation_id,senderId:user.id},android:{priority:'high',notification:{channel_id:'aura-messages',tag:`conversation-${message.conversation_id}`,sound:'default'}}}})})
      const provider=await response.text(),status=response.ok?'sent':'failed';if(response.ok)sent++
      await admin.from('message_push_deliveries').upsert({message_id:message.id,token_id:device.id,status,provider_response:provider.slice(0,1000)},{onConflict:'message_id,token_id'})
      if(!response.ok&&/UNREGISTERED|registration-token-not-registered/i.test(provider))await admin.from('mobile_push_tokens').update({active:false,updated_at:new Date().toISOString()}).eq('id',device.id)
    }
    return json({sent})
  }catch(error){return json({error:error instanceof Error?error.message:'Erro ao enviar notificação'},500)}
})
