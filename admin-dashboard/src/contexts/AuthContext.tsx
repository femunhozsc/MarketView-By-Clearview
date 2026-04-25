import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
  type User,
} from 'firebase/auth';
import {
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';

import { AuthContext, type AuthContextValue } from './auth';
import { auth, isFirebaseConfigured } from '../services/firebase';
import type { AdminRole, AdminUser } from '../types';

const allowedEmails = (import.meta.env.VITE_ADMIN_EMAIL_ALLOWLIST as
  | string
  | undefined)
  ?.split(',')
  .map((value) => value.trim().toLowerCase())
  .filter(Boolean) ?? [];

function roleFromClaims(claims: Record<string, unknown>): AdminRole | null {
  if (claims.admin === true || claims.adminRole === 'admin') return 'admin';
  if (claims.support === true || claims.adminRole === 'suporte') {
    return 'suporte';
  }
  return null;
}

function roleFromEmail(email: string): AdminRole | null {
  if (allowedEmails.includes(email.trim().toLowerCase())) {
    return 'admin';
  }
  return null;
}

async function resolveAdmin(user: User): Promise<AdminUser | null> {
  await user.reload();
  const token = await user.getIdTokenResult(true);
  const role =
    roleFromClaims(token.claims) || roleFromEmail(user.email ?? '');
  if (!role) return null;

  return {
    uid: user.uid,
    email: user.email ?? '',
    name: user.displayName ?? user.email ?? 'Admin MarketView',
    role,
  };
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [firebaseUser, setFirebaseUser] = useState<User | null>(null);
  const [admin, setAdmin] = useState<AdminUser | null>(null);
  const [isLoading, setIsLoading] = useState(isFirebaseConfigured);
  const configError = isFirebaseConfigured
    ? null
    : 'Configure as variaveis VITE_FIREBASE_* em .env.local.';

  useEffect(() => {
    if (!auth) {
      return undefined;
    }

    return onAuthStateChanged(auth, async (user) => {
      setFirebaseUser(user);
      if (!user) {
        setAdmin(null);
        setIsLoading(false);
        return;
      }

      const tryResolve = async () => {
        try {
          const resolved = await resolveAdmin(user);
          setAdmin(resolved);
        } catch {
          setAdmin(null);
        } finally {
          setIsLoading(false);
        }
      };

      await tryResolve();
    });
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({
      admin,
      firebaseUser,
      isLoading,
      configError,
      login: async (email, password) => {
        if (!auth) {
          throw new Error('Firebase nao configurado.');
        }
        const credential = await signInWithEmailAndPassword(
          auth,
          email,
          password,
        );
        let resolvedAdmin: AdminUser | null = null;
        for (let attempt = 0; attempt < 3; attempt += 1) {
          resolvedAdmin = await resolveAdmin(credential.user);
          if (resolvedAdmin) break;
          await new Promise((resolve) => setTimeout(resolve, 1200));
        }
        if (!resolvedAdmin) {
          await signOut(auth);
          throw new Error(
            'Esta conta nao possui permissao administrativa. Verifique as claims ou o email permitido.',
          );
        }
        setAdmin(resolvedAdmin);
      },
      logout: async () => {
        if (auth) await signOut(auth);
        setAdmin(null);
      },
    }),
    [admin, configError, firebaseUser, isLoading],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
