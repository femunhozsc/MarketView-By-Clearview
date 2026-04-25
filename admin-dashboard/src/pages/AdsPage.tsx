import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Edit3, PauseCircle, Save, Trash2, X } from 'lucide-react';
import { useState, type FormEvent } from 'react';

import { ApiNotice } from '../components/ApiNotice';
import { StatusBadge } from '../components/StatusBadge';
import { useAuth } from '../contexts/auth';
import { canDeleteAds } from '../lib/permissions';
import { getAds, isApiConfigured, removeAd, updateAd } from '../services/api';
import type { AdSummary } from '../types';
import { formatCurrency, formatDate } from '../utils/formatters';

type AdFormState = {
  title: string;
  description: string;
  price: string;
  category: string;
  location: string;
  isActive: boolean;
};

function formFromAd(ad: AdSummary): AdFormState {
  return {
    title: ad.title,
    description: ad.description,
    price: String(ad.price),
    category: ad.category,
    location: ad.location,
    isActive: ad.isActive,
  };
}

export function AdsPage() {
  const queryClient = useQueryClient();
  const { admin } = useAuth();
  const [editingAd, setEditingAd] = useState<AdSummary | null>(null);
  const [form, setForm] = useState<AdFormState | null>(null);
  const adsQuery = useQuery({
    queryKey: ['admin-ads'],
    queryFn: () => getAds(),
    enabled: isApiConfigured,
  });
  const pauseMutation = useMutation({
    mutationFn: (adId: string) => updateAd(adId, { isActive: false }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['admin-ads'] }),
  });
  const removeMutation = useMutation({
    mutationFn: (adId: string) =>
      removeAd(adId, 'Remocao administrativa pelo painel.'),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['admin-ads'] }),
  });
  const editMutation = useMutation({
    mutationFn: ({
      adId,
      data,
    }: {
      adId: string;
      data: Partial<AdSummary>;
    }) => updateAd(adId, data),
    onSuccess: () => {
      setEditingAd(null);
      setForm(null);
      queryClient.invalidateQueries({ queryKey: ['admin-ads'] });
    },
  });
  const ads = adsQuery.data?.data ?? [];

  function openEditor(ad: AdSummary) {
    setEditingAd(ad);
    setForm(formFromAd(ad));
  }

  function closeEditor() {
    if (editMutation.isPending) return;
    setEditingAd(null);
    setForm(null);
  }

  function updateForm<K extends keyof AdFormState>(
    key: K,
    value: AdFormState[K],
  ) {
    setForm((current) => (current ? { ...current, [key]: value } : current));
  }

  function handleEditSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!editingAd || !form) return;
    editMutation.mutate({
      adId: editingAd.id,
      data: {
        title: form.title.trim(),
        description: form.description.trim(),
        price: Number(form.price.replace(',', '.')) || 0,
        category: form.category.trim(),
        location: form.location.trim(),
        isActive: form.isActive,
      },
    });
  }

  return (
    <section>
      <div className="mb-6">
        <h2 className="text-2xl font-bold">Anuncios</h2>
        <p className="text-sm text-slate-500">
          Moderacao e edicao com motivo e auditoria no backend.
        </p>
      </div>

      <ApiNotice error={adsQuery.error} />

      <div className="overflow-hidden rounded-lg border border-slate-200 bg-white">
        <table className="w-full min-w-[920px] text-left text-sm">
          <thead className="bg-slate-50 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">Anuncio</th>
              <th className="px-4 py-3">Vendedor</th>
              <th className="px-4 py-3">Preco</th>
              <th className="px-4 py-3">Local</th>
              <th className="px-4 py-3">Status</th>
              <th className="px-4 py-3">Criado em</th>
              <th className="px-4 py-3">Acoes</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {ads.map((ad) => (
              <tr key={ad.id} className="hover:bg-slate-50">
                <td className="px-4 py-3">
                  <p className="font-semibold">{ad.title}</p>
                  <p className="text-xs text-slate-500">{ad.category}</p>
                </td>
                <td className="px-4 py-3">{ad.sellerName}</td>
                <td className="px-4 py-3">{formatCurrency(ad.price)}</td>
                <td className="px-4 py-3">{ad.location}</td>
                <td className="px-4 py-3">
                  <StatusBadge
                    label={ad.status}
                    tone={ad.isActive ? 'green' : 'slate'}
                  />
                </td>
                <td className="px-4 py-3">{formatDate(ad.createdAt)}</td>
                <td className="px-4 py-3">
                  <div className="flex gap-2">
                    <button
                      type="button"
                      onClick={() => openEditor(ad)}
                      className="inline-flex items-center gap-2 rounded border border-slate-200 px-3 py-1.5 font-semibold text-slate-700 hover:bg-slate-50"
                    >
                      <Edit3 className="h-4 w-4" aria-hidden />
                      Editar
                    </button>
                    <button
                      type="button"
                      onClick={() => pauseMutation.mutate(ad.id)}
                      className="inline-flex items-center gap-2 rounded border border-slate-200 px-3 py-1.5 font-semibold text-slate-700 hover:bg-slate-50"
                    >
                      <PauseCircle className="h-4 w-4" aria-hidden />
                      Pausar
                    </button>
                    {admin && canDeleteAds(admin.role) && (
                      <button
                        type="button"
                        onClick={() => removeMutation.mutate(ad.id)}
                        className="inline-flex items-center gap-2 rounded border border-rose-200 px-3 py-1.5 font-semibold text-rose-700 hover:bg-rose-50"
                      >
                        <Trash2 className="h-4 w-4" aria-hidden />
                        Excluir
                      </button>
                    )}
                  </div>
                </td>
              </tr>
            ))}
            {ads.length === 0 && (
              <tr>
                <td className="px-4 py-10 text-center text-slate-500" colSpan={7}>
                  Nenhum anuncio carregado ainda.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {editingAd && form && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/40 px-4 py-6">
          <form
            onSubmit={handleEditSubmit}
            className="w-full max-w-2xl rounded-lg bg-white shadow-panel"
          >
            <div className="flex items-center justify-between border-b border-slate-200 px-5 py-4">
              <div>
                <h3 className="text-lg font-bold">Editar anuncio</h3>
                <p className="text-sm text-slate-500">{editingAd.id}</p>
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
              <label className="md:col-span-2">
                <span className="mb-1 block text-sm font-semibold text-slate-700">
                  Titulo
                </span>
                <input
                  className="w-full rounded border border-slate-300 px-3 py-2"
                  value={form.title}
                  onChange={(event) => updateForm('title', event.target.value)}
                  required
                />
              </label>

              <label className="md:col-span-2">
                <span className="mb-1 block text-sm font-semibold text-slate-700">
                  Descricao
                </span>
                <textarea
                  className="min-h-28 w-full rounded border border-slate-300 px-3 py-2"
                  value={form.description}
                  onChange={(event) =>
                    updateForm('description', event.target.value)
                  }
                />
              </label>

              <label>
                <span className="mb-1 block text-sm font-semibold text-slate-700">
                  Preco
                </span>
                <input
                  className="w-full rounded border border-slate-300 px-3 py-2"
                  inputMode="decimal"
                  value={form.price}
                  onChange={(event) => updateForm('price', event.target.value)}
                />
              </label>

              <label>
                <span className="mb-1 block text-sm font-semibold text-slate-700">
                  Categoria
                </span>
                <input
                  className="w-full rounded border border-slate-300 px-3 py-2"
                  value={form.category}
                  onChange={(event) =>
                    updateForm('category', event.target.value)
                  }
                />
              </label>

              <label>
                <span className="mb-1 block text-sm font-semibold text-slate-700">
                  Localizacao
                </span>
                <input
                  className="w-full rounded border border-slate-300 px-3 py-2"
                  value={form.location}
                  onChange={(event) =>
                    updateForm('location', event.target.value)
                  }
                />
              </label>

              <label className="flex items-center gap-3 rounded border border-slate-200 px-3 py-2">
                <input
                  type="checkbox"
                  checked={form.isActive}
                  onChange={(event) =>
                    updateForm('isActive', event.target.checked)
                  }
                />
                <span className="text-sm font-semibold text-slate-700">
                  Anuncio ativo
                </span>
              </label>
            </div>

            {editMutation.error && (
              <div className="mx-5 mb-4 rounded border border-rose-200 bg-rose-50 p-3 text-sm text-rose-900">
                Nao foi possivel salvar a edicao.
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
