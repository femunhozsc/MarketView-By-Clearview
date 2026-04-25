import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  AlertCircle,
  CheckCircle2,
  Eye,
  EyeOff,
  ImagePlus,
  Link2,
  RefreshCw,
  Save,
  Trash2,
} from 'lucide-react';
import { useMemo, useState, type FormEvent } from 'react';

import { ApiNotice } from '../components/ApiNotice';
import {
  getHomeCustomization,
  isApiConfigured,
  updateHomeCustomization,
} from '../services/api';
import type { HomeBannerSlot, HomeCustomization } from '../types';

const emptyBanners: HomeBannerSlot[] = Array.from({ length: 5 }, (_, index) => ({
  id: String(index + 1),
  title: `Banner ${index + 1}`,
  imageUrl: '',
  enabled: index === 0,
}));

const defaultForm: HomeCustomization = {
  showPromotionalBanner: true,
  welcomeGreeting: '',
  welcomeMessage: '',
  banners: emptyBanners,
  updatedAt: null,
  updatedBy: '',
};

function normalizeForm(data?: HomeCustomization): HomeCustomization {
  if (!data) return defaultForm;
  const byId = new Map(data.banners.map((banner) => [banner.id, banner]));
  return {
    ...defaultForm,
    ...data,
    banners: emptyBanners.map((fallback) => ({
      ...fallback,
      ...byId.get(fallback.id),
    })),
  };
}

function formatUpdatedAt(value: string | null) {
  if (!value) return 'Ainda nao salvo';
  return new Intl.DateTimeFormat('pt-BR', {
    dateStyle: 'short',
    timeStyle: 'short',
  }).format(new Date(value));
}

function isLikelyCloudinaryUrl(value: string) {
  return value.trim() === '' || /^https:\/\/res\.cloudinary\.com\/.+/i.test(value);
}

