import { useQuery } from '@tanstack/react-query';
import {
  Megaphone,
  MessageSquareText,
  ShieldAlert,
  Users,
} from 'lucide-react';

import { ApiNotice } from '../components/ApiNotice';
import { getDashboardSummary, isApiConfigured } from '../services/api';

const emptySummary = {
  usersTotal: 0,
  adsActive: 0,
  chatsTotal: 0,
  pendingReports: 0,
};

export function OverviewPage() {
  const summaryQuery = useQuery({
    queryKey: ['admin-summary'],
    queryFn: getDashboardSummary,
    enabled: isApiConfigured,
  });
  const summary = summaryQuery.data ?? emptySummary;
  const cards = [
    {
      label: 'Usuarios',
      value: summary.usersTotal,
      icon: Users,
      color: 'text-market-blue',
    },
    {
      label: 'Anuncios ativos',
      value: summary.adsActive,
      icon: Megaphone,
      color: 'text-market-mint',
    },
    {
      label: 'Chats',
      value: summary.chatsTotal,
      icon: MessageSquareText,
      color: 'text-market-sky',
    },
    {
      label: 'Pendencias',
      value: summary.pendingReports,
      icon: ShieldAlert,
      color: 'text-market-amber',
    },
  ];

  return (
    <section>
      <div className="mb-6">
        <h2 className="text-2xl font-bold">Visao geral</h2>
        <p className="text-sm text-slate-500">
          Numeros principais para suporte e moderacao.
        </p>
      </div>

      <ApiNotice error={summaryQuery.error} />

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {cards.map((card) => (
          <article
            key={card.label}
            className="rounded-lg border border-slate-200 bg-white p-5 shadow-sm"
          >
            <div className="mb-4 flex items-center justify-between">
              <span className="text-sm font-semibold text-slate-500">
                {card.label}
              </span>
              <card.icon className={`h-5 w-5 ${card.color}`} aria-hidden />
            </div>
            <strong className="text-3xl font-bold">
              {card.value.toLocaleString('pt-BR')}
            </strong>
          </article>
        ))}
      </div>
    </section>
  );
}
