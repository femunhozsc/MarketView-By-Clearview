import {
  BadgeInfo,
  ImagePlus,
  MessageCircleMore,
  MonitorSmartphone,
  Sparkles,
  TextCursorInput,
} from 'lucide-react';

function BannerSlot({
  title,
  description,
  active = false,
}: {
  title: string;
  description: string;
  active?: boolean;
}) {
  return (
    <div
      className={`rounded border p-4 ${
        active
          ? 'border-blue-200 bg-blue-50'
          : 'border-slate-200 bg-white'
      }`}
    >
      <div className="flex items-center gap-3">
        <div
          className={`flex h-10 w-10 items-center justify-center rounded ${
            active ? 'bg-market-blue text-white' : 'bg-slate-100 text-slate-500'
          }`}
        >
          <ImagePlus className="h-5 w-5" aria-hidden="true" />
        </div>
        <div>
          <p className="text-sm font-bold text-slate-950">{title}</p>
          <p className="text-xs text-slate-500">{description}</p>
        </div>
      </div>
    </div>
  );
}

function FieldPreview({
  label,
  value,
}: {
  label: string;
  value: string;
}) {
  return (
    <div className="rounded border border-slate-200 bg-slate-50 p-4">
      <p className="text-xs font-semibold uppercase tracking-[0.14em] text-slate-500">
        {label}
      </p>
      <p className="mt-2 text-sm font-bold text-slate-950">{value}</p>
    </div>
  );
}

function MiniMetric({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded border border-white/15 bg-white/10 p-3 text-white">
      <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-white/70">
        {label}
      </p>
      <p className="mt-1 text-sm font-bold">{value}</p>
    </div>
  );
}

export function PersonalizePage() {
  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-2">
        <div className="flex flex-wrap items-center gap-3">
          <h2 className="text-2xl font-bold text-slate-950">Personalizar</h2>
          <span className="rounded bg-blue-50 px-3 py-1 text-xs font-bold text-market-blue">
            Somente visual
          </span>
        </div>
        <p className="max-w-3xl text-sm text-slate-500">
          Area visual para preparar os controles de banners, saudacao e texto
          abaixo do banner da tela inicial do app.
        </p>
      </div>

      <div className="grid gap-6 xl:grid-cols-[1.1fr_0.9fr]">
        <section className="rounded border border-slate-200 bg-white">
          <div className="flex items-center justify-between gap-4 border-b border-slate-200 p-5">
            <div>
              <div className="flex items-center gap-2 text-sm font-bold text-slate-950">
                <MonitorSmartphone className="h-4 w-4 text-market-blue" />
                Previa da tela inicial
              </div>
              <p className="mt-1 text-sm text-slate-500">
                Uma simulacao simples do que o usuario veria na home.
              </p>
            </div>
            <BadgeInfo className="h-5 w-5 text-slate-400" aria-hidden="true" />
          </div>

          <div className="p-5">
            <div className="overflow-hidden rounded border border-slate-200 bg-slate-100">
              <div className="bg-gradient-to-br from-blue-700 via-sky-600 to-cyan-500 p-6 text-white">
                <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-[0.16em] text-white/75">
                  <Sparkles className="h-4 w-4" aria-hidden="true" />
                  Home MarketView
                </div>
                <h3 className="mt-5 text-3xl font-black">Ola, &lt;usuario&gt;</h3>
                <p className="mt-3 max-w-xl text-sm leading-6 text-white/85">
                  Encontre anuncios, lojas e servicos perto de voce com uma
                  experiencia mais personalizada.
                </p>

                <div className="mt-8 rounded border border-white/15 bg-white/10 p-4">
                  <div className="flex items-center gap-2 text-sm font-bold">
                    <ImagePlus className="h-4 w-4" aria-hidden="true" />
                    Banner principal da tela inicial
                  </div>
                  <div className="mt-4 grid gap-3 md:grid-cols-3">
                    <MiniMetric label="Status" value="Ativo" />
                    <MiniMetric label="Formato" value="Principal" />
                    <MiniMetric label="Prioridade" value="Alta" />
                  </div>
                </div>

                <div className="mt-4 rounded border border-white/15 bg-white/10 p-4">
                  <div className="flex items-center gap-2 text-sm font-bold">
                    <TextCursorInput className="h-4 w-4" aria-hidden="true" />
                    Texto abaixo do banner
                  </div>
                  <p className="mt-2 text-sm leading-6 text-white/85">
                    Esse espaco pode receber uma frase curta, uma campanha ou um
                    aviso importante para quem abre o app.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </section>

        <aside className="space-y-6">
          <section className="rounded border border-slate-200 bg-white p-5">
            <div className="flex items-center gap-2 text-sm font-bold text-slate-950">
              <ImagePlus className="h-4 w-4 text-market-blue" />
              Banners da home
            </div>
            <p className="mt-1 text-sm text-slate-500">
              Espacos visuais para futuramente trocar, ordenar e ativar banners.
            </p>
            <div className="mt-4 space-y-3">
              <BannerSlot
                active
                title="Banner principal"
                description="Destaque maior no topo da tela inicial."
              />
              <BannerSlot
                title="Banner secundario"
                description="Area para campanhas e comunicados."
              />
              <BannerSlot
                title="Banner promocional"
                description="Espaco para ofertas, eventos ou novidades."
              />
            </div>
          </section>

          <section className="rounded border border-slate-200 bg-white p-5">
            <div className="flex items-center gap-2 text-sm font-bold text-slate-950">
              <MessageCircleMore className="h-4 w-4 text-market-blue" />
              Saudacao e texto
            </div>
            <p className="mt-1 text-sm text-slate-500">
              Campos visuais para a mensagem de abertura da home.
            </p>
            <div className="mt-4 space-y-3">
              <FieldPreview label="Saudacao" value="Ola, <usuario>" />
              <FieldPreview
                label="Texto abaixo do banner"
                value="Encontre anuncios, lojas e servicos perto de voce."
              />
            </div>
          </section>
        </aside>
      </div>
    </div>
  );
}
