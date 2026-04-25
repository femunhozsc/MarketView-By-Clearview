# Publicacao do Monitor MarketView

Este guia explica, passo a passo, como publicar o monitor MarketView para ele
funcionar sem depender do seu computador.

## O que vai para cada lugar

- `admin-dashboard/` vai para a Vercel
- `functions/` vai para o Firebase Functions
- `Firestore` e `Auth` continuam no Firebase

Depois de publicado, o monitor abre pela URL da Vercel e conversa com a API do
Firebase Functions. O seu computador deixa de ser necessario para o uso normal.

## 1. O que voce ja precisa ter pronto

1. O projeto Firebase no Blaze.
2. A conta admin com custom claim:

```json
{ "admin": true, "adminRole": "admin" }
```

3. O arquivo `admin-dashboard/.env.local` com as variaveis do Firebase.
4. O arquivo de service account apenas para uso local, em:

```text
admin-dashboard/.secrets/service-account.json
```

## 2. Publicar o backend no Firebase

Primeiro publique a API administrativa.

No terminal:

```powershell
cd C:\Users\User\AndroidStudioProjects\marketview
firebase deploy --only functions:api --project marketview-by-clearview
```

Se der certo, a API publica costuma ficar em um endereco parecido com:

```text
https://us-central1-marketview-by-clearview.cloudfunctions.net/api
```

Essa URL e a que o monitor vai usar em producao.

## 3. Configurar o monitor para producao

No arquivo `admin-dashboard/.env.local`, troque o valor de `VITE_API_BASE_URL`
para a URL publica do backend:

```text
VITE_API_BASE_URL=https://us-central1-marketview-by-clearview.cloudfunctions.net/api
```

As demais variaveis `VITE_FIREBASE_*` continuam apontando para o mesmo projeto
Firebase.

## 4. Entender o arquivo `vercel.json`

O monitor e uma aplicacao React de pagina unica. Por isso o arquivo
`admin-dashboard/vercel.json` faz todas as rotas voltarem para `index.html`.

Isso evita erro ao atualizar paginas internas como:

- `/support`
- `/community`
- `/users`
- `/ads`

## 5. Publicar o monitor na Vercel

Na Vercel:

1. Crie um novo projeto.
2. Conecte o repositorio do MarketView.
3. Escolha a pasta `admin-dashboard` como `Root Directory`.
4. Configure:

```text
Install Command: npm install
Build Command: npm run build
Output Directory: dist
```

5. Adicione as variaveis de ambiente da aplicacao.
6. Faça o deploy.

## 6. Variaveis na Vercel

Na Vercel, copie as variaveis do `admin-dashboard/.env.local` para a tela de
Environment Variables.

As mais importantes sao:

```text
VITE_API_BASE_URL
VITE_FIREBASE_API_KEY
VITE_FIREBASE_AUTH_DOMAIN
VITE_FIREBASE_PROJECT_ID
VITE_FIREBASE_STORAGE_BUCKET
VITE_FIREBASE_MESSAGING_SENDER_ID
VITE_FIREBASE_APP_ID
VITE_ADMIN_EMAIL_ALLOWLIST
```

Nao envie o arquivo `.secrets/service-account.json` para a Vercel.

## 7. Teste final

Depois do deploy, abra a URL da Vercel e confira:

1. Login do admin.
2. Visao geral.
3. Chats.
4. Suporte.
5. Comunidade.
6. Anuncios.
7. Usuarios.
8. Auditoria.

Se alguma tela der erro, quase sempre e uma destas coisas:

- `VITE_API_BASE_URL` ainda aponta para `localhost`
- o backend do Firebase nao foi publicado
- a conta nao tem custom claim de admin
- faltou recarregar a pagina depois de alterar variaveis

## 8. Como saber se o monitor esta independente do seu computador

O teste e simples:

1. Feche os terminais locais.
2. Abra a URL da Vercel.
3. Tente entrar no monitor.
4. Tente listar chats, suportes e usuarios.

Se funcionar assim, o monitor ja nao depende do seu computador.

## 9. Cuidados com custo

Como o projeto esta no Blaze, pode haver custo se houver uso acima das cotas
gratuitas. O ideal e configurar alertas de budget no Firebase/Google Cloud.

## 10. Ordem recomendada daqui para frente

1. Publicar o backend Firebase Functions.
2. Publicar o monitor na Vercel.
3. Testar as telas principais.
4. Configurar alertas de budget.
5. Criar dominio proprio do monitor, se quiser.
