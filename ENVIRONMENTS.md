# Ambientes da Aura 67

## Organização

- `test`: desenvolvimento local, validação e homologação.
- `production`: usuários reais e dados reais.
- `backups/`: cópias históricas do código antes de mudanças relevantes. Backups não substituem Git.

Use dois projetos Supabase independentes. Nunca teste migrations ou regras diretamente na produção.

## Configuração

Edite `config/environments.js` e preencha somente:

- Project URL do Supabase.
- Publishable key (`sb_publishable_...`) ou chave pública equivalente.
- URL pública do site.

Nunca coloque `service_role`, secret key ou senha do banco no frontend.

## Primeiro banco

1. Abra o projeto Supabase de teste.
2. Acesse o SQL Editor.
3. Execute `supabase/schema.sql`.
4. Em Authentication > URL Configuration, configure a URL de teste.
5. Teste cadastro, confirmação, login e recuperação.
6. Somente depois repita a migration no projeto de produção.

## Domínio

O aplicativo mobile pode ser distribuído sem que sua interface rode no domínio, mas o domínio é recomendado para a landing page, política de privacidade, suporte, confirmação de e-mail, recuperação de senha e links que abrem o aplicativo. Em produção, use HTTPS e URLs exatas nos redirecionamentos do Supabase.
