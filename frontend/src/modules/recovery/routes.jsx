import React from 'react'
import { RecoveryListPage } from './pages/RecoveryListPage.jsx'
import { RecoveryPlanPage } from './pages/RecoveryPlanPage.jsx'
import { AdminRecoveryApprovalsPage } from './pages/AdminRecoveryApprovalsPage.jsx'
import { HandoverVerificationPage } from './pages/HandoverVerificationPage.jsx'
import { ProtectedRoute } from '../../shared/components/ProtectedRoute.jsx'

export const recoveryRoutes = [
  {
    path: '/recovery',
    element: (
      <ProtectedRoute allowedRoles={['Customer']}>
        <RecoveryListPage />
      </ProtectedRoute>
    )
  },
  {
    path: '/recovery/:id',
    element: (
      <ProtectedRoute allowedRoles={['Customer', 'Admin']}>
        <RecoveryPlanPage />
      </ProtectedRoute>
    )
  },
  {
    path: '/verify-handover/:id',
    element: <HandoverVerificationPage />
  },
  {
    path: '/admin/recovery',
    element: (
      <ProtectedRoute allowedRoles={['Admin']}>
        <AdminRecoveryApprovalsPage />
      </ProtectedRoute>
    )
  }
]
