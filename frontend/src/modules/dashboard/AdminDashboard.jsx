import React, { useEffect, useState } from 'react'
import { Link } from 'react-router'
import { Package, ShieldCheck, Building2, Truck, CheckCircle2, Cpu, ArrowRight } from 'lucide-react'
import { apiClient } from '../../shared/services/apiClient.js'
import { TopBar } from '../../shared/components/TopBar.jsx'

export function AdminDashboard() {
  const [stats, setStats] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function loadStats() {
      try {
        const res = await apiClient.get('/api/dashboard/admin')
        setStats(res.data)
      } catch {
        // Handle error gracefully
      } finally {
        setLoading(false)
      }
    }
    loadStats()
  }, [])

  return (
    <>
      <TopBar title="Admin Operations Dashboard" />

      <div className="content-container">
        <div className="page-header">
          <div className="page-title-group">
            <h1>Platform Overview & Health</h1>
            <div className="page-subtitle">Monitor multi-agent execution, human approvals, and physical logistics</div>
          </div>
        </div>

        {/* Stats Grid */}
        <div className="stat-grid">
          <div className="stat-card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div className="stat-label">Pending Recovery Approvals</div>
              <ShieldCheck size={18} color="var(--warning)" />
            </div>
            <div className="stat-value">{stats?.pendingRecoveryApprovals ?? 0}</div>
          </div>

          <div className="stat-card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div className="stat-label">Awaiting Agent Assignment</div>
              <Truck size={18} color="var(--info)" />
            </div>
            <div className="stat-value">{stats?.collectionsAwaitingAssignment ?? 0}</div>
          </div>

          <div className="stat-card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div className="stat-label">Active Collections in Transit</div>
              <Truck size={18} color="var(--primary)" />
            </div>
            <div className="stat-value">{stats?.activeCollections ?? 0}</div>
          </div>

          <div className="stat-card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div className="stat-label">Active Certified Partners</div>
              <Building2 size={18} color="var(--primary)" />
            </div>
            <div className="stat-value">{stats?.activePartners ?? 0}</div>
          </div>

          <div className="stat-card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div className="stat-label">Total Recoveries Completed</div>
              <CheckCircle2 size={18} color="var(--success)" />
            </div>
            <div className="stat-value">{stats?.completedRecoveries ?? 0}</div>
          </div>
        </div>

        {/* Action Cards */}
        <div className="grid-2">
          <div className="card" style={{ display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.75rem', color: 'var(--primary)' }}>
                <ShieldCheck size={20} />
                <h3 style={{ fontSize: '1.125rem' }}>Recovery Approvals Queue</h3>
              </div>
              <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem', lineHeight: 1.6, marginBottom: '1.5rem' }}>
                Review AI-generated preparation plans submitted by customers. Approve, request revisions, or reject before partner matching is unlocked.
              </p>
            </div>
            <Link to="/admin/recovery" className="btn btn-primary" style={{ alignSelf: 'flex-start' }}>
              <span>Review Approvals Queue</span>
              <ArrowRight size={16} />
            </Link>
          </div>

          <div className="card" style={{ display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.75rem', color: 'var(--primary)' }}>
                <Truck size={20} />
                <h3 style={{ fontSize: '1.125rem' }}>Collection Agent Dispatch</h3>
              </div>
              <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem', lineHeight: 1.6, marginBottom: '1.5rem' }}>
                Assign collection agents to customer pickups based on Agent 4 proposals, confirm pickup windows, and verify final deliveries.
              </p>
            </div>
            <Link to="/admin/collections" className="btn btn-secondary" style={{ alignSelf: 'flex-start' }}>
              <span>Manage Collections</span>
              <ArrowRight size={16} />
            </Link>
          </div>

          <div className="card" style={{ display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.75rem', color: 'var(--primary)' }}>
                <Cpu size={20} />
                <h3 style={{ fontSize: '1.125rem' }}>AI Agent Workflow Auditing</h3>
              </div>
              <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem', lineHeight: 1.6, marginBottom: '1.5rem' }}>
                Inspect the end-to-end execution trail across Agent 1 (Item Assessment), Agent 2 (Recovery Planning), Agent 3 (Partner Matching), and Agent 4 (Collection Planning).
              </p>
            </div>
            <Link to="/admin/workflows" className="btn btn-secondary" style={{ alignSelf: 'flex-start' }}>
              <span>View Workflow History</span>
              <ArrowRight size={16} />
            </Link>
          </div>

          <div className="card" style={{ display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.75rem', color: 'var(--primary)' }}>
                <Building2 size={20} />
                <h3 style={{ fontSize: '1.125rem' }}>Accredited Partners & Agents</h3>
              </div>
              <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem', lineHeight: 1.6, marginBottom: '1.5rem' }}>
                Configure registered recycling centers, charitable foundations, and field collection agent personnel.
              </p>
            </div>
            <div style={{ display: 'flex', gap: '0.75rem' }}>
              <Link to="/admin/partners" className="btn btn-secondary btn-sm">
                <span>Partners</span>
              </Link>
              <Link to="/admin/collection-agents" className="btn btn-secondary btn-sm">
                <span>Agents</span>
              </Link>
            </div>
          </div>
        </div>
      </div>
    </>
  )
}