export function PersonalizePage() {
  const queryClient = useQueryClient();
  const [draft, setDraft] = useState<HomeCustomization | null>(null);
  const configQuery = useQuery({
    queryKey: ['home-customization'],
    queryFn: getHomeCustomization,
    enabled: isApiConfigured,
  });
  const remoteForm = useMemo(
    () => normalizeForm(configQuery.data),
    [configQuery.data],
  );
  const form = draft ?? remoteForm;
  const saveMutation = useMutation({
    mutationFn: updateHomeCustomization,
    onSuccess: (data) => {
      setDraft(null);
      queryClient.setQueryData(['home-customization'], data);
    },
  });

  const enabledBannerCount = useMemo(
    () =>
      form.banners.filter(
        (banner) => banner.enabled && banner.imageUrl.trim().length > 0,
      ).length,
    [form.banners],
  );
  const hasInvalidCloudinaryUrl = form.banners.some(
    (banner) => banner.imageUrl.trim() && !isLikelyCloudinaryUrl(banner.imageUrl),
  );
  const canSave =
    isApiConfigured && !saveMutation.isPending && !hasInvalidCloudinaryUrl;

  function updateBanner(
    id: string,
    key: keyof Pick<HomeBannerSlot, 'title' | 'imageUrl' | 'enabled'>,
    value: string | boolean,
  ) {
    setDraft((current) => {
      const next = current ?? form;
      return {
        ...next,
        banners: next.banners.map((banner) =>
          banner.id === id ? { ...banner, [key]: value } : banner,
        ),
      };
    });
  }

  function clearBanner(id: string) {
    setDraft((current) => {
      const next = current ?? form;
      return {
        ...next,
        banners: next.banners.map((banner) =>
          banner.id === id
            ? { ...banner, imageUrl: '', enabled: false }
            : banner,
        ),
      };
    });
  }

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!canSave) return;

    saveMutation.mutate({
      ...form,
      welcomeGreeting: form.welcomeGreeting.trim(),
      welcomeMessage: form.welcomeMessage.trim(),
      banners: form.banners.map((banner) => ({
        ...banner,
        title: banner.title.trim() || `Banner ${banner.id}`,
        imageUrl: banner.imageUrl.trim(),
      })),
    });
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-2">
        <div className="flex flex-wrap items-center gap-3">
          <h2 className="text-2xl font-bold text-slate-950">Personalizar</h2>
          <span className="rounded bg-emerald-50 px-3 py-1 text-xs font-bold text-emerald-700">
            Conectado ao app
          </span>
        </div>
        <p className="max-w-3xl text-sm text-slate-500">
          Controle os banners da home, a saudacao e o texto exibido abaixo do
          banner principal. Use URLs HTTPS do Cloudinary.
        </p>
      </div>

      <ApiNotice error={configQuery.error || saveMutation.error} />

      <form onSubmit={handleSubmit} className="space-y-6">
        <section className="rounded border border-slate-200 bg-white">
          <div className="flex flex-wrap items-center justify-between gap-4 border-b border-slate-200 p-5">
            <div>
              <div className="flex items-center gap-2 text-sm font-bold text-slate-950">
                <ImagePlus className="h-4 w-4 text-market-blue" />
                Banners da tela inicial
              </div>
              <p className="mt-1 text-sm text-slate-500">
                {enabledBannerCount} banner(s) ativo(s). Slots sem URL usam os
                banners padrao do app.
              </p>
            </div>
            <button
              type="button"
              onClick={() => configQuery.refetch()}
              disabled={configQuery.isFetching}
              className="inline-flex items-center gap-2 rounded border border-slate-200 px-3 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60"
            >
              <RefreshCw className="h-4 w-4" aria-hidden="true" />
              Recarregar
            </button>
          </div>

          <div className="divide-y divide-slate-100">
            {form.banners.map((banner) => {
              const urlIsValid = isLikelyCloudinaryUrl(banner.imageUrl);
              return (
                <div key={banner.id} className="grid gap-4 p-5 xl:grid-cols-[220px_1fr_auto]">
                  <div className="flex items-start gap-3">
                    <button
                      type="button"
                      onClick={() =>
                        updateBanner(banner.id, 'enabled', !banner.enabled)
                      }
                      className={`flex h-10 w-10 items-center justify-center rounded border ${
                        banner.enabled
                          ? 'border-blue-200 bg-blue-50 text-market-blue'
                          : 'border-slate-200 bg-slate-50 text-slate-500'
                      }`}
                      title={banner.enabled ? 'Desativar' : 'Ativar'}
                    >
                      {banner.enabled ? (
                        <Eye className="h-4 w-4" aria-hidden="true" />
                      ) : (
                        <EyeOff className="h-4 w-4" aria-hidden="true" />
                      )}
                    </button>
                    <div>
                      <p className="text-sm font-bold text-slate-950">
                        Slot {banner.id}
                      </p>
                      <p className="text-xs text-slate-500">
                        {banner.enabled ? 'Ativo na home' : 'Oculto no app'}
                      </p>
                    </div>
                  </div>

                  <div className="grid gap-3 md:grid-cols-[220px_1fr]">
                    <label className="block">
                      <span className="text-xs font-bold uppercase text-slate-500">
                        Nome interno
                      </span>
                      <input
                        value={banner.title}
                        onChange={(event) =>
                          updateBanner(banner.id, 'title', event.target.value)
                        }
                        className="mt-1 w-full rounded border border-slate-200 px-3 py-2 text-sm outline-none focus:border-market-blue"
                        placeholder={`Banner ${banner.id}`}
                      />
                    </label>

                    <label className="block">
                      <span className="text-xs font-bold uppercase text-slate-500">
                        URL Cloudinary
                      </span>
                      <div className="mt-1 flex items-center rounded border border-slate-200 bg-white focus-within:border-market-blue">
                        <Link2 className="ml-3 h-4 w-4 text-slate-400" aria-hidden="true" />
                        <input
                          value={banner.imageUrl}
                          onChange={(event) =>
                            updateBanner(
                              banner.id,
                              'imageUrl',
                              event.target.value,
                            )
                          }
                          className="min-w-0 flex-1 rounded px-3 py-2 text-sm outline-none"
                          placeholder="https://res.cloudinary.com/..."
                        />
                      </div>
                      {!urlIsValid && (
                        <p className="mt-1 flex items-center gap-1 text-xs font-semibold text-red-600">
                          <AlertCircle className="h-3.5 w-3.5" aria-hidden="true" />
                          Use uma URL HTTPS do Cloudinary.
                        </p>
                      )}
                    </label>
                  </div>

                  <button
                    type="button"
                    onClick={() => clearBanner(banner.id)}
                    className="inline-flex items-center justify-center gap-2 rounded border border-slate-200 px-3 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-50 xl:self-end"
                  >
                    <Trash2 className="h-4 w-4" aria-hidden="true" />
                    Limpar
                  </button>
                </div>
              );
            })}
          </div>
        </section>

        <section className="rounded border border-slate-200 bg-white p-5">
          <div className="flex items-center gap-2 text-sm font-bold text-slate-950">
            <CheckCircle2 className="h-4 w-4 text-market-blue" />
            Saudacao e texto abaixo do banner
          </div>

          <div className="mt-4 grid gap-4 lg:grid-cols-2">
            <label className="block">
              <span className="text-xs font-bold uppercase text-slate-500">
                Saudacao
              </span>
              <input
                value={form.welcomeGreeting}
                onChange={(event) =>
                  setDraft((current) => ({
                    ...(current ?? form),
                    welcomeGreeting: event.target.value,
                  }))
                }
                className="mt-1 w-full rounded border border-slate-200 px-3 py-2 text-sm outline-none focus:border-market-blue"
                placeholder="Ex.: Ola"
                maxLength={40}
              />
            </label>

            <label className="block">
              <span className="text-xs font-bold uppercase text-slate-500">
                Banner promocional
              </span>
              <select
                value={form.showPromotionalBanner ? 'show' : 'hide'}
                onChange={(event) =>
                  setDraft((current) => ({
                    ...(current ?? form),
                    showPromotionalBanner: event.target.value === 'show',
                  }))
                }
                className="mt-1 w-full rounded border border-slate-200 px-3 py-2 text-sm outline-none focus:border-market-blue"
              >
                <option value="show">Mostrar banners</option>
                <option value="hide">Ocultar banners</option>
              </select>
            </label>

            <label className="block lg:col-span-2">
              <span className="text-xs font-bold uppercase text-slate-500">
                Texto abaixo do banner
              </span>
              <textarea
                value={form.welcomeMessage}
                onChange={(event) =>
                  setDraft((current) => ({
                    ...(current ?? form),
                    welcomeMessage: event.target.value,
                  }))
                }
                className="mt-1 min-h-24 w-full resize-y rounded border border-slate-200 px-3 py-2 text-sm outline-none focus:border-market-blue"
                placeholder="Mensagem curta exibida na home."
                maxLength={180}
              />
            </label>
          </div>
        </section>

        <div className="flex flex-wrap items-center justify-between gap-3 rounded border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">
            Ultima atualizacao: {formatUpdatedAt(form.updatedAt)}
          </p>
          <button
            type="submit"
            disabled={!canSave}
            className="inline-flex items-center gap-2 rounded bg-market-blue px-4 py-2 text-sm font-bold text-white hover:bg-blue-700 disabled:cursor-not-allowed disabled:bg-slate-300"
          >
            <Save className="h-4 w-4" aria-hidden="true" />
            {saveMutation.isPending ? 'Salvando...' : 'Salvar alteracoes'}
          </button>
        </div>
      </form>
    </div>
  );
}
