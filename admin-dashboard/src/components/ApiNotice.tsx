import { ServerCog } from 'lucide-react';

import { isApiConfigured } from '../services/api';

type ApiNoticeProps = {
  error?: unknown;
};

type ApiResponseError = {
  response?: {
    status?: number;
    data?: unknown;
  };
};

function getErrorDetail(error: unknown) {
  if (!error || typeof error !== 'object') {
    return null;
  }

  const response = (error as ApiResponseError).response;
  const status = response?.status;
  const data = response?.data;

  const apiMessage =
    data && typeof data === 'object' && 'error' in data
      ? String((data as { error?: unknown }).error)
      : null;

  if (status === 401) {
    return 'Sua sessao expirou ou o login nao enviou um token valido. Entre novamente e tente salvar.';
  }

  if (status === 403) {
    return 'Seu usuario nao tem permissao de administrador para salvar estas alteracoes.';
  }

  if (status === 404) {
    return 'A rota administrativa ainda nao foi encontrada no backend publicado. Publique novamente as Firebase Functions.';
  }

  if (status) {
    return `A API respondeu com erro ${status}${apiMessage ? `: ${apiMessage}` : '.'}`;
  }

  if (error instanceof Error && error.message) {
    return error.message;
  }

  return 'Nao foi possivel chamar o backend administrativo agora.';
}

export function ApiNotice({ error }: ApiNoticeProps) {
  if (isApiConfigured && !error) return null;

  const title = isApiConfigured
    ? 'Falha ao chamar backend administrativo'
    : 'Backend administrativo pendente';
  const message = isApiConfigured
    ? getErrorDetail(error)
    : 'Configure `VITE_API_BASE_URL` quando os endpoints seguros estiverem publicados. O painel ja esta preparado para enviar o token do Firebase em cada chamada.';

  return (
    <div className="mb-4 flex gap-3 rounded border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900">
      <ServerCog className="mt-0.5 h-5 w-5 flex-none" aria-hidden="true" />
      <div>
        <p className="font-semibold">{title}</p>
        <p>{message}</p>
      </div>
    </div>
  );
}
