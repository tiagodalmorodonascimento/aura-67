# Aura 67

Aplicação web responsiva de evolução pessoal e social. A experiência combina atividades, projetos privados, planos comportamentais, temporadas mensais, perfis, Momentos e conversas privadas.

## Execução

O frontend usa HTML, CSS e JavaScript nativos e deve ser servido por HTTP. Abrir os arquivos diretamente não reproduz corretamente autenticação, service worker e redirecionamentos.

- `index.html`: página pública do domínio.
- `login.html` e `cadastro.html`: autenticação Supabase.
- `app.html`: aplicação autenticada.
- `admin.html`: moderação, protegida por função e papel no banco.
- `service-worker.js` e `manifest.json`: instalação como PWA.
- `supabase/`: esquema inicial e migrations incrementais.

## Banco de dados

O projeto usa Supabase Auth, Postgres, Storage e RPCs. Execute `supabase/schema.sql` em uma instalação nova e depois as migrations numeradas, em ordem. Em uma instalação já existente, execute somente as migrations ainda não aplicadas.

A migration mais recente é `migration-029-integrity-guards.sql`. Ela remove pontos por mera criação de projeto, impede repetição diária do mínimo comportamental, adiciona limites antispam e otimiza consultas frequentes.

As tabelas privadas têm RLS e/ou acesso direto revogado; operações sensíveis passam por funções no banco. Buckets de comprovação e anexos de conversa são privados. Nunca publique a chave `service_role` no frontend.

## Ambientes e publicação

As chaves públicas e URLs são selecionadas em `config/environments.js`. O domínio atual na Vercel usa o ambiente de teste compartilhado. Antes da produção comercial, configure um projeto Supabase de produção separado e preencha os valores de produção sem substituir o ambiente de teste.

O repositório é publicado pela Vercel após o push para a branch principal. O app permanece instalável como PWA; o empacotamento APK deve ser feito somente depois da validação funcional e da configuração definitiva do domínio.

## Validação antes de publicar

1. Verifique a sintaxe dos arquivos JavaScript com `node --check`.
2. Execute a migration nova no Supabase SQL Editor e confirme que não há erro.
3. Teste cadastro, confirmação de e-mail, login, recuperação de senha e logout.
4. Teste pontuação, projetos, atividades, ranking, chat, anexos, bloqueio e denúncias com pelo menos duas contas.
5. Confirme os fluxos mobile, tema claro/escuro, modo offline e permissões de notificações.

Credenciais administrativas não devem ser registradas neste arquivo nem versionadas no Git.
