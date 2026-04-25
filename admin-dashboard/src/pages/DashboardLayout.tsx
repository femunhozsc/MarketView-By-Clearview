import {
  BarChart3,
  FileClock,
  Headset,
  LayoutDashboard,
  LogOut,
  MessageSquareText,
  PackageSearch,
  RadioTower,
  SlidersHorizontal,
  Users,
} from 'lucide-react';
import { NavLink, Outlet } from 'react-router-dom';
import clsx from 'clsx';

import { useAuth } from '../contexts/auth';

const navItems = [
  { to: '/', label: 'Visao geral', icon: LayoutDashboard },
  { to: '/chats', label: 'Chats', icon: MessageSquareText },
  { to: '/support', label: 'Suporte', icon: Headset },
  { to: '/community', label: 'Comunidade', icon: RadioTower },
  { to: '/ads', label: 'Anuncios', icon: PackageSearch },
  { to: '/personalize', label: 'Personalizar', icon: SlidersHorizontal },
  { to: '/users', label: 'Usuarios', icon: Users },
  { to: '/activities', label: 'Auditoria', icon: FileClock },
];

export function DashboardLayout() {
  const { admin, logout } = useAuth();

  return (
    <div className="min-h-screen bg-slate-100 text-slate-950">
      <aside className="fixed inset-y-0 left-0 hidden w-64 border-r border-slate-200 bg-white lg:flex lg:flex-col">
        <div className="flex h-16 items-center gap-3 border-b border-slate-200 px-5">
          <BarChart3 className="h-6 w-6 text-market-blue" aria-hidden="true" />
          <span className="font-bold">MarketView Admin</span>
        </div>
        <nav className="flex-1 space-y-1 px-3 py-4">
          {navItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.to === '/'}
              className={({ isActive }) =>
                clsx(
                  'flex items-center gap-3 rounded px-3 py-2 text-sm font-semibold',
                  isActive
                    ? 'bg-blue-50 text-market-blue'
                    : 'text-slate-600 hover:bg-slate-100 hover:text-slate-950',
                )
              }
            >
              <item.icon className="h-4 w-4" aria-hidden="true" />
              {item.label}
            </NavLink>
          ))}
        </nav>
        <div className="border-t border-slate-200 p-4">
          <p className="text-sm font-semibold">{admin?.name}</p>
          <p className="text-xs text-slate-500">
            {admin?.email} · {admin?.role}
          </p>
          <button
            type="button"
            onClick={logout}
            className="mt-3 flex w-full items-center gap-2 rounded border border-slate-200 px-3 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-50"
          >
            <LogOut className="h-4 w-4" aria-hidden="true" />
            Sair
          </button>
        </div>
      </aside>

      <div className="lg:pl-64">
        <header className="sticky top-0 z-10 border-b border-slate-200 bg-white px-4 py-3 lg:px-8">
          <div className="flex items-center justify-between gap-4">
            <div>
              <p className="text-xs font-semibold uppercase tracking-[0.16em] text-slate-500">
                Monitor
              </p>
              <h1 className="text-xl font-bold">Operacao MarketView</h1>
            </div>
            <button
              type="button"
              onClick={logout}
              className="flex items-center gap-2 rounded border border-slate-200 px-3 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-50 lg:hidden"
            >
              <LogOut className="h-4 w-4" aria-hidden="true" />
              Sair
            </button>
          </div>
          <nav className="mt-3 flex gap-2 overflow-x-auto lg:hidden">
            {navItems.map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                end={item.to === '/'}
                className={({ isActive }) =>
                  clsx(
                    'whitespace-nowrap rounded px-3 py-2 text-sm font-semibold',
                    isActive
                      ? 'bg-blue-50 text-market-blue'
                      : 'text-slate-600',
                  )
                }
              >
                {item.label}
              </NavLink>
            ))}
          </nav>
        </header>
        <main className="px-4 py-6 lg:px-8">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
