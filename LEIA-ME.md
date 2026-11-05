# Quadro de tarefas do RH: como colocar no ar

O sistema tem três partes:

- **Supabase**: guarda as tarefas e os logins, e bloqueia cada pessoa nas empresas liberadas para ela. Plano gratuito.
- **GitHub**: guarda os arquivos do site.
- **Vercel**: publica o site e roda a tela de Usuários e acessos. Plano gratuito.

A pasta `C:\PROJETO-TAREFAS\dados` continua recebendo uma cópia de tudo a cada alteração, no seu computador.

## Arquivos

| Arquivo | Para que serve |
| --- | --- |
| `index.html` | O quadro de tarefas |
| `config.js` | Endereço do Supabase e do site (você preenche) |
| `api/admin.js` | Cria acessos, reseta senhas e muda empresas (só o administrador) |
| `package.json` | Diz ao Vercel qual biblioteca instalar |
| `supabase/1-estrutura.sql` | Cria as tabelas e as regras de acesso |
| `supabase/2-administrador.sql` | Torna o rh@useebrasil.com.br administrador |
| `.gitignore` | Impede que a pasta `dados` vá para o GitHub |

## Passo 1. Supabase

1. Crie uma conta em supabase.com e clique em **New project**. Dê um nome (por exemplo `tarefas-rh`), crie uma senha de banco (guarde-a) e escolha a região **South America (São Paulo)**.
2. Abra **SQL Editor**, clique em **New query**, cole todo o conteúdo de `supabase/1-estrutura.sql` e clique em **Run**.
3. Abra **Authentication > Users > Add user > Create new user**. Informe `rh@useebrasil.com.br`, a senha do administrador e marque **Auto Confirm User**.
4. Volte ao **SQL Editor**, cole o conteúdo de `supabase/2-administrador.sql` e clique em **Run**. Deve aparecer uma linha com `is_admin = true`.
5. Abra **Authentication > Sign In / Providers** e desligue **Allow new users to sign up**. Assim, só entra quem você liberar.
6. Abra **Project Settings > API Keys** (ou **Data API**) e anote três coisas:
   - a **URL** do projeto (`https://xxxx.supabase.co`);
   - a chave pública (**anon public** ou **publishable**);
   - a chave secreta (**service_role** ou **secret**). Essa é a chave mestra: nunca coloque no `config.js` nem no GitHub.

## Passo 2. Preencher o config.js

Abra `config.js` no Bloco de Notas e troque:

- `supabaseUrl` pela URL do projeto;
- `supabaseAnonKey` pela chave pública;
- `siteUrl` você preenche no passo 4, quando tiver o endereço do Vercel.

## Passo 3. GitHub

1. Crie uma conta em github.com e clique em **New repository**. Nome `tarefas-rh`, marque **Private** e clique em **Create repository**.
2. Na página do repositório, clique em **uploading an existing file**.
3. Arraste `index.html`, `config.js`, `package.json`, `.gitignore` e as pastas `api` e `supabase`. **Não envie a pasta `dados`.**
4. Clique em **Commit changes**.

Dica: no Windows, arquivos que começam com ponto (`.gitignore`) às vezes ficam ocultos. Ative **Exibir > Itens ocultos** no Explorador de Arquivos.

## Passo 4. Vercel

1. Crie uma conta em vercel.com entrando com o GitHub.
2. Clique em **Add New > Project**, escolha o repositório `tarefas-rh` e clique em **Import**.
3. Em **Framework Preset**, deixe **Other**.
4. Abra **Environment Variables** e cadastre:
   - `SUPABASE_URL` = a URL do projeto;
   - `SUPABASE_SERVICE_ROLE_KEY` = a chave secreta.
5. Clique em **Deploy**. Ao terminar, o Vercel mostra o endereço (por exemplo `https://tarefas-rh.vercel.app`).
6. Volte ao `config.js` no GitHub (abra o arquivo e clique no lápis), coloque esse endereço em `siteUrl` e salve com **Commit changes**. O Vercel publica de novo sozinho em cerca de 1 minuto.

## Passo 5. Primeiro acesso e migração

1. Abra o endereço do Vercel no Chrome e entre com `rh@useebrasil.com.br`.
2. Clique em **Importar backup** e escolha `C:\PROJETO-TAREFAS\dados\tarefas-rh-dados.json`. Suas tarefas atuais entram no sistema.
3. Clique em **Escolher pasta dados** e selecione `C:\PROJETO-TAREFAS\dados`. A partir daí, cada alteração (sua ou de outra pessoa) também é gravada lá.
4. Troque a senha inicial em **seu nome > Trocar minha senha**.

## Liberar acesso para alguém

1. Clique em **Usuários e acessos**.
2. Digite o e-mail, marque as empresas e clique em **Liberar acesso e gerar senha**.
3. A senha aparece na tela uma única vez. Clique em **Copiar e-mail e senha** e envie para a pessoa.

Na mesma tela você muda as empresas de cada pessoa (vale na hora), usa **Resetar senha** para gerar uma nova senha e remove o acesso de quem saiu.

Por segurança, o sistema não guarda as senhas de forma legível. Por isso não é possível ver uma senha antiga, só gerar uma nova.

## Usar pelo arquivo no computador

Deixe `index.html` e `config.js` juntos em `C:\PROJETO-TAREFAS` e abra o `index.html`. Ele entra no mesmo banco de dados do site, então tudo fica sincronizado.

## Observações

- No plano gratuito, o Supabase pausa o projeto depois de 7 dias sem nenhum acesso. Basta entrar no painel e clicar em **Restore**.
- Se alguém mudar uma tarefa, quem está com o quadro aberto vê a mudança na hora.
