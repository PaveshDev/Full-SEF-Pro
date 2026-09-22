import React, { useEffect, useState } from 'react'
import { Link } from 'react-router'
import { Repeat, Eye } from 'lucide-react'
import { apiClient } from '../../../shared/services/apiClient.js'
import { StatusChip } from '../../../shared/components/StatusChip.jsx'
import { TopBar } from '../../../shared/components/TopBar.jsx'

export function RecoveryListPage() {
  const [recoveries, setRecoveries] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    async function loadRecoveries() {
      try {
        setLoading(true)
        const res = await apiClient.get('/api/recovery')
        setRecoveries(Array.isArray(res.data) ? res.data : (res.data?.items || []))
      } catch {
        setError('Failed to load recovery requests.')
      } finally {
        setLoading(false)
      }
    }
    loadRecoveries()
  }, [])

  return (
    <>
      <TopBar title="Recovery Requests" />

      <div className="content-container">
        <div className="page-header">
          <div className="page-title-group">
            <h1>Recovery Plans & Approvals</h1>
            <div className="page-subtitle">Track your recovery requests through preparation, approval, and partner matching</div>
          </div>
        </div>

        {error && <div className="alert alert-error">{error}</div>}

        {loading ? (
          <div className="card" style={{ textAlign: 'center', padding: '3rem' }}>
            <p style={{ color: 'var(--text-muted)' }}>Loading recovery plans...</p>
          </div>
        ) : recoveries.length === 0 ? (
          <div className="card" style={{ textAlign: 'center', padding: '3.5rem 2rem' }}>
            <div style={{ display: 'inline-flex', padding: '1rem', background: 'var(--surface-subtle)', borderRadius: 'var(--radius-full)', marginBottom: '1rem' }}>
              <Repeat size={36} color="var(--primary)" />
            </div>
            <h3 style={{ marginBottom: '0.5rem' }}>No recovery requests yet</h3>
            <p style={{ color: 'var(--text-muted)', maxWidth: '420px', margin: '0 auto 1.5rem', fontSize: '0.875rem' }}>
              Submit an electronic waste item and select a recovery route to generate an AI preparation plan.
            </p>
            <Link to="/items" className="btn btn-primary">Go to My Items</Link>
          </div>
        ) : (
          <div className="table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Item</th>
                  <th>Route</th>
                  <th>Status</th>
                  <th>Plan Summary</th>
                  <th>Created</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {recoveries.map((rec) => (
                  <tr key={rec.id}>
                    <td>
                      <div style={{ fontWeight: 600 }}>{rec.item?.name || 'Item'}</div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                        {rec.item?.category?.name}
                      </div>
                    </td>
                    <td><StatusChip status={rec.selectedRoute} type="route" /></td>
                    <td><StatusChip status={rec.status} /></td>
                    <td style={{ maxWidth: '280px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      {rec.plan?.summary || 'Plan pending generation'}
                    </td>
                    <td style={{ fontSize: '0.8125rem', color: 'var(--text-muted)' }}>
                      {new Date(rec.createdAt).toLocaleDateString()}
                    </td>
                    <td>
                      <Link to={`/recovery/${rec.id}`} className="btn btn-secondary btn-sm">
                        <Eye size={14} />
                        <span>View Plan</span>
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </>
  )
}
