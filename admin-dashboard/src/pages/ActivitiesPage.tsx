import { useQuery } from '@tanstack/react-query';

import { ApiNotice } from '../components/ApiNotice';
import { getActivities, isApiConfigured } from '../services/api';
import { formatDate } from '../utils/formatters';

export function ActivitiesPage() {
  const activitiesQuery = useQuery({
    queryKey: ['admin-activities'],
    queryFn: () => getActivities(),
    enabled: isApiConfigured,
  });
  const activities = activitiesQuery.data?.data ?? [];

  return (
    <section>
      <div className="mb-6">
        <h2 className="text-2xl font-bold">Auditoria</h2>
        <p className="text-sm text-slate-500">
          Registro de leitura de chats, alteracoes e remocoes.
        </p>
      </div>

      <ApiNotice error={activitiesQuery.error} />

      <div className="overflow-hidden rounded-lg border border-slate-200 bg-white">
        <table className="w-full min-w-[900px] text-left text-sm">
          <thead className="bg-slate-50 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">Admin</th>
              <th className="px-4 py-3">Acao</th>
              <th className="px-4 py-3">Recurso</th>
              <th className="px-4 py-3">Descricao</th>
              <th className="px-4 py-3">Data</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {activities.map((activity) => (
              <tr key={activity.id} className="hover:bg-slate-50">
                <td className="px-4 py-3">{activity.adminEmail}</td>
                <td className="px-4 py-3 font-semibold">{activity.action}</td>
                <td className="px-4 py-3">
                  {activity.resourceType}:{activity.resourceId}
                </td>
                <td className="px-4 py-3">{activity.description}</td>
                <td className="px-4 py-3">{formatDate(activity.createdAt)}</td>
              </tr>
            ))}
            {activities.length === 0 && (
              <tr>
                <td className="px-4 py-10 text-center text-slate-500" colSpan={5}>
                  Nenhuma atividade carregada ainda.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </section>
  );
}
