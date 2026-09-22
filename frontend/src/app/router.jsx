import React from 'react'
import { createBrowserRouter, Navigate } from 'react-router'
import { HomePage } from '../modules/public/HomePage.jsx'
import { LoginPage } from '../modules/public/LoginPage.jsx'
import { RegisterPage } from '../modules/public/RegisterPage.jsx'
import { CustomerDashboard } from '../modules/dashboard/CustomerDashboard.jsx'
import { AdminDashboard } from '../modules/dashboard/AdminDashboard.jsx'
import { CollectionAgentDashboard } from '../modules/dashboard/CollectionAgentDashboard.jsx'
import { AIWorkflowHistoryPage } from '../modules/workflows/AIWorkflowHistoryPage.jsx'
import { ProfilePage } from '../modules/customer/pages/ProfilePage.jsx'
import { ProtectedRoute } from '../shared/components/ProtectedRoute.jsx'

import { itemsRoutes } from '../modules/items/routes.jsx'
import { recoveryRoutes } from '../modules/recovery/routes.jsx'
import { partnersRoutes } from '../modules/partners/routes.jsx'
import { collectionsRoutes } from '../modules/collections/routes.jsx'

export const router = createBrowserRouter([
  { path: '/', element: <HomePage /> },
  { path: '/login', element: <LoginPage /> },
  { path: '/register', element: <RegisterPage /> },
  {
    path: '/profile',
    element: (
      <ProtectedRoute allowedRoles={['Customer', 'Admin', 'CollectionAgent', 'Partner']}>
        <ProfilePage />
      </ProtectedRoute>
    )
  },
  {
    path: '/dashboard',
    element: (
      <ProtectedRoute allowedRoles={['Customer']}>
        <CustomerDashboard />
      </ProtectedRoute>
    )
  },
  {
    path: '/admin',
    element: (
      <ProtectedRoute allowedRoles={['Admin']}>
        <AdminDashboard />
      </ProtectedRoute>
    )
  },
  {
    path: '/admin/workflows',
    element: (
      <ProtectedRoute allowedRoles={['Admin']}>
        <AIWorkflowHistoryPage />
      </ProtectedRoute>
    )
  },
  {
    path: '/agent',
    element: (
      <ProtectedRoute allowedRoles={['CollectionAgent']}>
        <CollectionAgentDashboard />
      </ProtectedRoute>
    )
  },
  ...itemsRoutes,
  ...recoveryRoutes,
  ...partnersRoutes,
  ...collectionsRoutes,
  { path: '*', element: <Navigate to="/" replace /> }
])
