import React, { useEffect, useState } from 'react'
import { Truck, AlertCircle, CheckCircle2, Calendar, Clock, Eye, X, Package, Building2, User, Sparkles, AlertTriangle, Mail } from 'lucide-react'
import { apiClient } from '../../../shared/services/apiClient.js'
import { StatusChip } from '../../../shared/components/StatusChip.jsx'
import { TopBar } from '../../../shared/components/TopBar.jsx'

export function AdminCollectionsPage() {
  const [collections, setCollections] = useState([])
  const [selectedCol, setSelectedCol] = useState(null)
  const [loading, setLoading] = useState(true)
  const [assigningId, setAssigningId] = useState(null)
  const [sendingEmailId, setSendingEmailId] = useState(null)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  useEffect(() => {
    loadData()
  }, [])

  const loadData = async () => {
    try {
      setLoading(true)
      const colRes = await apiClient.get('/api/admin/collections')
      setCollections(colRes.data)
    } catch {
      setError('Failed to load collections queue.')
    } finally {
      setLoading(false)
    }
  }

  const handleSendDeliveryEmail = async (id) => {
    try {
      setSendingEmailId(id)
      setError('')
      setSuccess('')
      const res = await apiClient.post(`/api/admin/collections/${id}/send-delivery-email`)
      setSuccess(`Delivery email notification successfully generated and dispatched via Brevo!`)
      await loadData()
      if (selectedCol && selectedCol.id === id) {
        setSelectedCol(res.data)
      }
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to dispatch email via Brevo.')
    } finally {
      setSendingEmailId(null)
    }
  }

  const handleAssignAgent = async (id, isReassign = false) => {
    try {
      setAssigningId(id)
      setError('')
      setSuccess('')
      const res = await apiClient.post(`/api/admin/collections/${id}/assign-agent`)
      setSuccess(
        isReassign
          ? `Reassigned to collection agent (${res.data.assignedAgentName || 'Agent'}) via Agentic AI.`
          : `Assigned to collection agent (${res.data.assignedAgentName || 'Agent'}) via Agentic AI.`
      )
      await loadData()
      if (selectedCol && selectedCol.id === id) {
        setSelectedCol(res.data)
      }
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to dispatch agent with Agentic AI.')
    } finally {
      setAssigningId(null)
    }
  }

  return (
    <>
      <TopBar title="Collections Logistics" />

      <div className="content-container">
        <div className="page-header">
          <div className="page-title-group">
            <h1>Collection Logistics & Milestone Tracking</h1>
            <div className="page-subtitle">
              Review customer pickup requests, dispatch available agents with Agentic AI, and track handovers
            </div>
          </div>
        </div>

        {error && (
          <div className="alert alert-error">
            <AlertCircle size={18} />
            <span>{error}</span>
          </div>
        )}

        {success && (
          <div className="alert alert-success">
            <CheckCircle2 size={18} />
            <span>{success}</span>
          </div>
        )}

        {loading ? (
          <div className="card" style={{ textAlign: 'center', padding: '3rem' }}>
            <p style={{ color: 'var(--text-muted)' }}>Loading collections queue...</p>
          </div>
        ) : collections.length === 0 ? (
          <div className="card" style={{ textAlign: 'center', padding: '3rem' }}>
            <Truck size={36} color="var(--primary)" style={{ margin: '0 auto 1rem' }} />
            <h3>No active collection requests</h3>
          </div>
        ) : (
          <div className="table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Item & Partner</th>
                  <th>Status & Milestone</th>
                  <th>Assigned Agent</th>
                  <th>Scheduled Window</th>
                  <th style={{ textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {collections.map((c) => (
                  <tr key={c.id}>
                    <td>
                      <div style={{ fontWeight: 600 }}>{c.item?.name}</div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.125rem' }}>
                        Destination: <strong>{c.partnerName}</strong>
                      </div>
                    </td>
                    <td>
                      <StatusChip status={c.status} />
                      {c.status === 'Requested' && (
                        <div style={{ fontSize: '0.75rem', marginTop: '0.25rem' }}>
                          {c.statusHistory?.[c.statusHistory.length - 1]?.note?.toLowerCase().includes('declined') ? (
                            <div style={{ color: '#B45309', background: '#FEF3C7', padding: '0.2rem 0.4rem', borderRadius: '4px', display: 'inline-flex', alignItems: 'center', gap: '0.25rem', marginTop: '0.25rem' }}>
                              <AlertTriangle size={12} />
                              <span>{c.statusHistory[c.statusHistory.length - 1].note}</span>
                            </div>
                          ) : (
                            <span style={{ color: 'var(--text-muted)' }}>Awaiting Admin AI dispatch</span>
                          )}
                        </div>
                      )}
                      {c.status === 'AgentAssigned' && (
                        <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.25rem' }}>
                          Agent assigned (awaiting agent confirmation)
                        </div>
                      )}
                      {c.status === 'Scheduled' && (
                        <div style={{ fontSize: '0.75rem', color: 'var(--primary)', marginTop: '0.25rem' }}>
                          Confirmed by agent (pickup scheduled)
                        </div>
                      )}
                      {c.status === 'Collected' && (
                        <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.25rem' }}>
                          Item is picked up by the collection agent
                        </div>
                      )}
                      {c.status === 'DeliveredToPartner' && (
                        <div style={{ fontSize: '0.75rem', color: 'var(--primary)', marginTop: '0.25rem', fontWeight: 500 }}>
                          Item handed over • Waiting for partner review & confirmation
                        </div>
                      )}
                      {c.status === 'Completed' && (
                        <div>
                          <div style={{ fontSize: '0.75rem', color: 'var(--success)', marginTop: '0.25rem', display: 'flex', alignItems: 'center', gap: '0.25rem' }}>
                            <CheckCircle2 size={12} />
                            <span>Handed over & cycle completed</span>
                          </div>
                          {c.deliveryEmailSent && (
                            <div style={{ fontSize: '0.7rem', color: 'var(--primary)', marginTop: '0.125rem', display: 'flex', alignItems: 'center', gap: '0.25rem' }}>
                              <Mail size={11} />
                              <span>Delivery email sent</span>
                            </div>
                          )}
                        </div>
                      )}
                    </td>
                    <td>
                      {c.assignedAgentName ? (
                        <div>
                          <span style={{ fontWeight: 600 }}>{c.assignedAgentName}</span>
                          <div style={{ fontSize: '0.7rem', color: 'var(--primary)', marginTop: '0.125rem' }}>
                            {c.status === 'AgentAssigned' ? 'Awaiting Acceptance' : 'Confirmed'}
                          </div>
                        </div>
                      ) : (
                        <span style={{ color: 'var(--text-muted)', fontSize: '0.8125rem' }}>Unassigned</span>
                      )}
                    </td>
                    <td style={{ fontSize: '0.8125rem' }}>
                      {c.scheduledPickupDate ? (
                        <div>
                          <div style={{ fontWeight: 500 }}>{new Date(c.scheduledPickupDate).toLocaleDateString()}</div>
                          <div style={{ color: 'var(--text-muted)', fontSize: '0.75rem' }}>
                            {c.scheduledStartTime?.slice(0, 5)} - {c.scheduledEndTime?.slice(0, 5)}
                          </div>
                        </div>
                      ) : (
                        <div style={{ color: 'var(--text-muted)' }}>
                          Pref: {c.preferredPickupDate ? new Date(c.preferredPickupDate).toLocaleDateString() : 'N/A'}
                        </div>
                      )}
                    </td>
                    <td style={{ textAlign: 'right' }}>
                      <div style={{ display: 'inline-flex', alignItems: 'center', gap: '0.5rem', justifyContent: 'flex-end' }}>
                        {(c.status === 'Requested' || c.status === 'AgentAssigned') && (
                          <button
                            onClick={() => handleAssignAgent(c.id, Boolean(c.assignedCollectionAgentId))}
                            disabled={assigningId === c.id}
                            className="btn btn-primary btn-sm"
                            title={c.assignedCollectionAgentId ? "Use Agentic AI to reassign to an available agent in location" : "Use Agentic AI to assign free agent in location"}
                          >
                            <Sparkles size={14} />
                            <span>
                              {assigningId === c.id
                                ? (c.assignedCollectionAgentId ? 'Reassigning...' : 'Assigning...')
                                : (c.statusHistory?.[c.statusHistory.length - 1]?.note?.toLowerCase().includes('declined')
                                    ? 'Re-dispatch with AI'
                                    : (c.assignedCollectionAgentId ? 'Reassign Agent (AI)' : 'Assign Agent with AI'))}
                            </span>
                          </button>
                        )}
                        <button
                          onClick={() => setSelectedCol(c)}
                          className="btn btn-secondary btn-sm"
                          title="View Full Collection History"
                        >
                          <Eye size={14} />
                          <span>Details</span>
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Modal: View Details and Milestone History */}
        {selectedCol && (
          <div
            style={{
              position: 'fixed',
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              background: 'rgba(0, 0, 0, 0.45)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              zIndex: 1000,
              padding: '1rem'
            }}
          >
            <div
              className="card"
              style={{
                width: '100%',
                maxWidth: '620px',
                maxHeight: '90vh',
                overflowY: 'auto',
                boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)'
              }}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem', borderBottom: '1px solid var(--border-light)', paddingBottom: '0.75rem' }}>
                <div>
                  <h3 style={{ fontSize: '1.25rem' }}>Collection Request Details</h3>
                  <div style={{ fontSize: '0.8125rem', color: 'var(--text-muted)' }}>
                    Item: <strong>{selectedCol.item?.name}</strong>
                  </div>
                </div>
                <button
                  onClick={() => setSelectedCol(null)}
                  className="btn btn-secondary btn-sm"
                  style={{ padding: '0.375rem' }}
                >
                  <X size={16} />
                </button>
              </div>

              {/* Status & Summary Cards */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem', marginBottom: '1.25rem' }}>
                <div style={{ background: 'var(--surface-subtle)', padding: '0.875rem', borderRadius: 'var(--radius-sm)' }}>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 500 }}>Current Status</div>
                  <div style={{ marginTop: '0.375rem' }}>
                    <StatusChip status={selectedCol.status} />
                  </div>
                </div>
                <div style={{ background: 'var(--surface-subtle)', padding: '0.875rem', borderRadius: 'var(--radius-sm)' }}>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 500 }}>Assigned Agent</div>
                  <div style={{ fontWeight: 600, marginTop: '0.375rem', fontSize: '0.9375rem' }}>
                    {selectedCol.assignedAgentName || (selectedCol.status === 'Requested' ? 'Unassigned' : 'None')}
                  </div>
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem', marginBottom: '1.5rem', fontSize: '0.8125rem' }}>
                <div>
                  <div style={{ color: 'var(--text-muted)', fontWeight: 500 }}>Destination Partner</div>
                  <div style={{ fontWeight: 600, marginTop: '0.25rem' }}>{selectedCol.partnerName}</div>
                </div>
                <div>
                  <div style={{ color: 'var(--text-muted)', fontWeight: 500 }}>Scheduled Window</div>
                  <div style={{ fontWeight: 600, marginTop: '0.25rem' }}>
                    {selectedCol.scheduledPickupDate ? `${new Date(selectedCol.scheduledPickupDate).toLocaleDateString()} (${selectedCol.scheduledStartTime?.slice(0, 5)} - ${selectedCol.scheduledEndTime?.slice(0, 5)})` : 'Not scheduled'}
                  </div>
                </div>
              </div>

              {/* Milestone Event Timeline */}
              <div style={{ borderTop: '1px solid var(--border-light)', paddingTop: '1.25rem' }}>
                <h4 style={{ fontSize: '0.9375rem', marginBottom: '0.875rem' }}>Event Timeline & Milestones</h4>
                {selectedCol.statusHistory && selectedCol.statusHistory.length > 0 ? (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
                    {selectedCol.statusHistory.map((h, idx) => (
                      <div
                        key={idx}
                        style={{
                          display: 'flex',
                          alignItems: 'flex-start',
                          gap: '0.75rem',
                          fontSize: '0.8125rem',
                          background: 'var(--surface-subtle)',
                          padding: '0.625rem 0.875rem',
                          borderRadius: 'var(--radius-sm)'
                        }}
                      >
                        <CheckCircle2 size={16} color="var(--primary)" style={{ marginTop: '0.125rem', flexShrink: 0 }} />
                        <div style={{ flex: 1 }}>
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                            <StatusChip status={h.status} />
                            <span style={{ color: 'var(--text-muted)', fontSize: '0.75rem' }}>
                              {new Date(h.changedAt).toLocaleString()}
                            </span>
                          </div>
                          {h.note && (
                            <div style={{ marginTop: '0.375rem', color: 'var(--text-main)' }}>
                              {h.note}
                            </div>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <p style={{ color: 'var(--text-muted)', fontSize: '0.8125rem' }}>No status events logged yet.</p>
                )}
              </div>

              {/* Brevo Delivery Email Audit Card */}
              {selectedCol.status === 'Completed' && (
                <div style={{ marginTop: '1.25rem', padding: '0.875rem', borderRadius: 'var(--radius-sm)', background: 'var(--surface-subtle)', border: '1px solid var(--border-light)' }}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                      <Mail size={16} color="var(--primary)" />
                      <span style={{ fontWeight: 600, fontSize: '0.875rem' }}>AI Customer Notification (Brevo)</span>
                    </div>
                    <span className={`badge ${selectedCol.deliveryEmailSent ? 'badge-success' : 'badge-warning'}`}>
                      {selectedCol.deliveryEmailSent ? 'Email Dispatched' : 'Pending'}
                    </span>
                  </div>
                  {selectedCol.deliveryEmailSent ? (
                    <div style={{ marginTop: '0.5rem', fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                      <div><strong>Subject:</strong> {selectedCol.deliveryEmailSubject}</div>
                      <div style={{ marginTop: '0.2rem' }}><strong>Sent at:</strong> {new Date(selectedCol.deliveryEmailSentAt).toLocaleString()}</div>
                    </div>
                  ) : (
                    <div style={{ marginTop: '0.5rem', fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                      Automated delivery email has not been triggered yet.
                    </div>
                  )}
                </div>
              )}

              <div style={{ marginTop: '1.5rem', display: 'flex', justifyContent: 'flex-end', gap: '0.75rem' }}>
                {selectedCol.status === 'Completed' && (
                  <button
                    onClick={() => handleSendDeliveryEmail(selectedCol.id)}
                    disabled={sendingEmailId === selectedCol.id}
                    className="btn btn-secondary"
                    title="Generate and resend delivery email notification via Brevo"
                  >
                    <Mail size={16} />
                    <span>{sendingEmailId === selectedCol.id ? 'Sending...' : 'Resend Email (Brevo)'}</span>
                  </button>
                )}
                {(selectedCol.status === 'Requested' || selectedCol.status === 'AgentAssigned') && (
                  <button
                    onClick={() => handleAssignAgent(selectedCol.id, Boolean(selectedCol.assignedCollectionAgentId))}
                    disabled={assigningId === selectedCol.id}
                    className="btn btn-primary"
                    title={selectedCol.assignedCollectionAgentId ? "Use Agentic AI to reassign to an available agent in location" : "Use Agentic AI to assign free agent in location"}
                  >
                    <Sparkles size={16} />
                    <span>
                      {assigningId === selectedCol.id
                        ? (selectedCol.assignedCollectionAgentId ? 'Reassigning with AI...' : 'Dispatching with AI...')
                        : (selectedCol.assignedCollectionAgentId ? 'Reassign Agent with AI' : 'Assign Agent with AI')}
                    </span>
                  </button>
                )}
                <button onClick={() => setSelectedCol(null)} className="btn btn-secondary">
                  Close
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </>
  )
}
