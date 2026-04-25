import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import process from 'node:process';

import { cert, initializeApp } from 'firebase-admin/app';
import { getAuth as getAdminAuth } from 'firebase-admin/auth';

function usage() {
  console.log(
    'Uso: npm run set-claims -- --email usuario@exemplo.com --role admin --service-account C:/caminho/service-account.json',
  );
}

function readArg(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

function getServiceAccountPath() {
  return (
    readArg('--service-account') ||
    process.env.FIREBASE_SERVICE_ACCOUNT_PATH ||
    process.env.GOOGLE_APPLICATION_CREDENTIALS
  );
}

async function loadServiceAccount(pathValue) {
  if (!pathValue) {
    throw new Error(
      'Defina --service-account ou FIREBASE_SERVICE_ACCOUNT_PATH/GOOGLE_APPLICATION_CREDENTIALS.',
    );
  }

  const raw = await readFile(resolve(pathValue), 'utf8');
  return JSON.parse(raw);
}

function resolveClaims(role) {
  if (role === 'admin') {
    return { admin: true, adminRole: 'admin' };
  }
  if (role === 'suporte') {
    return { support: true, adminRole: 'suporte' };
  }
  throw new Error('Role invalido. Use admin ou suporte.');
}

async function main() {
  const email = readArg('--email');
  const role = readArg('--role');
  const serviceAccountPath = getServiceAccountPath();

  if (!email || !role) {
    usage();
    process.exit(1);
  }

  const serviceAccount = await loadServiceAccount(serviceAccountPath);
  const app = initializeApp({
    credential: cert(serviceAccount),
    projectId: serviceAccount.project_id,
  });

  const auth = getAdminAuth(app);
  const user = await auth.getUserByEmail(email);
  const claims = resolveClaims(role);

  await auth.setCustomUserClaims(user.uid, claims);

  console.log(`Claims definidos para ${email} (${user.uid}) -> ${JSON.stringify(claims)}`);
  process.exit(0);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
