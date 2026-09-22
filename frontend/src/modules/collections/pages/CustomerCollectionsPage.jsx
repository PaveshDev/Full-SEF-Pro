import React, { useEffect, useState } from 'react'
import { Link } from 'react-router'
import { Truck, Calendar, Clock, MapPin, CheckCircle2 } from 'lucide-react'
import { apiClient } from '../../../shared/services/apiClient.js'
import { StatusChip } from '../../../shared/components/StatusChip.jsx'
import { TopBar } from '../../../shared/components/TopBar.jsx'

export function CustomerCollectionsPage() {
  const [collections, setCollections] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    async function loadCollections() {
      try {
        setLoading(true)
        const res = await apiClient.get('/api/collections')
        setCollections(Array.isArray(res.data) ? res.data : (res.data?.items || []))
      } catch {
        setError('Failed to load collections.')
      } finally {
        setLoading(false)
      }
    }
    loadCollections()
  }, [])

  return (
    <>
      <TopBar title="Collections & Pickups" />

      <div className="content-container">
        <div className="page-header">
          <div className="page-title-group">
            <h1>Physical Collection Tracking</h1>
            <div className="page-subtitle">Track pickup scheduling, assigned agents, and delivery to partner facilities</div>
          </div>
        </div>

        {error && <div className="alert alert-error">{error}</div>}

        {loading ? (
          <div className="card" style={{ textAlign: 'center', padding: '3rem' }}>
            <p style={{ color: 'var(--text-muted)' }}>Loading collections...</p>
          </div>
        ) : collections.length === 0 ? (
          <div className="card" style={{ textAlign: 'center', padding: '3.5rem 2rem' }}>
            <Truck size={36} color="var(--primary)" style={{ margin: '0 auto 1rem' }} />
            <h3>No active collection requests</h3>
            <p style={{ color: 'var(--text-muted)', maxWidth: '420px', margin: '0 auto 1.5rem', fontSize: '0.875rem' }}>
              Once your recovery plan is approved and you select a partner, you can schedule a pickup here.
            </p>
            <Link to="/recovery" className="btn btn-primary">View Recovery Requests</Link>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
            {collections.map((col) => (
              <div key={col.id} className="card">
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '1rem' }}>
                  <div>
                    <h3 style={{ fontSize: '1.25rem' }}>{col.item?.name || 'Item'}</h3>
                    <div style={{ color: 'var(--text-muted)', fontSize: '0.875rem', marginTop: '0.25rem' }}>
                      Delivery Recipient: <strong>{col.partnerName}</strong>
                    </div>
                  </div>
                  <StatusChip status={col.status} />
                </div>

                {col.status === 'Collected' && (
                  <div className="alert alert-info" style={{ marginBottom: '1.25rem' }}>
                    <Truck size={18} />
                    <span>Item has been picked up by our collection agent ({col.assignedAgentName || 'Agent'}) and is on the way to {col.partnerName}.</span>
                  </div>
                )}
                {col.status === 'DeliveredToPartner' && (
                  <div className="alert alert-success" style={{ marginBottom: '1.25rem' }}>
                    <CheckCircle2 size={18} />
                    <span>Item has been handed over to {col.partnerName}.</span>
                  </div>
                )}
                {col.status === 'Completed' && (
                  <div className="alert alert-success" style={{ marginBottom: '1.25rem' }}>
                    <CheckCircle2 size={18} />
                    <span>Collection & Recovery Completed! The item has been safely received by {col.partnerName}.</span>
                  </div>
                )}

                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem', padding: '1rem', background: 'var(--surface-subtle)', borderRadius: 'var(--radius-sm)', marginBottom: '1.25rem' }}>
                  <div>
                    <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 500 }}>Customer Preferred Date</div>
                    <div style={{ fontWeight: 600, marginTop: '0.25rem' }}>
                      {col.preferredPickupDate ? new Date(col.preferredPickupDate).toLocaleDateString() : 'Flexible'}
                    </div>
                  </div>
                  <div>
                    <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 500 }}>Scheduled Pickup Window</div>
                    <div style={{ fontWeight: 600, marginTop: '0.25rem' }}>
                      {col.scheduledPickupDate ? `${new Date(col.scheduledPickupDate).toLocaleDateString()} (${col.scheduledStartTime?.slice(0, 5)} - ${col.scheduledEndTime?.slice(0, 5)})` : 'Pending Admin Assignment'}
                    </div>
                  </div>
                  <div>
                    <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 500 }}>Assigned Collection Agent</div>
                    <div style={{ fontWeight: 600, marginTop: '0.25rem' }}>
                      {col.assignedAgentName || 'Agent pending assignment'}
                    </div>
                  </div>
                </div>

                {/* Progress history timeline */}
                {col.statusHistory && col.statusHistory.length > 0 && (
                  <div>
                    <div style={{ fontSize: '0.8125rem', fontWeight: 600, color: 'var(--text-muted)', marginBottom: '0.5rem' }}>
                      Collection Event History
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '0.375rem' }}>
                      {col.statusHistory.map((h, idx) => (
                        <div key={idx} style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', fontSize: '0.8125rem' }}>
                          <CheckCircle2 size={14} color="var(--primary)" />
                          <span style={{ fontWeight: 600 }}><StatusChip status={h.status} /></span>
                          <span style={{ color: 'var(--text-muted)' }}>{new Date(h.changedAt).toLocaleString()}</span>
                          {h.note && <span style={{ color: 'var(--text-main)' }}>— {h.note}</span>}
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </>
  )
}
