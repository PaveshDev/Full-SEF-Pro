import React, { useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router'
import { Plus, Package, ArrowRight, Eye, Sparkles, Pencil } from 'lucide-react'
import { apiClient } from '../../../shared/services/apiClient.js'
import { StatusChip } from '../../../shared/components/StatusChip.jsx'
import { TopBar } from '../../../shared/components/TopBar.jsx'

export function CustomerItemsPage() {
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const navigate = useNavigate()

  useEffect(() => {
    fetchItems()
  }, [])

  const fetchItems = async () => {
    try {
      setLoading(true)
      const res = await apiClient.get('/api/items')
      setItems(Array.isArray(res.data) ? res.data : (res.data?.items || []))
    } catch (err) {
      setError('Failed to load items.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <>
      <TopBar
        title="My Items"
        action={
          <Link to="/items/new" className="btn btn-primary btn-sm">
            <Plus size={16} />
            <span>Submit New Item</span>
          </Link>
        }
      />

      <div className="content-container">
        <div className="page-header">
          <div className="page-title-group">
            <h1>Electronic Items</h1>
            <div className="page-subtitle">Track and manage your submitted electronic waste items</div>
          </div>
        </div>

        {error && <div className="alert alert-error">{error}</div>}

        {loading ? (
          <div className="card" style={{ textAlign: 'center', padding: '3rem' }}>
            <p style={{ color: 'var(--text-muted)' }}>Loading your items...</p>
          </div>
        ) : items.length === 0 ? (
          <div className="card" style={{ textAlign: 'center', padding: '3.5rem 2rem' }}>
            <div style={{ display: 'inline-flex', padding: '1rem', background: 'var(--surface-subtle)', borderRadius: 'var(--radius-full)', marginBottom: '1rem' }}>
              <Package size={36} color="var(--primary)" />
            </div>
            <h3 style={{ marginBottom: '0.5rem' }}>No items added yet</h3>
            <p style={{ color: 'var(--text-muted)', maxWidth: '400px', margin: '0 auto 1.5rem', fontSize: '0.875rem' }}>
              Start your waste-to-value journey by registering your unused electronic devices.
            </p>
            <Link to="/items/new" className="btn btn-primary">
              <Plus size={16} />
              <span>Submit First Item</span>
            </Link>
          </div>
        ) : (
          <div className="table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Item</th>
                  <th>Category</th>
                  <th>Condition</th>
                  <th>Status</th>
                  <th>Selected Route</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {items.map((item) => (
                  <tr key={item.id}>
                    <td>
                      <div style={{ fontWeight: 600 }}>{item.name}</div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                        {[item.brand, item.model].filter(Boolean).join(' • ') || 'No brand specified'}
                      </div>
                    </td>
                    <td>{item.category?.name || 'General'}</td>
                    <td style={{ maxWidth: '200px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      {item.conditionDescription}
                    </td>
                    <td><StatusChip status={item.status} /></td>
                    <td>
                      {item.selectedRecoveryRoute ? (
                        <StatusChip status={item.selectedRecoveryRoute} type="route" />
                      ) : (
                        <span style={{ color: 'var(--text-light)', fontSize: '0.8125rem' }}>Not selected</span>
                      )}
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: '0.5rem' }}>
                        <Link to={`/items/${item.id}`} className="btn btn-secondary btn-sm">
                          <Eye size={14} />
                          <span>View</span>
                        </Link>
                        <Link to={`/items/${item.id}?edit=true`} className="btn btn-secondary btn-sm" title="Edit Item Details">
                          <Pencil size={14} />
                          <span>Edit</span>
                        </Link>
                      </div>
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
