# Ativação do push de mensagens

O código do aplicativo, a migration e a Edge Function já estão preparados. Para ativar o envio real no Android:

1. No Firebase Console, crie/abra o projeto da Aura e adicione um aplicativo Android com o pacote `com.aura67.app`.
2. Baixe `google-services.json` e coloque em `android/app/google-services.json`. Esse arquivo é local e não deve ser enviado ao GitHub.
3. Execute `migration-041-message-push-notifications.sql` no SQL Editor do Supabase.
4. No Firebase, gere uma chave JSON em **Configurações do projeto → Contas de serviço**.
5. No Supabase, salve o JSON completo como segredo da Edge Function chamado `FIREBASE_SERVICE_ACCOUNT`.
6. Publique a função com `supabase functions deploy message-push` ou pelo painel do Supabase.
7. Gere um novo APK e conceda a permissão de notificações no primeiro acesso.

O arquivo da conta de serviço nunca deve ser incluído no aplicativo ou no repositório.
