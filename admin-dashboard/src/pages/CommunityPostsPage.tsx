import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Edit3, Save, Trash2, X } from 'lucide-react';
import { useState, type FormEvent } from 'react';

import { ApiNotice } from '../components/ApiNotice';
import {
  getCommunityPosts,
  isApiConfigured,
  removeCommunityPost,
  updateCommunityPost,
} from '../services/api';
import type { CommunityPostSummary } from '../types';
import { formatDate } from '../utils/formatters';

type CommunityPostForm = {
  content: string;
  type: string;
  imageLabel: string;
};

function formFromPost(post: CommunityPostSummary): CommunityPostForm {
  return {
    content: post.content,
    type: post.type,
    imageLabel: post.imageLabel,
  };
}

export function CommunityPostsPage() {
  const queryClient = useQueryClient();
  const [editingPost, setEditingPost] = useState<CommunityPostSummary | null>(
    null,
  );
  const [form, setForm] = useState<CommunityPostForm | null>(null);

  const postsQuery = useQuery({
    queryKey: ['admin-community-posts'],
    queryFn: () => getCommunityPosts(),
    enabled: isApiConfigured,
  });

  const editMutation = useMutation({
    mutationFn: ({
      postId,
      data,
    }: {
      postId: string;
      data: CommunityPostForm;
    }) => updateCommunityPost(postId, data),
    onSuccess: () => {
      setEditingPost(null);
      setForm(null);
      queryClient.invalidateQueries({ queryKey: ['admin-community-posts'] });
    },
  });

  const removeMutation = useMutation({
    mutationFn: (postId: string) => removeCommunityPost(postId),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ['admin-community-posts'] }),
  });

  const posts = postsQuery.data?.data ?? [];

  function openEditor(post: CommunityPostSummary) {
    setEditingPost(post);
    setForm(formFromPost(post));
  }

  function closeEditor() {
    if (editMutation.isPending) return;
    setEditingPost(null);
    setForm(null);
  }

  function updateForm<K extends keyof CommunityPostForm>(
    key: K,
    value: CommunityPostForm[K],
  ) {
    setForm((current) => (current ? { ...current, [key]: value } : current));
  }

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!editingPost || !form) return;
    editMutation.mutate({
      postId: editingPost.id,
      data: {
        content: form.content.trim(),
        type: form.type.trim() || 'aviso',
        imageLabel: form.imageLabel.trim(),
      },
    });
  }

  return (
    <section>
      <div className="mb-6">
        <h2 className="text-2xl font-bold">Comunidade</h2>
        <p className="text-sm text-slate-500">
          Edicao e exclusao de publicacoes da comunidade.
        </p>
      </div>

      <ApiNotice error={postsQuery.error} />

      <div className="overflow-hidden rounded-lg border border-slate-200 bg-white">
        <table className="w-full min-w-[900px] text-left text-sm">
          <thead className="bg-slate-50 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">Publicacao</th>
              <th className="px-4 py-3">Autor</th>
              <th className="px-4 py-3">Tipo</th>
              <th className="px-4 py-3">Interacoes</th>
              <th className="px-4 py-3">Criada em</th>
              <th className="px-4 py-3">Acoes</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {posts.map((post) => (
              <tr key={post.id} className="hover:bg-slate-50">
                <td className="px-4 py-3">
                  <p className="line-clamp-2 font-semibold">{post.content}</p>
                  {post.imageUrl && (
                    <p className="text-xs text-slate-500">
                      Imagem: {post.imageLabel || 'sem legenda'}
                    </p>
                  )}
                </td>
                <td className="px-4 py-3">
                  <p>{post.authorName}</p>
                  <p className="text-xs text-slate-500">{post.authorType}</p>
                </td>
                <td className="px-4 py-3">{post.type}</td>
                <td className="px-4 py-3">
                  {post.likeCount} curtidas · {post.commentCount} comentarios
                </td>
                <td className="px-4 py-3">{formatDate(post.createdAt)}</td>
                <td className="px-4 py-3">
                  <div className="flex gap-2">
                    <button
                      type="button"
                      onClick={() => openEditor(post)}
                      className="inline-flex items-center gap-2 rounded border border-slate-200 px-3 py-1.5 font-semibold text-slate-700 hover:bg-slate-50"
                    >
                      <Edit3 className="h-4 w-4" aria-hidden />
                      Editar
                    </button>
                    <button
                      type="button"
                      onClick={() => removeMutation.mutate(post.id)}
                      className="inline-flex items-center gap-2 rounded border border-rose-200 px-3 py-1.5 font-semibold text-rose-700 hover:bg-rose-50"
                    >
                      <Trash2 className="h-4 w-4" aria-hidden />
                      Excluir
                    </button>
                  </div>
                </td>
              </tr>
            ))}
            {posts.length === 0 && (
              <tr>
                <td className="px-4 py-10 text-center text-slate-500" colSpan={6}>
                  Nenhuma publicacao carregada ainda.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {editingPost && form && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/40 px-4 py-6">
          <form
            onSubmit={handleSubmit}
            className="w-full max-w-2xl rounded-lg bg-white shadow-panel"
          >
            <div className="flex items-center justify-between border-b border-slate-200 px-5 py-4">
              <div>
                <h3 className="text-lg font-bold">Editar publicacao</h3>
                <p className="text-sm text-slate-500">{editingPost.id}</p>
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
                  Conteudo
                </span>
                <textarea
                  className="min-h-32 w-full rounded border border-slate-300 px-3 py-2"
                  value={form.content}
                  onChange={(event) => updateForm('content', event.target.value)}
                  required
                />
              </label>
              <label>
                <span className="mb-1 block text-sm font-semibold text-slate-700">
                  Tipo
                </span>
                <select
                  className="w-full rounded border border-slate-300 px-3 py-2"
                  value={form.type}
                  onChange={(event) => updateForm('type', event.target.value)}
                >
                  <option value="aviso">aviso</option>
                  <option value="flyer">flyer</option>
                  <option value="promocao">promocao</option>
                </select>
              </label>
              <label>
                <span className="mb-1 block text-sm font-semibold text-slate-700">
                  Legenda da imagem
                </span>
                <input
                  className="w-full rounded border border-slate-300 px-3 py-2"
                  value={form.imageLabel}
                  onChange={(event) =>
                    updateForm('imageLabel', event.target.value)
                  }
                />
              </label>
            </div>

            {editMutation.error && (
              <div className="mx-5 mb-4 rounded border border-rose-200 bg-rose-50 p-3 text-sm text-rose-900">
                Nao foi possivel salvar a publicacao.
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
