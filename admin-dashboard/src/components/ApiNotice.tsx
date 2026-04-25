import { ServerCog } from 'lucide-react';

import { isApiConfigured } from '../services/api';

type ApiNoticeProps = {
  error?: unknown;
};

export function ApiNotice({ error }: ApiNoticeProps) {
  if (isApiConfigured && !error) return null;

  return (
    <div className="mb-4 flex gap-3 rounded border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900">
      <ServerCog className="mt-0.5 h-5 w-5 flex-none" aria-hidden="true" />
      <div>
        <p className="font-semibold">Backend administrativo pendente</p>
        <p>
          Configure `VITE_API_BASE_URL` quando os endpoints seguros estiverem
          publicados. O painel ja esta preparado para enviar o token do Firebase
          em cada chamada.
        </p>
      </div>
    </div>
  );
}
