import React from 'react'
import { Sidebar } from '../components/Sidebar.jsx'

export function AppLayout({ children }) {
  return (
    <div className="app-shell">
      <Sidebar />
      <main className="app-main">
        {children}
      </main>
    </div>
  )
}
