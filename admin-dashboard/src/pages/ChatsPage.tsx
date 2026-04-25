import { useQuery } from '@tanstack/react-query';
import { Eye, MessageSquareText } from 'lucide-react';
import { useState } from 'react';
import clsx from 'clsx';

import { ApiNotice } from '../components/ApiNotice';
import { StatusBadge } from '../components/StatusBadge';
import { getChatMessages, getChats, isApiConfigured } from '../services/api';
import { formatDate } from '../utils/formatters';

function apiErrorDetail(error: unknown) {
  const responseData = (error as { response?: { data?: unknown } })?.response
    ?.data;
  if (responseData && typeof responseData === 'object') {
    const detail = (responseData as { detail?: unknown; error?: unknown }).detail;
    const code = (responseData as { detail?: unknown; error?: unknown }).error;
    if (typeof detail === 'string' && detail.trim()) return detail;
    if (typeof code === 'string' && code.trim()) return code;
  }
  return 'Confira o terminal do Firebase Functions para ver o erro detalhado.';
}

export function ChatsPage() {
  const [selectedChatId, setSelectedChatId] = useState<string | null>(null);
  const chatsQuery = useQuery({
    queryKey: ['admin-chats'],
    queryFn: () => getChats(),
    enabled: isApiConfigured,
  });
  const messagesQuery = useQuery({
    queryKey: ['admin-chat-messages', selectedChatId],
    queryFn: () => getChatMessages(selectedChatId ?? ''),
    enabled: isApiConfigured && Boolean(selectedChatId),
  });
  const chats = chatsQuery.data?.data ?? [];
  const selectedChat = chats.find((chat) => chat.id === selectedChatId) ?? null;

  function selectChat(chatId: string) {
    setSelectedChatId(chatId);
  }

  return (
    <section>
      <div className="mb-6 flex items-center justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold">Chats</h2>
          <p className="text-sm text-slate-500">
            Leitura controlada para suporte, denuncia e seguranca.
          </p>
        </div>
      </div>

      <ApiNotice error={chatsQuery.error} />

      <div className="grid gap-4 xl:grid-cols-[1fr_420px]">
        <div className="overflow-hidden rounded-lg border border-slate-200 bg-white">
          <table className="w-full min-w-[760px] text-left text-sm">
            <thead className="bg-slate-50 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">Conversa</th>
                <th className="px-4 py-3">Anuncio</th>
                <th className="px-4 py-3">Ultima mensagem</th>
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3">Acoes</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {chats.map((chat) => (
                <tr
                  key={chat.id}
                  onClick={() => selectChat(chat.id)}
                  className={clsx(
                    'cursor-pointer hover:bg-slate-50',
                    selectedChatId === chat.id && 'bg-blue-50/70',
                  )}
                  tabIndex={0}
                  onKeyDown={(event) => {
                    if (event.key === 'Enter' || event.key === ' ') {
                      event.preventDefault();
                      selectChat(chat.id);
                    }
                  }}
                >
                  <td className="px-4 py-3">
                    <p className="font-semibold">{chat.buyerName}</p>
                    <p className="text-xs text-slate-500">
                      com {chat.sellerName}
                    </p>
                  </td>
                  <td className="px-4 py-3">{chat.adTitle || chat.adId}</td>
                  <td className="px-4 py-3">
                    <p className="line-clamp-1">{chat.lastMessage}</p>
                    <p className="text-xs text-slate-500">
                      {formatDate(chat.lastMessageTime)}
                    </p>
                  </td>
                  <td className="px-4 py-3">
                    <StatusBadge label={chat.status} tone="blue" />
                  </td>
                  <td className="px-4 py-3">
                    <button
                      type="button"
                      onClick={(event) => {
                        event.stopPropagation();
                        selectChat(chat.id);
                      }}
                      className={clsx(
                        'inline-flex items-center gap-2 rounded border px-3 py-1.5 font-semibold',
                        selectedChatId === chat.id
                          ? 'border-blue-200 bg-blue-100 text-market-blue'
                          : 'border-slate-200 text-slate-700 hover:bg-slate-50',
                      )}
                    >
                      <Eye className="h-4 w-4" aria-hidden />
                      {selectedChatId === chat.id ? 'Aberto' : 'Ver'}
                    </button>
                  </td>
                </tr>
              ))}
              {chats.length === 0 && (
                <tr>
                  <td className="px-4 py-10 text-center text-slate-500" colSpan={5}>
                    Nenhum chat carregado ainda.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        <aside className="rounded-lg border border-slate-200 bg-white p-4">
          <div className="mb-4 flex items-start gap-2">
            <MessageSquareText
              className="mt-0.5 h-5 w-5 flex-none text-market-blue"
              aria-hidden
            />
            <div>
              <h3 className="font-bold">Mensagens</h3>
              {selectedChat && (
                <p className="text-sm text-slate-500">
                  {selectedChat.buyerName} com {selectedChat.sellerName}
                </p>
              )}
            </div>
          </div>
          {!selectedChatId && (
            <p className="text-sm text-slate-500">
              Selecione um chat para visualizar. O backend deve registrar
              auditoria em cada abertura.
            </p>
          )}
          {selectedChatId && messagesQuery.isLoading && (
            <p className="text-sm text-slate-500">Carregando mensagens...</p>
          )}
          {selectedChatId && messagesQuery.isError && (
            <div className="rounded border border-rose-200 bg-rose-50 p-3 text-sm text-rose-900">
              <p className="font-semibold">
                Nao foi possivel carregar as mensagens deste chat.
              </p>
              <p className="mt-1 text-xs">{apiErrorDetail(messagesQuery.error)}</p>
            </div>
          )}
          {selectedChatId &&
            !messagesQuery.isLoading &&
            !messagesQuery.isError &&
            (messagesQuery.data ?? []).length === 0 && (
              <p className="text-sm text-slate-500">
                Este chat ainda nao tem mensagens carregadas.
              </p>
            )}
          <div className="space-y-3">
            {(messagesQuery.data ?? []).map((message) => (
              <div
                key={message.id}
                className="rounded border border-slate-100 bg-slate-50 p-3"
              >
                <div className="mb-1 flex items-center justify-between gap-2">
                  <strong className="text-sm">{message.senderName}</strong>
                  <span className="text-xs text-slate-500">
                    {formatDate(message.createdAt)}
                  </span>
                </div>
                <p className="text-sm text-slate-700">
                  {message.text || `[${message.type}]`}
                </p>
              </div>
            ))}
          </div>
        </aside>
      </div>
    </section>
  );
}
