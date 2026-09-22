import React from 'react'
import { Link } from 'react-router'
import { User } from 'lucide-react'
import { useAuth } from '../context/AuthContext.jsx'

export function TopBar({ title, action }) {
  const { user } = useAuth()

  return (
    <header className="app-topbar">
      <div>
        <h2 style={{ fontSize: '1.25rem' }}>{title}</h2>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
        {action}
        <Link
          to="/profile"
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '0.5rem',
            background: 'var(--surface-subtle)',
            padding: '0.375rem 0.75rem',
            borderRadius: 'var(--radius-full)',
            textDecoration: 'none',
            color: 'inherit',
            transition: 'background 0.15s ease'
          }}
          title="View & Edit Profile"
        >
          <User size={16} color="var(--primary)" />
          <span style={{ fontSize: '0.8125rem', fontWeight: 500 }}>{user?.email}</span>
        </Link>
      </div>
    </header>
  )
}
