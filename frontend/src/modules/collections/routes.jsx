import React from 'react'
import { CustomerCollectionsPage } from './pages/CustomerCollectionsPage.jsx'
import { SchedulePickupPage } from './pages/SchedulePickupPage.jsx'
import { AdminCollectionsPage } from './pages/AdminCollectionsPage.jsx'
import { CollectionAgentJobsPage } from './pages/CollectionAgentJobsPage.jsx'
import { AdminCollectionAgentsPage } from './pages/AdminCollectionAgentsPage.jsx'
import { ProtectedRoute } from '../../shared/components/ProtectedRoute.jsx'

export const collectionsRoutes = [
  {
    path: '/collections',
    element: (
      <ProtectedRoute allowedRoles={['Customer']}>
        <CustomerCollectionsPage />
      </ProtectedRoute>
    )
  },
  {
    path: '/recovery/:id/schedule',
    element: (
      <ProtectedRoute allowedRoles={['Customer']}>
        <SchedulePickupPage />
      </ProtectedRoute>
    )
  },
  {
    path: '/admin/collections',
    element: (
      <ProtectedRoute allowedRoles={['Admin']}>
        <AdminCollectionsPage />
      </ProtectedRoute>
    )
  },
  {
    path: '/admin/collection-agents',
    element: (
      <ProtectedRoute allowedRoles={['Admin']}>
        <AdminCollectionAgentsPage />
      </ProtectedRoute>
    )
  },
  {
    path: '/agent/jobs',
    element: (
      <ProtectedRoute allowedRoles={['CollectionAgent']}>
        <CollectionAgentJobsPage />
      </ProtectedRoute>
    )
  }
]
