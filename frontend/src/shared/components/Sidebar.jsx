import React from 'react'
import { NavLink } from 'react-router'
import {
  LayoutDashboard,
  Package,
  Repeat,
  Truck,
  Building2,
  Users,
  Cpu,
  LogOut,
  ShieldCheck,
  CalendarCheck,
  User
} from 'lucide-react'
import { useAuth } from '../context/AuthContext.jsx'

export function Sidebar() {
  const { role, logout, user } = useAuth()

  return (
    <aside className="app-sidebar">
      <div className="sidebar-header">
        <div className="brand-title">
          <Repeat size={24} color="var(--primary)" />
          <span>LoopWorth</span>
        </div>
        <div className="brand-tagline">Give Waste Another Worth</div>
      </div>

      <nav className="sidebar-nav">
        {/* Customer Navigation */}
        {role === 'Customer' && (
          <>
            <NavLink to="/dashboard" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
              <LayoutDashboard size={18} />
              <span>Dashboard</span>
            </NavLink>
            <NavLink to="/items" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
              <Package size={18} />
              <span>My Items</span>
            </NavLink>
            <NavLink to="/recovery" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
              <Repeat size={18} />
              <span>Recovery Requests</span>
            </NavLink>
            <NavLink to="/matching-partners" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
              <Building2 size={18} />
              <span>Partner Matching</span>
            </NavLink>
            <NavLink to="/collections" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
              <Truck size={18} />
              <span>Collections</span>
            </NavLink>
            <NavLink to="/profile" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
              <User size={18} />
              <span>My Profile</span>
            </NavLink>
          </>
        )}

        {/* Admin Navigation */}
        {role === 'Admin' && (
          <>
            <NavLink to="/admin" end className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
              <LayoutDashboard size={18} />
              <span>Admin Dashboard</span>
            </NavLink>
            <NavLink to="/admin/recovery" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
              <ShieldCheck size={18} />
              <span>Recovery Approvals</span>
            </NavLink>
            <NavLink to="/admin/partners" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
              <Building2 size={18} />
              <span>Partners</span>
            </NavLink>
            <NavLink to="/admin/collections" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
              <Truck size={18} />
              <span>Collections</span>
            </NavLink>
            <NavLink to="/admin/collection-agents" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
              <Users size={18} />
              <span>Collection Agents</span>
            </NavLink>
            <NavLink to="/admin/workflows" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
              <Cpu size={18} />
              <span>AI Workflows</span>
            </NavLink>
          </>
        )}

        {/* Collection Agent Navigation */}
        {role === 'CollectionAgent' && (
          <>
            <NavLink to="/agent" end className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
              <LayoutDashboard size={18} />
              <span>Agent Dashboard</span>
            </NavLink>
            <NavLink to="/agent/jobs" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
              <CalendarCheck size={18} />
              <span>Assigned Pickups</span>
            </NavLink>
          </>
        )}

        {/* Certified Partner Navigation */}
        {role === 'Partner' && (
          <>
            <NavLink to="/partner" end className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
              <LayoutDashboard size={18} />
              <span>Partner Dashboard</span>
            </NavLink>
            <NavLink to="/partner" className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
              <Building2 size={18} />
              <span>Facility Intake</span>
            </NavLink>
          </>
        )}
      </nav>

      <div className="sidebar-footer">
        <NavLink
          to="/profile"
          style={{
            display: 'block',
            marginBottom: '0.75rem',
            fontSize: '0.8125rem',
            textDecoration: 'none',
            padding: '0.5rem',
            borderRadius: 'var(--radius-sm)',
            transition: 'background 0.15s ease'
          }}
          className="user-profile-preview-link"
          title="Click to view and edit profile"
        >
          <div style={{ fontWeight: 600, color: 'var(--text-main)' }}>{user?.name || 'Account'}</div>
          <div style={{ color: 'var(--text-muted)', fontSize: '0.75rem' }}>{user?.role} • Edit Profile</div>
        </NavLink>
        <button onClick={logout} className="btn btn-secondary btn-sm" style={{ width: '100%', justifyContent: 'flex-start' }}>
          <LogOut size={16} />
          <span>Sign Out</span>
        </button>
      </div>
    </aside>
  )
}
