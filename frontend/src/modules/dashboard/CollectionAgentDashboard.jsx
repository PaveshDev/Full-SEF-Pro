import React, { useEffect, useState } from 'react'
import { Link } from 'react-router'
import { Truck, CalendarCheck, CheckCircle2, ArrowRight } from 'lucide-react'
import { apiClient } from '../../shared/services/apiClient.js'
import { useAuth } from '../../shared/context/AuthContext.jsx'
import { TopBar } from '../../shared/components/TopBar.jsx'

export function CollectionAgentDashboard() {
  const { user } = useAuth()
  const [stats, setStats] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function loadStats() {
      try {
        const res = await apiClient.get('/api/dashboard/agent')
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
      <TopBar title="Collection Agent Portal" />

      <div className="content-container">
        <div className="page-header">
          <div className="page-title-group">
            <h1>Welcome back, {user?.name}</h1>
            <div className="page-subtitle">Your field collection metrics and pickup assignments</div>
          </div>
        </div>

        <div className="stat-grid">
          <div className="stat-card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div className="stat-label">Pending Assigned Pickups</div>
              <Truck size={18} color="var(--primary)" />
            </div>
            <div className="stat-value">{stats?.assignedJobs ?? 0}</div>
          </div>

          <div className="stat-card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div className="stat-label">Scheduled For Today</div>
              <CalendarCheck size={18} color="var(--warning)" />
            </div>
            <div className="stat-value">{stats?.todaysJobs ?? 0}</div>
          </div>

          <div className="stat-card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div className="stat-label">Completed Deliveries</div>
              <CheckCircle2 size={18} color="var(--success)" />
            </div>
            <div className="stat-value">{stats?.completedJobs ?? 0}</div>
          </div>
        </div>

        <div className="card" style={{ maxWidth: '640px' }}>
          <h3 style={{ marginBottom: '0.5rem' }}>Active Pickup Jobs</h3>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem', marginBottom: '1.25rem' }}>
            View your dispatch route, contact details, item categories, and update delivery milestones in real-time.
          </p>
          <Link to="/agent/jobs" className="btn btn-primary">
            <span>View Assigned Pickups</span>
            <ArrowRight size={16} />
          </Link>
        </div>
      </div>
    </>
  )
}
