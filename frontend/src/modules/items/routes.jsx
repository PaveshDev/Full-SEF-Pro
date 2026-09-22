import React from 'react'
import { CustomerItemsPage } from './pages/CustomerItemsPage.jsx'
import { AddItemPage } from './pages/AddItemPage.jsx'
import { ItemDetailsPage } from './pages/ItemDetailsPage.jsx'
import { ProtectedRoute } from '../../shared/components/ProtectedRoute.jsx'

export const itemsRoutes = [
  {
    path: '/items',
    element: (
      <ProtectedRoute allowedRoles={['Customer']}>
        <CustomerItemsPage />
      </ProtectedRoute>
    )
  },
  {
    path: '/items/new',
    element: (
      <ProtectedRoute allowedRoles={['Customer']}>
        <AddItemPage />
      </ProtectedRoute>
    )
  },
  {
    path: '/items/:id',
    element: (
      <ProtectedRoute allowedRoles={['Customer', 'Admin']}>
        <ItemDetailsPage />
      </ProtectedRoute>
    )
  }
]
