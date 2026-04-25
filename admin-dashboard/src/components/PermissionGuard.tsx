import type { ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router-dom';

import { useAuth } from '../contexts/auth';

type PermissionGuardProps = {
  children: ReactNode;
};

export function PermissionGuard({ children }: PermissionGuardProps) {
  const location = useLocation();
  const { admin, isLoading } = useAuth();

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-slate-50 text-slate-600">
        Carregando acesso...
      </div>
    );
  }

  if (!admin) {
    return <Navigate to="/login" replace state={{ from: location }} />;
  }

  return children;
}
