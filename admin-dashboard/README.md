# MarketView Admin Dashboard

Dashboard web administrativo do MarketView. Esta versao segue a proposta do
arquivo `admin_dashboard_spec.md`, adaptada para a arquitetura atual do app:
Firebase Auth no login e backend administrativo com Firebase Admin SDK para ler
Firestore sem abrir regras publicas.

## Parte 1 entregue

- Projeto React + TypeScript + Vite.
- TailwindCSS configurado.
- Login com Firebase Auth.
- Protecao de rotas por custom claims.
- Layout com sidebar.
- Telas-base: visao geral, chats, anuncios, usuarios e auditoria.
- Cliente API que envia `Authorization: Bearer <Firebase ID token>`.

## Configuracao local

Crie `admin-dashboard/.env.local` com base em `.env.example`.

```bash
npm install
npm run dev
```

## Variaveis necessarias

As variaveis `VITE_FIREBASE_*` devem vir do app web do Firebase no projeto
`marketview-by-clearview`.

`VITE_API_BASE_URL` deve apontar para o backend administrativo seguro. Exemplo:

```text
VITE_API_BASE_URL=http://localhost:5001/marketview-by-clearview/us-central1/api
```

ou, em producao:

```text
VITE_API_BASE_URL=https://admin-api.seu-dominio.com
```

## O que voce precisa configurar no Firebase

1. Criar ou reutilizar um app Web no Firebase Console.
2. Copiar as configuracoes Web para `.env.local`.
3. Em Authentication > Sign-in method, habilitar Email/Senha.
4. Criar os usuarios da equipe MarketView.
5. Adicionar custom claims nesses usuarios:

```json
{ "admin": true, "adminRole": "admin" }
```

ou para suporte:

```json
{ "support": true, "adminRole": "suporte" }
```

6. Em Authentication > Settings > Authorized domains, adicionar o dominio do
dashboard quando publicar.

## Como aplicar custom claims

Use o script pronto do projeto:

```bash
npm run set-claims -- --email usuario@marketview.com --role admin --service-account C:/caminho/service-account.json
```

Para suporte:

```bash
npm run set-claims -- --email suporte@marketview.com --role suporte --service-account C:/caminho/service-account.json
```

O arquivo `service-account.json` precisa ser baixado no Firebase Console do
projeto correto. O script procura o usuario por email e grava as claims nele.

## Backend esperado

O dashboard nao acessa Firestore diretamente. O backend deve validar o Firebase
ID token com Admin SDK, checar `adminRole` e executar consultas administrativas.

Endpoints usados pela UI:

- `GET /admin/summary`
- `GET /admin/chats?page=1&limit=25`
- `GET /admin/chats/:chatId/messages`
- `GET /admin/ads?page=1&limit=25`
- `PATCH /admin/ads/:adId`
- `DELETE /admin/ads/:adId`
- `GET /admin/users?page=1&limit=25`
- `GET /admin/activities?page=1&limit=25`

Toda leitura de chat, edicao de anuncio, exclusao e suspensao futura deve gerar
um documento de auditoria em `admin_audit_logs`.

## Rodar o monitor completo localmente

Em um terminal, suba a API administrativa:

```bash
cd C:\Users\User\AndroidStudioProjects\marketview
firebase emulators:start --only functions --project marketview-by-clearview
```

Em outro terminal, suba o painel:

```bash
cd C:\Users\User\AndroidStudioProjects\marketview\admin-dashboard
npm run dev -- --host 127.0.0.1 --port 5173
```

Depois abra:

```text
http://localhost:5173
```

O painel local usa:

```text
http://localhost:5001/marketview-by-clearview/us-central1/api
```

Enquanto o Firestore emulator nao estiver ligado, a API local fala com o
Firestore de producao do projeto `marketview-by-clearview`. Use apenas contas
admin autorizadas.

## Regra de seguranca importante

Nao abra `firestore.rules` para o dashboard. O painel deve operar por backend
com Admin SDK. As regras do app continuam protegendo apenas clientes normais.

## Proxima parte

A proxima etapa e criar o backend administrativo com Firebase Functions:

- middleware para validar ID token;
- permissao por role;
- endpoints acima;
- auditoria em `admin_audit_logs`;
- consultas paginadas para `users`, `ads`, `chats` e `messages`.
