import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Edit3, Save, X } from 'lucide-react';
import { useState, type FormEvent } from 'react';

import { ApiNotice } from '../components/ApiNotice';
import { StatusBadge } from '../components/StatusBadge';
import { getUsers, isApiConfigured, updateUser } from '../services/api';
import type { UserSummary } from '../types';
import { formatDate } from '../utils/formatters';

type UserFormState = {
  firstName: string;
  lastName: string;
  phone: string;
  city: string;
  state: string;
  status: 'active' | 'suspended';
};

function formFromUser(user: UserSummary): UserFormState {
  const nameParts = user.name.trim().split(/\s+/).filter(Boolean);
  return {
    firstName: user.firstName || nameParts[0] || '',
    lastName: user.lastName || nameParts.slice(1).join(' '),
    phone: user.phone,
    city: user.city,
    state: user.state,
    status: user.status === 'suspended' ? 'suspended' : 'active',
  };
}

export function UsersPage() {
  const queryClient = useQueryClient();
  const [editingUser, setEditingUser] = useState<UserSummary | null>(null);
  const [form, setForm] = useState<UserFormState | null>(null);

  const usersQuery = useQuery({
    queryKey: ['admin-users'],
    queryFn: () => getUsers(),
    enabled: isApiConfigured,
  });

  const editMutation = useMutation({
    mutationFn: ({
      userId,
      data,
    }: {
      userId: string;
      data: Partial<UserSummary>;
    }) => updateUser(userId, data),
    onSuccess: () => {
      setEditingUser(null);
      setForm(null);
      queryClient.invalidateQueries({ queryKey: ['admin-users'] });
    },
  });

  const users = usersQuery.data?.data ?? [];

  function openEditor(user: UserSummary) {
    setEditingUser(user);
    setForm(formFromUser(user));
  }

  function closeEditor() {
    if (editMutation.isPending) return;
    setEditingUser(null);
    setForm(null);
  }

  function updateForm<K extends keyof UserFormState>(
    key: K,
    value: UserFormState[K],
  ) {
    setForm((current) => (current ? { ...current, [key]: value } : current));
  }

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!editingUser || !form) return;
    editMutation.mutate({
      userId: editingUser.uid,
      data: {
        firstName: form.firstName.trim(),
        lastName: form.lastName.trim(),
        phone: form.phone.trim(),
        city: form.city.trim(),
        state: form.state.trim(),
        status: form.status,
      },
    });
  }

  return (
    <section>
      <div className="mb-6">
        <h2 className="text-2xl font-bold">Usuarios</h2>
        <p className="text-sm text-slate-500">
          Consulta operacional para suporte e verificacao de contas.
        </p>
      </div>

      <ApiNotice error={usersQuery.error} />

      <div className="overflow-hidden rounded-lg border border-slate-200 bg-white">
        <table className="w-full min-w-[960px] text-left text-sm">
          <thead className="bg-slate-50 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">Usuario</th>
              <th className="px-4 py-3">Contato</th>
              <th className="px-4 py-3">Cidade</th>
              <th className="px-4 py-3">Anuncios</th>
              <th className="px-4 py-3">Status</th>
              <th className="px-4 py-3">Criado em</th>
              <th className="px-4 py-3">Acoes</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {users.map((user) => (
              <tr key={user.uid} className="hover:bg-slate-50">
                <td className="px-4 py-3">
                  <p className="font-semibold">{user.name}</p>
                  <p className="text-xs text-slate-500">{user.uid}</p>
                </td>
                <td className="px-4 py-3">
                  <p>{user.email}</p>
                  <p className="text-xs text-slate-500">{user.phone}</p>
                </td>
                <td className="px-4 py-3">
                  {[user.city, user.state].filter(Boolean).join(' - ')}
                </td>
                <td className="px-4 py-3">{user.adsCount}</td>
                <td className="px-4 py-3">
                  <StatusBadge
                    label={user.status}
                    tone={user.status === 'active' ? 'green' : 'red'}
                  />
                </td>
                <td className="px-4 py-3">{formatDate(user.createdAt)}</td>
                <td className="px-4 py-3">
                  <button
                    type="button"
                    onClick={() => openEditor(user)}
                    className="inline-flex items-center gap-2 rounded border border-slate-200 px-3 py-1.5 font-semibold text-slate-700 hover:bg-slate-50"
                  >
                    <Edit3 className="h-4 w-4" aria-hidden />
                    Editar
                  </button>
                </td>
              </tr>
            ))}
            {users.length === 0 && (
              <tr>
                <td className="px-4 py-10 text-center text-slate-500" colSpan={7}>
                  Nenhum usuario carregado ainda.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {editingUser && form && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/40 px-4 py-6">
          <form
            onSubmit={handleSubmit}
            className="w-full max-w-2xl rounded-lg bg-white shadow-panel"
          >
            <div className="flex items-center justify-between border-b border-slate-200 px-5 py-4">
              <div>
                <h3 className="text-lg font-bold">Editar usuario</h3>
                <p className="text-sm text-slate-500">{editingUser.email}</p>
              </div>
              <button
                type="button"
                onClick={closeEditor}
                className="rounded border border-slate-200 p-2 text-slate-600 hover:bg-slate-50"
                aria-label="Fechar editor"
              >
                <X className="h-4 w-4" aria-hidden />
              </button>
            </div>

            <div className="grid gap-4 px-5 py-5 md:grid-cols-2">
              <label>
                <span className="mb-1 block text-sm font-semibold text-slate-700">
                  Nome
                </span>
                <input
                  className="w-full rounded border border-slate-300 px-3 py-2"
                  value={form.firstName}
                  onChange={(event) =>
                    updateForm('firstName', event.target.value)
                  }
                  required
                />
              </label>
              <label>
                <span className="mb-1 block text-sm font-semibold text-slate-700">
                  Sobrenome
                </span>
                <input
                  className="w-full rounded border border-slate-300 px-3 py-2"
                  value={form.lastName}
                  onChange={(event) =>
                    updateForm('lastName', event.target.value)
                  }
                />
              </label>
              <label>
                <span className="mb-1 block text-sm font-semibold text-slate-700">
                  Telefone
                </span>
                <input
                  className="w-full rounded border border-slate-300 px-3 py-2"
                  value={form.phone}
                  onChange={(event) => updateForm('phone', event.target.value)}
                />
              </label>
              <label>
                <span className="mb-1 block text-sm font-semibold text-slate-700">
                  Status
                </span>
                <select
                  className="w-full rounded border border-slate-300 px-3 py-2"
                  value={form.status}
                  onChange={(event) =>
                    updateForm(
                      'status',
                      event.target.value as UserFormState['status'],
                    )
                  }
                >
                  <option value="active">active</option>
                  <option value="suspended">suspended</option>
                </select>
              </label>
              <label>
                <span className="mb-1 block text-sm font-semibold text-slate-700">
                  Cidade
                </span>
                <input
                  className="w-full rounded border border-slate-300 px-3 py-2"
                  value={form.city}
                  onChange={(event) => updateForm('city', event.target.value)}
                />
              </label>
              <label>
                <span className="mb-1 block text-sm font-semibold text-slate-700">
                  Estado
                </span>
                <input
                  className="w-full rounded border border-slate-300 px-3 py-2"
                  value={form.state}
                  onChange={(event) => updateForm('state', event.target.value)}
                />
              </label>
            </div>

            {editMutation.error && (
              <div className="mx-5 mb-4 rounded border border-rose-200 bg-rose-50 p-3 text-sm text-rose-900">
                Nao foi possivel salvar o usuario.
              </div>
            )}

            <div className="flex justify-end gap-2 border-t border-slate-200 px-5 py-4">
              <button
                type="button"
                onClick={closeEditor}
                className="rounded border border-slate-200 px-4 py-2 font-semibold text-slate-700 hover:bg-slate-50"
              >
                Cancelar
              </button>
              <button
                type="submit"
                disabled={editMutation.isPending}
                className="inline-flex items-center gap-2 rounded bg-market-blue px-4 py-2 font-semibold text-white hover:bg-blue-700 disabled:bg-slate-300"
              >
                <Save className="h-4 w-4" aria-hidden />
                {editMutation.isPending ? 'Salvando...' : 'Salvar'}
              </button>
            </div>
          </form>
        </div>
      )}
    </section>
  );
}
