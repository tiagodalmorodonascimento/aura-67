# Aura 67

Template inicial de dashboard responsivo, criado com HTML, CSS e JavaScript puros.

## Como abrir

Abra o arquivo `index.html` em qualquer navegador moderno. Não é necessário instalar dependências.

## Estrutura

- `index.html` — estrutura e conteúdo da interface.
- `styles.css` — aparência, cores, layout e responsividade.
- `script.js` — menu móvel, navegação, busca, modal e avisos.

## Ranking

O menu **Ranking** abre uma classificação gamificada com pódio, pontuação semanal e mensal, posição do usuário, sequências de atividade e sugestões para ganhar pontos. Os dados de demonstração usam os atributos `data-week` e `data-month` no `index.html`.

## Estrutura mobile-first

- `index.html` — landing page pública e lista de espera.
- `cadastro.html` — criação de conta em modo de demonstração.
- `login.html` — entrada em modo de demonstração.
- `app.html` — dashboard e ranking preservados como área interna.
- `manifest.json` e `service-worker.js` — instalação básica como PWA.
- `css/` e `js/` — estilos e comportamentos das novas páginas.

As contas atuais ficam apenas no navegador para validar a jornada. Antes de produção, a autenticação deverá ser substituída pelo Supabase Auth; nenhuma credencial local deve ser tratada como conta real.

## Supabase e ambientes

A camada de autenticação detecta automaticamente o ambiente em `config/environments.js`. Quando uma URL e uma chave pública válidas forem configuradas, cadastro, confirmação de e-mail, login, Google OAuth e recuperação passam a usar o Supabase. Sem configuração, o fluxo local continua disponível apenas para demonstração.

Veja `ENVIRONMENTS.md` para configurar teste, produção, domínio e o primeiro esquema do banco.

## Perfis e design

Depois do esquema inicial, execute `supabase/migration-002-public-profiles.sql` no ambiente de teste. Essa migration adiciona perfil público pesquisável, pontuação, cores, avatar, capa e o bucket de imagens. E-mails permanecem exclusivamente no Auth e nunca são exibidos na busca pública.

## Hábitos e missões

Execute `supabase/migration-004-habits-missions.sql` depois da migration 003. Ela instala 56 ações em sete categorias, conclusões diárias, XP processado no banco, bônus de combo e sequência. A tela fica disponível em **Atividade / Jornada**. O navegador nunca escolhe nem altera diretamente a quantidade de XP.

## Comprovação de ações

Execute `supabase/migration-005-photo-proof.sql` depois da migration 004. Ela adiciona modos de comprovação, bucket privado para fotos, XP pendente e funções de envio e revisão. Fotos exigidas não concedem XP até aprovação. Nunca exiba o bucket `action-proofs` publicamente.

## Super Admin

Execute `supabase/migration-006-super-admin.sql` depois da migration 005. A área separada fica em `admin.html` e valida o papel no banco. Para promover a primeira conta, use o comando comentado no final da migration trocando `SEU_EMAIL_AQUI`. Usuários comuns recebem acesso negado mesmo conhecendo a URL.

## Padrão de tipografia

Nenhum texto legível da interface deve usar menos de `8px`. Textos recorrentes devem preferir `9px` a `12px`, e títulos devem manter hierarquia superior. Ícones e elementos gráficos não seguem esse limite quando não representam texto.

## Personalização rápida

As principais cores ficam no início de `styles.css`, dentro de `:root`. Edite os textos e módulos diretamente no `index.html`. Use `script.js` para conectar os botões às funcionalidades futuras.
