import React, { useEffect, useState } from 'react'
import { Link } from 'react-router'
import { Package, Repeat, Truck, CheckCircle2, ArrowRight, Plus, Sparkles, MapPin, Phone, UserCheck } from 'lucide-react'
import { apiClient } from '../../shared/services/apiClient.js'
import { useAuth } from '../../shared/context/AuthContext.jsx'
import { TopBar } from '../../shared/components/TopBar.jsx'

export function CustomerDashboard() {
  const { user } = useAuth()
  const [stats, setStats] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function loadStats() {
      try {
        const res = await apiClient.get('/api/dashboard/customer')
        setStats(res.data)
      } catch {
        // Fallback
      } finally {
        setLoading(false)
      }
    }
    loadStats()
  }, [])

  return (
    <>
      <TopBar
        title="Dashboard"
        action={
          <Link to="/items/new" className="btn btn-primary btn-sm">
            <Plus size={16} />
            <span>Submit Item</span>
          </Link>
        }
      />

      <div className="content-container">
        <div className="page-header">
          <div className="page-title-group">
            <h1>Welcome back, {user?.name}</h1>
            <div className="page-subtitle">Track your electronic waste recovery lifecycle at a glance</div>
          </div>
        </div>

        {/* Stats Grid */}
        <div className="stat-grid" style={{ marginBottom: '1.5rem' }}>
          <div className="stat-card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div className="stat-label">Total Items Submitted</div>
              <Package size={18} color="var(--primary)" />
            </div>
            <div className="stat-value">{stats?.totalItems ?? 0}</div>
          </div>

          <div className="stat-card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div className="stat-label">Pending Recovery Review</div>
              <Repeat size={18} color="var(--warning)" />
            </div>
            <div className="stat-value">{stats?.pendingRecovery ?? 0}</div>
          </div>

          <div className="stat-card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div className="stat-label">Active Collections</div>
              <Truck size={18} color="var(--info)" />
            </div>
            <div className="stat-value">{stats?.activeCollections ?? 0}</div>
          </div>

          <div className="stat-card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div className="stat-label">Completed Recoveries</div>
              <CheckCircle2 size={18} color="var(--success)" />
            </div>
            <div className="stat-value">{stats?.completedItems ?? 0}</div>
          </div>
        </div>

        {/* Pickup Contact & Address Card */}
        <div className="card" style={{ marginBottom: '1.5rem', background: '#F8FAF9', border: '1px solid var(--border)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '1rem' }}>
            <div style={{ display: 'flex', alignItems: 'flex-start', gap: '0.875rem' }}>
              <div style={{ background: 'var(--surface)', padding: '0.625rem', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border)' }}>
                <MapPin size={22} color="var(--primary)" />
              </div>
              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.25rem' }}>
                  <h4 style={{ margin: 0, fontSize: '0.9375rem', fontWeight: 600 }}>Registered Pickup Location &amp; Contact</h4>
                  <span style={{ fontSize: '0.75rem', color: 'var(--primary)', background: '#EBF5EE', padding: '0.125rem 0.5rem', borderRadius: 'var(--radius-full)', fontWeight: 500 }}>
                    Active
                  </span>
                </div>
                <div style={{ fontSize: '0.8125rem', color: 'var(--text-muted)', display: 'flex', flexWrap: 'wrap', gap: '1rem', alignItems: 'center' }}>
                  <span><strong>Address:</strong> {user?.address ? `${user.address}, ${user.town}, ${user.district}` : 'Not provided yet'}</span>
                  {user?.phone && (
                    <span style={{ display: 'inline-flex', alignItems: 'center', gap: '0.25rem' }}>
                      <Phone size={12} color="var(--primary)" />
                      <strong>Phone:</strong> {user.phone}
                    </span>
                  )}
                </div>
              </div>
            </div>

            <Link to="/profile" className="btn btn-secondary btn-sm" style={{ alignSelf: 'center' }}>
              <UserCheck size={14} />
              <span>Edit Details</span>
            </Link>
          </div>
        </div>

        {/* Quick action banners */}
        <div className="grid-2">
          <div className="card" style={{ display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.75rem', color: 'var(--primary)' }}>
                <Sparkles size={20} />
                <h3 style={{ fontSize: '1.125rem' }}>Have Disused Electronics?</h3>
              </div>
              <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem', lineHeight: 1.6, marginBottom: '1.5rem' }}>
                Submit your smartphones, laptops, and appliances. Our Agent 1 will assess condition and advise whether to Donate or Recycle.
              </p>
            </div>
            <Link to="/items/new" className="btn btn-primary" style={{ alignSelf: 'flex-start' }}>
              <span>Submit New Item</span>
              <ArrowRight size={16} />
            </Link>
          </div>

          <div className="card" style={{ display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.75rem', color: 'var(--dark)' }}>
                <Repeat size={20} />
                <h3 style={{ fontSize: '1.125rem' }}>Recovery Plans</h3>
              </div>
              <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem', lineHeight: 1.6, marginBottom: '1.5rem' }}>
                Follow your preparation procedures, track admin review status, match certified partners, and schedule doorstep pickups.
              </p>
            </div>
            <Link to="/recovery" className="btn btn-secondary" style={{ alignSelf: 'flex-start' }}>
              <span>View Recovery Requests</span>
              <ArrowRight size={16} />
            </Link>
          </div>
        </div>
      </div>
    </>
  )
}
