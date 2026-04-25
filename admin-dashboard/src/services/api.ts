import axios from 'axios';

import { auth } from './firebase';
import type {
  AdSummary,
  AuditLog,
  ChatMessage,
  ChatSummary,
  CommunityPostSummary,
  DashboardSummary,
  HomeCustomization,
  PageResponse,
  SupportDashboard,
  SupportChatSummary,
  SupportMessage,
  UserSummary,
} from '../types';

export const apiBaseUrl = import.meta.env.VITE_API_BASE_URL as
  | string
  | undefined;

export const isApiConfigured = Boolean(apiBaseUrl);

export const api = axios.create({
  baseURL: apiBaseUrl,
  timeout: 20_000,
});

api.interceptors.request.use(async (config) => {
  if (auth?.currentUser) {
    const token = await auth.currentUser.getIdToken();
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

export async function getDashboardSummary() {
  const response = await api.get<DashboardSummary>('/admin/summary');
  return response.data;
}

export async function getHomeCustomization() {
  const response = await api.get<HomeCustomization>('/admin/home-customization');
  return response.data;
}

export async function updateHomeCustomization(data: HomeCustomization) {
  const response = await api.patch<HomeCustomization>(
    '/admin/home-customization',
    data,
  );
  return response.data;
}

export async function getChats(page = 1) {
  const response = await api.get<PageResponse<ChatSummary>>('/admin/chats', {
    params: { page, limit: 25 },
  });
  return response.data;
}

export async function getChatMessages(chatId: string) {
  const response = await api.get<{ messages: ChatMessage[] }>(
    `/admin/chats/${chatId}/messages`,
  );
  return response.data.messages;
}

export async function getSupportChats(page = 1, status = 'open') {
  const response = await api.get<PageResponse<SupportChatSummary>>(
    '/admin/support',
    {
      params: { page, limit: 25, status },
    },
  );
  return response.data;
}

export async function getSupportDashboard() {
  const response = await api.get<SupportDashboard>('/admin/support/dashboard');
  return response.data;
}

export async function getSupportMessages(supportChatId: string) {
  const response = await api.get<{ messages: SupportMessage[] }>(
    `/admin/support/${supportChatId}/messages`,
  );
  return response.data.messages;
}

export async function sendSupportMessage(supportChatId: string, text: string) {
  const response = await api.post<SupportMessage>(
    `/admin/support/${supportChatId}/messages`,
    { text },
  );
  return response.data;
}

export async function closeSupportChat(
  supportChatId: string,
  data: { resolutionOutcome: 'resolved' | 'unresolved'; resolutionFeedback: string },
) {
  const response = await api.patch<SupportChatSummary>(
    `/admin/support/${supportChatId}/close`,
    data,
  );
  return response.data;
}

export async function getAds(page = 1) {
  const response = await api.get<PageResponse<AdSummary>>('/admin/ads', {
    params: { page, limit: 25 },
  });
  return response.data;
}

export async function updateAd(adId: string, data: Partial<AdSummary>) {
  const response = await api.patch<AdSummary>(`/admin/ads/${adId}`, data);
  return response.data;
}

export async function removeAd(adId: string, reason: string) {
  const response = await api.delete<{ message: string }>(`/admin/ads/${adId}`, {
    data: { reason },
    headers: { 'X-Admin-Action': 'remove_ad' },
  });
  return response.data;
}

export async function getUsers(page = 1) {
  const response = await api.get<PageResponse<UserSummary>>('/admin/users', {
    params: { page, limit: 25 },
  });
  return response.data;
}

export async function updateUser(userId: string, data: Partial<UserSummary>) {
  const response = await api.patch<UserSummary>(`/admin/users/${userId}`, data);
  return response.data;
}

export async function getActivities(page = 1) {
  const response = await api.get<PageResponse<AuditLog>>('/admin/activities', {
    params: { page, limit: 25 },
  });
  return response.data;
}

export async function getCommunityPosts(page = 1) {
  const response = await api.get<PageResponse<CommunityPostSummary>>(
    '/admin/community-posts',
    {
      params: { page, limit: 25 },
    },
  );
  return response.data;
}

export async function updateCommunityPost(
  postId: string,
  data: Pick<CommunityPostSummary, 'content' | 'type' | 'imageLabel'>,
) {
  const response = await api.patch<CommunityPostSummary>(
    `/admin/community-posts/${postId}`,
    data,
  );
  return response.data;
}

export async function removeCommunityPost(postId: string) {
  const response = await api.delete<{ message: string }>(
    `/admin/community-posts/${postId}`,
  );
  return response.data;
}
