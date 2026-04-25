import { useState, type FormEvent } from 'react';
import { LockKeyhole, ShieldCheck } from 'lucide-react';
import { Navigate, useLocation, useNavigate } from 'react-router-dom';

import { useAuth } from '../contexts/auth';

export function LoginPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const { admin, configError, login } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const from = (location.state as { from?: { pathname?: string } } | null)?.from
    ?.pathname;

  if (admin) return <Navigate to={from ?? '/'} replace />;

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setIsSubmitting(true);
    try {
      await login(email.trim(), password);
      navigate(from ?? '/', { replace: true });
    } catch (caught) {
      setError(
        caught instanceof Error ? caught.message : 'Nao foi possivel entrar.',
      );
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <main className="flex min-h-screen bg-slate-100">
      <section className="hidden flex-1 bg-market-ink px-12 py-10 text-white lg:flex lg:flex-col lg:justify-between">
        <div className="flex items-center gap-3 text-lg font-bold">
          <ShieldCheck className="h-6 w-6 text-market-mint" aria-hidden="true" />
          MarketView Admin
        </div>
        <div className="max-w-xl">
          <p className="mb-4 text-sm font-semibold uppercase tracking-[0.2em] text-market-mint">
            Operacao segura
          </p>
          <h1 className="text-5xl font-bold leading-tight">
            Monitoramento interno sem abrir regras do Firebase.
          </h1>
          <p className="mt-5 text-lg text-slate-300">
            Acesso por Firebase Auth, permissao por custom claims e chamadas
            protegidas por backend administrativo.
          </p>
        </div>
      </section>

      <section className="flex w-full items-center justify-center px-5 py-10 lg:w-[480px]">
        <form
          onSubmit={handleSubmit}
          className="w-full max-w-md rounded-lg bg-white p-6 shadow-panel"
        >
          <div className="mb-8 flex items-center gap-3">
            <span className="flex h-11 w-11 items-center justify-center rounded bg-blue-50 text-market-blue">
              <LockKeyhole className="h-5 w-5" aria-hidden="true" />
            </span>
            <div>
              <h2 className="text-xl font-bold text-slate-950">
                Entrar no monitor
              </h2>
              <p className="text-sm text-slate-500">
                Use uma conta autorizada da equipe.
              </p>
            </div>
          </div>

          {configError && (
            <div className="mb-4 rounded border border-amber-200 bg-amber-50 p-3 text-sm text-amber-900">
              {configError}
            </div>
          )}

          {error && (
            <div className="mb-4 rounded border border-rose-200 bg-rose-50 p-3 text-sm text-rose-900">
              {error}
            </div>
          )}

          <label className="mb-4 block">
            <span className="mb-1 block text-sm font-semibold text-slate-700">
              Email
            </span>
            <input
              className="w-full rounded border border-slate-300 px-3 py-2 text-slate-950"
              type="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              autoComplete="email"
              required
            />
          </label>

          <label className="mb-6 block">
            <span className="mb-1 block text-sm font-semibold text-slate-700">
              Senha
            </span>
            <input
              className="w-full rounded border border-slate-300 px-3 py-2 text-slate-950"
              type="password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              autoComplete="current-password"
              required
            />
          </label>

          <button
            type="submit"
            disabled={isSubmitting || Boolean(configError)}
            className="flex w-full items-center justify-center rounded bg-market-blue px-4 py-2.5 font-semibold text-white transition hover:bg-blue-700 disabled:cursor-not-allowed disabled:bg-slate-300"
          >
            {isSubmitting ? 'Entrando...' : 'Entrar'}
          </button>
        </form>
      </section>
    </main>
  );
}
