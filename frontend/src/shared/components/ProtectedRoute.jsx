import React from 'react'
import { Navigate } from 'react-router'
import { useAuth } from '../context/AuthContext.jsx'
import { AppLayout } from '../layouts/AppLayout.jsx'

export function ProtectedRoute({ children, allowedRoles }) {
  const { user, role, loading } = useAuth()

  if (loading) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100vh' }}>
        <p style={{ color: 'var(--text-muted)' }}>Loading LoopWorth...</p>
      </div>
    )
  }

  if (!user) {
    return <Navigate to="/login" replace />
  }

  if (allowedRoles && !allowedRoles.includes(role)) {
    // Redirect to user's home dashboard
    if (role === 'Admin') return <Navigate to="/admin" replace />
    if (role === 'CollectionAgent') return <Navigate to="/agent" replace />
    return <Navigate to="/dashboard" replace />
  }

  return <AppLayout>{children}</AppLayout>
}
