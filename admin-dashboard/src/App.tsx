import { Navigate, Route, Routes } from 'react-router-dom';

import { DashboardLayout } from './pages/DashboardLayout';
import { LoginPage } from './pages/LoginPage';
import { ActivitiesPage } from './pages/ActivitiesPage';
import { AdsPage } from './pages/AdsPage';
import { ChatsPage } from './pages/ChatsPage';
import { CommunityPostsPage } from './pages/CommunityPostsPage';
import { OverviewPage } from './pages/OverviewPage';
import { SupportPage } from './pages/SupportPage';
import { UsersPage } from './pages/UsersPage';
import { PermissionGuard } from './components/PermissionGuard';

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        path="/"
        element={
          <PermissionGuard>
            <DashboardLayout />
          </PermissionGuard>
        }
      >
        <Route index element={<OverviewPage />} />
        <Route path="chats" element={<ChatsPage />} />
        <Route path="support" element={<SupportPage />} />
        <Route path="community" element={<CommunityPostsPage />} />
        <Route path="ads" element={<AdsPage />} />
        <Route path="users" element={<UsersPage />} />
        <Route path="activities" element={<ActivitiesPage />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
