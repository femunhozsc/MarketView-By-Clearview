import type { AdminRole } from '../types';

export function canManageAdmins(role: AdminRole) {
  return role === 'admin';
}

export function canDeleteAds(role: AdminRole) {
  return role === 'admin';
}

export function canDeleteChats(role: AdminRole) {
  return role === 'admin';
}
