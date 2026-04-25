import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import clsx from 'clsx';
import { BarChart3, CheckCircle2, Headset, Send, X } from 'lucide-react';
import { useState, type FormEvent } from 'react';

import { ApiNotice } from '../components/ApiNotice';
import { StatusBadge } from '../components/StatusBadge';
import {
  closeSupportChat,
  getSupportChats,
  getSupportDashboard,
  getSupportMessages,
  isApiConfigured,
  sendSupportMessage,
} from '../services/api';
import type { SupportChatSummary } from '../types';
import { formatDate } from '../utils/formatters';

type SupportTab = 'open' | 'closed';
type CloseForm = {
  outcome: 'resolved' | 'unresolved';
  feedback: string;
};

function outcomeLabel(chat: SupportChatSummary) {
  if (chat.type === 'report' && chat.status !== 'closed') return 'Denuncia';
  if (chat.status !== 'closed') return 'Aberto';
  if (chat.resolutionOutcome === 'resolved') return 'Resolvido';
  if (chat.resolutionOutcome === 'unresolved') return 'Nao resolvido';
  return 'Finalizado';
}

export function SupportPage() {
  const queryClient = useQueryClient();
  const [selectedChatId, setSelectedChatId] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<SupportTab>('open');
  const [reply, setReply] = useState('');
  const [showDashboard, setShowDashboard] = useState(false);
  const [closingChat, setClosingChat] = useState<SupportChatSummary | null>(null);
  const [closeForm, setCloseForm] = useState<CloseForm>({
    outcome: 'resolved',
    feedback: '',
  });

  const supportQuery = useQuery({
    queryKey: ['admin-support-chats', activeTab],
    queryFn: () => getSupportChats(1, activeTab),
    enabled: isApiConfigured,
  });

  const dashboardQuery = useQuery({
    queryKey: ['admin-support-dashboard'],
    queryFn: () => getSupportDashboard(),
    enabled: isApiConfigured && showDashboard,
  });

  const messagesQuery = useQuery({
    queryKey: ['admin-support-messages', selectedChatId],
    queryFn: () => getSupportMessages(selectedChatId ?? ''),
    enabled: isApiConfigured && Boolean(selectedChatId),
  });

  const sendMutation = useMutation({
    mutationFn: ({ chatId, text }: { chatId: string; text: string }) =>
      sendSupportMessage(chatId, text),
    onSuccess: () => {
      setReply('');
      queryClient.invalidateQueries({
        queryKey: ['admin-support-messages', selectedChatId],
      });
      queryClient.invalidateQueries({ queryKey: ['admin-support-chats'] });
    },
  });

  const closeMutation = useMutation({
    mutationFn: ({
      chatId,
      outcome,
      feedback,
    }: {
      chatId: string;
      outcome: 'resolved' | 'unresolved';
      feedback: string;
    }) =>
      closeSupportChat(chatId, {
        resolutionOutcome: outcome,
        resolutionFeedback: feedback,
      }),
    onSuccess: () => {
      setClosingChat(null);
      setCloseForm({ outcome: 'resolved', feedback: '' });
      setSelectedChatId(null);
      setActiveTab('closed');
      queryClient.invalidateQueries({ queryKey: ['admin-support-chats'] });
      queryClient.invalidateQueries({ queryKey: ['admin-support-dashboard'] });
    },
  });

  const chats = supportQuery.data?.data ?? [];
  const selectedChat = chats.find((chat) => chat.id === selectedChatId) ?? null;
  const isClosed = selectedChat?.status === 'closed';

  function selectTab(tab: SupportTab) {
    setActiveTab(tab);
    setSelectedChatId(null);
    setReply('');
  }

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const text = reply.trim();
    if (!selectedChatId || !text || isClosed) return;
    sendMutation.mutate({ chatId: selectedChatId, text });
  }

  function openCloseDialog(chat: SupportChatSummary) {
    setClosingChat(chat);
    setCloseForm({ outcome: 'resolved', feedback: '' });
  }

  function handleCloseSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!closingChat || !closeForm.feedback.trim()) return;
    closeMutation.mutate({
      chatId: closingChat.id,
      outcome: closeForm.outcome,
      feedback: closeForm.feedback.trim(),
    });
  }

  return (
    <section>
      <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 className="text-2xl font-bold">Suporte</h2>
          <p className="text-sm text-slate-500">
            Atendimento direto entre usuarios e equipe MarketView.
          </p>
        </div>
        <button
          type="button"
          onClick={() => setShowDashboard((value) => !value)}
          className="inline-flex items-center gap-2 rounded border border-slate-200 bg-white px-3 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-50"
        >
          <BarChart3 className="h-4 w-4" aria-hidden />
          Dashboard
        </button>
      </div>

      <ApiNotice error={supportQuery.error} />

      {showDashboard && (
        <div className="mb-4 rounded-lg border border-slate-200 bg-white p-4">
          <div className="mb-3 flex items-center justify-between gap-3">
            <div>
              <h3 className="font-bold">Chamadas finalizadas por admin</h3>
              <p className="text-sm text-slate-500">
                Ordenado de quem finalizou mais para menos.
              </p>
            </div>
            <button
              type="button"
              onClick={() => setShowDashboard(false)}
              className="rounded border border-slate-200 p-2 text-slate-600 hover:bg-slate-50"
              aria-label="Fechar dashboard"
            >
              <X className="h-4 w-4" aria-hidden />
            </button>
          </div>
          {dashboardQuery.isLoading && (
            <p className="text-sm text-slate-500">Carregando dashboard...</p>
          )}
          {dashboardQuery.data && (
            <>
              <div className="mb-4 grid gap-3 md:grid-cols-3">
                <div className="rounded border border-slate-200 p-3">
                  <p className="text-xs uppercase text-slate-500">Total</p>
                  <p className="text-2xl font-bold">{dashboardQuery.data.totalClosed}</p>
                </div>
                <div className="rounded border border-emerald-200 bg-emerald-50 p-3">
                  <p className="text-xs uppercase text-emerald-700">Resolvidos</p>
                  <p className="text-2xl font-bold text-emerald-800">
                    {dashboardQuery.data.resolved}
                  </p>
                </div>
                <div className="rounded border border-rose-200 bg-rose-50 p-3">
                  <p className="text-xs uppercase text-rose-700">Nao resolvidos</p>
                  <p className="text-2xl font-bold text-rose-800">
                    {dashboardQuery.data.unresolved}
                  </p>
                </div>
              </div>
              <div className="overflow-hidden rounded border border-slate-200">
                <table className="w-full text-left text-sm">
                  <thead className="bg-slate-50 text-xs uppercase text-slate-500">
                    <tr>
                      <th className="px-3 py-2">Admin</th>
                      <th className="px-3 py-2">Finalizadas</th>
                      <th className="px-3 py-2">Resolvidas</th>
                      <th className="px-3 py-2">Nao resolvidas</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {dashboardQuery.data.admins.map((admin) => (
                      <tr key={admin.adminUid}>
                        <td className="px-3 py-2 font-semibold">{admin.adminEmail}</td>
                        <td className="px-3 py-2">{admin.total}</td>
                        <td className="px-3 py-2">{admin.resolved}</td>
                        <td className="px-3 py-2">{admin.unresolved}</td>
                      </tr>
                    ))}
                    {dashboardQuery.data.admins.length === 0 && (
                      <tr>
                        <td className="px-3 py-6 text-center text-slate-500" colSpan={4}>
                          Nenhuma chamada finalizada ainda.
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </>
          )}
        </div>
      )}

      <div className="mb-4 inline-flex rounded border border-slate-200 bg-white p-1">
        <button
          type="button"
          onClick={() => selectTab('open')}
          className={clsx(
            'rounded px-3 py-1.5 text-sm font-semibold',
            activeTab === 'open'
              ? 'bg-blue-50 text-market-blue'
              : 'text-slate-600 hover:bg-slate-50',
          )}
        >
          Abertos
        </button>
        <button
          type="button"
          onClick={() => selectTab('closed')}
          className={clsx(
            'rounded px-3 py-1.5 text-sm font-semibold',
            activeTab === 'closed'
              ? 'bg-blue-50 text-market-blue'
              : 'text-slate-600 hover:bg-slate-50',
          )}
        >
          Finalizados
        </button>
      </div>

      <div className="grid min-h-[620px] gap-4 xl:grid-cols-[380px_1fr]">
        <aside className="overflow-hidden rounded-lg border border-slate-200 bg-white">
          <div className="border-b border-slate-200 px-4 py-3">
            <p className="text-sm font-bold">
              {activeTab === 'open' ? 'Atendimentos abertos' : 'Finalizados'}
            </p>
            <p className="text-xs text-slate-500">
              {chats.length} atendimento(s) carregado(s)
            </p>
          </div>
          <div className="max-h-[560px] overflow-y-auto">
            {chats.map((chat) => (
              <button
                key={chat.id}
                type="button"
                onClick={() => setSelectedChatId(chat.id)}
                className={clsx(
                  'block w-full border-b border-slate-100 px-4 py-3 text-left hover:bg-slate-50',
                  selectedChatId === chat.id && 'bg-blue-50/70',
                )}
              >
                <div className="mb-1 flex items-center justify-between gap-3">
                  <p className="truncate font-semibold">{chat.userName}</p>
                  <StatusBadge
                    label={outcomeLabel(chat)}
                    tone={chat.status === 'closed' ? 'slate' : 'green'}
                  />
                </div>
                <p className="truncate text-xs text-slate-500">
                  {chat.userEmail || chat.userId}
                </p>
                <p className="mt-2 line-clamp-2 text-sm text-slate-700">
                  {chat.lastMessage || chat.subject}
                </p>
                <p className="mt-1 text-xs text-slate-400">
                  {formatDate(chat.lastMessageTime || chat.createdAt)}
                </p>
              </button>
            ))}
            {chats.length === 0 && (
              <div className="px-4 py-10 text-center text-sm text-slate-500">
                Nenhum atendimento nesta aba.
              </div>
            )}
          </div>
        </aside>

        <div className="flex min-h-[620px] flex-col rounded-lg border border-slate-200 bg-white">
          <div className="flex items-start justify-between gap-3 border-b border-slate-200 px-4 py-4">
            <div className="flex items-start gap-3">
              <Headset
                className="mt-0.5 h-5 w-5 flex-none text-market-blue"
                aria-hidden
              />
              <div>
                <h3 className="font-bold">
                  {selectedChat ? selectedChat.userName : 'Atendimento'}
                </h3>
                <p className="text-sm text-slate-500">
                  {selectedChat
                    ? selectedChat.subject
                    : 'Selecione uma conversa para responder.'}
                </p>
                {selectedChat?.type === 'report' && (
                  <div className="mt-2 rounded border border-amber-200 bg-amber-50 p-2 text-xs text-amber-950">
                    <p className="font-semibold">
                      Denuncia de{' '}
                      {selectedChat.reportTargetType === 'ad'
                        ? 'anuncio'
                        : 'publicacao'}
                    </p>
                    <p>
                      Referencia: {selectedChat.reportTargetTitle || '-'} (
                      {selectedChat.reportTargetId || '-'})
                    </p>
                    <p>Motivo: {selectedChat.reportReason || '-'}</p>
                    {selectedChat.reportDetails && (
                      <p>Detalhes: {selectedChat.reportDetails}</p>
                    )}
                  </div>
                )}
                {selectedChat?.status === 'closed' && (
                  <p className="mt-1 text-xs text-slate-500">
                    Finalizado por {selectedChat.closedByEmail || '-'} em{' '}
                    {formatDate(selectedChat.closedAt)}
                  </p>
                )}
              </div>
            </div>
            {selectedChat && selectedChat.status !== 'closed' && (
              <button
                type="button"
                onClick={() => openCloseDialog(selectedChat)}
                className="inline-flex items-center gap-2 rounded border border-emerald-200 px-3 py-2 text-sm font-semibold text-emerald-700 hover:bg-emerald-50"
              >
                <CheckCircle2 className="h-4 w-4" aria-hidden />
                Finalizar
              </button>
            )}
          </div>

          {selectedChat?.status === 'closed' && (
            <div className="border-b border-slate-200 bg-slate-50 px-4 py-3 text-sm">
              <p className="font-semibold">{outcomeLabel(selectedChat)}</p>
              <p className="mt-1 text-slate-600">
                {selectedChat.resolutionFeedback || 'Sem feedback registrado.'}
              </p>
            </div>
          )}

          <div className="flex-1 space-y-3 overflow-y-auto bg-slate-50 px-4 py-4">
            {!selectedChatId && (
              <p className="text-sm text-slate-500">
                As mensagens dos usuarios aparecerao aqui.
              </p>
            )}
            {selectedChatId && messagesQuery.isLoading && (
              <p className="text-sm text-slate-500">Carregando mensagens...</p>
            )}
            {selectedChatId && messagesQuery.isError && (
              <div className="rounded border border-rose-200 bg-rose-50 p-3 text-sm text-rose-900">
                Nao foi possivel carregar este atendimento.
              </div>
            )}
            {selectedChatId &&
              !messagesQuery.isLoading &&
              !messagesQuery.isError &&
              (messagesQuery.data ?? []).length === 0 && (
                <p className="text-sm text-slate-500">
                  Este atendimento ainda nao tem mensagens.
                </p>
              )}
            {(messagesQuery.data ?? []).map((message) => {
              const isAdmin = message.senderRole === 'admin';
              return (
                <div
                  key={message.id}
                  className={clsx('flex', isAdmin ? 'justify-end' : 'justify-start')}
                >
                  <div
                    className={clsx(
                      'max-w-[78%] rounded-lg px-3 py-2 text-sm shadow-sm',
                      isAdmin
                        ? 'bg-market-blue text-white'
                        : 'border border-slate-200 bg-white text-slate-800',
                    )}
                  >
                    <div className="mb-1 flex items-center justify-between gap-3">
                      <strong className="text-xs">{message.senderName}</strong>
                      <span
                        className={clsx(
                          'text-[11px]',
                          isAdmin ? 'text-blue-100' : 'text-slate-400',
                        )}
                      >
                        {formatDate(message.createdAt)}
                      </span>
                    </div>
                    <p className="whitespace-pre-wrap">{message.text}</p>
                  </div>
                </div>
              );
            })}
          </div>

          <form
            onSubmit={handleSubmit}
            className="border-t border-slate-200 p-4"
          >
            <label className="sr-only" htmlFor="support-reply">
              Resposta do suporte
            </label>
            <div className="flex gap-2">
              <textarea
                id="support-reply"
                className="min-h-12 flex-1 resize-none rounded border border-slate-300 px-3 py-2 text-sm"
                placeholder={
                  isClosed ? 'Atendimento finalizado' : 'Digite a resposta...'
                }
                value={reply}
                disabled={!selectedChatId || isClosed || sendMutation.isPending}
                onChange={(event) => setReply(event.target.value)}
              />
              <button
                type="submit"
                disabled={
                  !selectedChatId ||
                  isClosed ||
                  !reply.trim() ||
                  sendMutation.isPending
                }
                className="inline-flex h-12 items-center gap-2 rounded bg-market-blue px-4 text-sm font-semibold text-white hover:bg-blue-700 disabled:bg-slate-300"
              >
                <Send className="h-4 w-4" aria-hidden />
                Enviar
              </button>
            </div>
            {sendMutation.error && (
              <p className="mt-2 text-sm text-rose-700">
                Nao foi possivel enviar a resposta.
              </p>
            )}
          </form>
        </div>
      </div>

      {closingChat && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/40 px-4 py-6">
          <form
            onSubmit={handleCloseSubmit}
            className="w-full max-w-lg rounded-lg bg-white shadow-panel"
          >
            <div className="flex items-center justify-between border-b border-slate-200 px-5 py-4">
              <div>
                <h3 className="text-lg font-bold">Finalizar atendimento</h3>
                <p className="text-sm text-slate-500">{closingChat.userName}</p>
              </div>
              <button
                type="button"
                onClick={() => setClosingChat(null)}
                className="rounded border border-slate-200 p-2 text-slate-600 hover:bg-slate-50"
                aria-label="Fechar"
              >
                <X className="h-4 w-4" aria-hidden />
              </button>
            </div>
            <div className="space-y-4 px-5 py-5">
              <div>
                <span className="mb-2 block text-sm font-semibold text-slate-700">
                  Resultado
                </span>
                <div className="inline-flex rounded border border-slate-200 p-1">
                  <button
                    type="button"
                    onClick={() =>
                      setCloseForm((current) => ({
                        ...current,
                        outcome: 'resolved',
                      }))
                    }
                    className={clsx(
                      'rounded px-3 py-1.5 text-sm font-semibold',
                      closeForm.outcome === 'resolved'
                        ? 'bg-emerald-50 text-emerald-700'
                        : 'text-slate-600',
                    )}
                  >
                    Resolvido
                  </button>
                  <button
                    type="button"
                    onClick={() =>
                      setCloseForm((current) => ({
                        ...current,
                        outcome: 'unresolved',
                      }))
                    }
                    className={clsx(
                      'rounded px-3 py-1.5 text-sm font-semibold',
                      closeForm.outcome === 'unresolved'
                        ? 'bg-rose-50 text-rose-700'
                        : 'text-slate-600',
                    )}
                  >
                    Nao resolvido
                  </button>
                </div>
              </div>
              <label>
                <span className="mb-1 block text-sm font-semibold text-slate-700">
                  Feedback interno
                </span>
                <textarea
                  className="min-h-28 w-full rounded border border-slate-300 px-3 py-2 text-sm"
                  value={closeForm.feedback}
                  onChange={(event) =>
                    setCloseForm((current) => ({
                      ...current,
                      feedback: event.target.value,
                    }))
                  }
                  required
                  placeholder="Ex.: Usuario orientado a atualizar o app e reenviar as imagens."
                />
              </label>
            </div>
            {closeMutation.error && (
              <p className="mx-5 mb-4 rounded border border-rose-200 bg-rose-50 p-3 text-sm text-rose-900">
                Nao foi possivel finalizar o atendimento.
              </p>
            )}
            <div className="flex justify-end gap-2 border-t border-slate-200 px-5 py-4">
              <button
                type="button"
                onClick={() => setClosingChat(null)}
                className="rounded border border-slate-200 px-4 py-2 font-semibold text-slate-700 hover:bg-slate-50"
              >
                Cancelar
              </button>
              <button
                type="submit"
                disabled={closeMutation.isPending || !closeForm.feedback.trim()}
                className="rounded bg-market-blue px-4 py-2 font-semibold text-white hover:bg-blue-700 disabled:bg-slate-300"
              >
                {closeMutation.isPending ? 'Finalizando...' : 'Finalizar'}
              </button>
            </div>
          </form>
        </div>
      )}
    </section>
  );
}
