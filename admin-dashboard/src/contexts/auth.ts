import { createContext, useContext } from 'react';
import type { User } from 'firebase/auth';

import type { AdminUser } from '../types';

export type AuthContextValue = {
  admin: AdminUser | null;
  firebaseUser: User | null;
  isLoading: boolean;
  configError: string | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
};

export const AuthContext = createContext<AuthContextValue | null>(null);

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth deve ser usado dentro de AuthProvider.');
  }
  return context;
}
