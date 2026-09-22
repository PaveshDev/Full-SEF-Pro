import React from 'react'
import { PartnerRecommendationsPage } from './pages/PartnerRecommendationsPage.jsx'
import { CustomerPartnerMatchingPage } from './pages/CustomerPartnerMatchingPage.jsx'
import { AdminPartnersPage } from './pages/AdminPartnersPage.jsx'
import { PartnerDashboardPage } from './pages/PartnerDashboardPage.jsx'
import { ProtectedRoute } from '../../shared/components/ProtectedRoute.jsx'

export const partnersRoutes = [
  {
    path: '/partner',
    element: (
      <ProtectedRoute allowedRoles={['Partner', 'Admin']}>
        <PartnerDashboardPage />
      </ProtectedRoute>
    )
  },
  {
    path: '/matching-partners',
    element: (
      <ProtectedRoute allowedRoles={['Customer', 'Admin']}>
        <CustomerPartnerMatchingPage />
      </ProtectedRoute>
    )
  },
  {
    path: '/matching-partners/:id',
    element: (
      <ProtectedRoute allowedRoles={['Customer', 'Admin']}>
        <CustomerPartnerMatchingPage />
      </ProtectedRoute>
    )
  },
  {
    path: '/recovery/:id/partners',
    element: (
      <ProtectedRoute allowedRoles={['Customer', 'Admin']}>
        <CustomerPartnerMatchingPage />
      </ProtectedRoute>
    )
  },
  {
    path: '/admin/partners',
    element: (
      <ProtectedRoute allowedRoles={['Admin']}>
        <AdminPartnersPage />
      </ProtectedRoute>
    )
  }
]
