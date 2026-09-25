import React, { useEffect, useState } from 'react'
import { ShieldCheck, Check, X, RotateCcw, AlertCircle, CheckCircle2, Eye, Lock, Clock, AlertTriangle, Leaf, CheckSquare, Square } from 'lucide-react'
import { apiClient } from '../../../shared/services/apiClient.js'
import { StatusChip } from '../../../shared/components/StatusChip.jsx'
import { TopBar } from '../../../shared/components/TopBar.jsx'

export function AdminRecoveryApprovalsPage() {
  const [recoveries, setRecoveries] = useState([])
  const [selectedRecovery, setSelectedRecovery] = useState(null)
  const [decision, setDecision] = useState('')
  const [reason, setReason] = useState('')
  const [customHandling, setCustomHandling] = useState('')
  const [loading, setLoading] = useState(true)
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  useEffect(() => {
    loadRecoveries()
  }, [])

  const loadRecoveries = async () => {
    try {
      setLoading(true)
      const res = await apiClient.get('/api/admin/recovery')
      setRecoveries(res.data)
    } catch {
      setError('Failed to load pending recovery plans.')
    } finally {
      setLoading(false)
    }
  }

  const handleSelectRecovery = (rec) => {
    setSelectedRecovery(rec)
    setDecision('Approved')
    setReason('')
    setCustomHandling(rec.plan?.adminHandlingInstructions || '')
  }

  const handleDecision = async () => {
    if (!decision) return
    if ((decision === 'Rejected' || decision === 'RevisionRequested') && !reason.trim()) {
      setError('A reason is required when rejecting or requesting revisions.')
      return
    }

    setSubmitting(true)
    setError('')
    try {
      await apiClient.post(`/api/admin/recovery/${selectedRecovery.id}/decision`, {
        decision,
        reason: reason || null,
        customHandlingInstructions: customHandling.trim() || null
      })
      setSuccess(`Recovery plan ${decision} successfully.`)
      setSelectedRecovery(null)
      setDecision('')
      setReason('')
      setCustomHandling('')
      await loadRecoveries()
    } catch (err) {
      console.error('Failed to submit decision:', err)
      setError(
        err.response?.data?.error ||
        err.response?.data?.title ||
        err.message ||
        'Failed to submit decision.'
      )
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <>
      <TopBar title="Recovery Approvals" />

      <div className="content-container">
        <div className="page-header">
          <div className="page-title-group">
            <h1>Human Admin Review Queue</h1>
            <div className="page-subtitle">Review AI-generated preparation plans before items proceed to partner matching</div>
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
            <p style={{ color: 'var(--text-muted)' }}>Loading approval queue...</p>
          </div>
        ) : recoveries.length === 0 ? (
          <div className="card" style={{ textAlign: 'center', padding: '3rem 2rem' }}>
            <ShieldCheck size={36} color="var(--primary)" style={{ margin: '0 auto 1rem' }} />
            <h3>No recovery plans pending review</h3>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem', marginTop: '0.25rem' }}>
              All submitted recovery preparation plans have been evaluated.
            </p>
          </div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: selectedRecovery ? '1fr 1fr' : '1fr', gap: '1.5rem', alignItems: 'start' }}>
            {/* List */}
            <div className="table-container">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Item</th>
                    <th>Route</th>
                    <th>Status</th>
                    <th>Submitted</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {recoveries.map((rec) => (
                    <tr
                      key={rec.id}
                      style={{ background: selectedRecovery?.id === rec.id ? 'var(--primary-light)' : undefined }}
                    >
                      <td>
                        <div style={{ fontWeight: 600 }}>{rec.item?.name}</div>
                        <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                          {rec.item?.category?.name}
                        </div>
                      </td>
                      <td><StatusChip status={rec.selectedRoute} type="route" /></td>
                      <td><StatusChip status={rec.status} /></td>
                      <td style={{ fontSize: '0.8125rem', color: 'var(--text-muted)' }}>
                        {rec.submittedAt ? new Date(rec.submittedAt).toLocaleDateString() : 'N/A'}
                      </td>
                      <td>
                        <button
                          onClick={() => handleSelectRecovery(rec)}
                          className="btn btn-primary btn-sm"
                        >
                          <Eye size={14} />
                          <span>{rec.status?.toLowerCase() === 'pendingadminapproval' ? 'Review' : 'View'}</span>
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {/* Review Panel */}
            {selectedRecovery && (() => {
              const isPending = selectedRecovery.status?.toLowerCase() === 'pendingadminapproval'
              const isApproved = selectedRecovery.status?.toLowerCase() === 'approved'
              const isRejected = selectedRecovery.status?.toLowerCase() === 'rejected'
              const isRevision = selectedRecovery.status?.toLowerCase() === 'revisionrequested'
              const latestDecision = selectedRecovery.approvalDecisions?.[0]

              return (
                <div className="card">
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '1rem' }}>
                    <div>
                      <h3>{selectedRecovery.item?.name}</h3>
                      <div style={{ fontSize: '0.8125rem', color: 'var(--text-muted)' }}>
                        Selected Route: <StatusChip status={selectedRecovery.selectedRoute} type="route" />
                      </div>
                    </div>
                    <button onClick={() => setSelectedRecovery(null)} className="btn btn-secondary btn-sm">Close</button>
                  </div>

                  <div style={{ background: 'var(--surface-subtle)', padding: '0.875rem', borderRadius: 'var(--radius-sm)', marginBottom: '1rem', fontSize: '0.875rem' }}>
                    <div style={{ fontWeight: 600, marginBottom: '0.25rem' }}>Customer Condition Report</div>
                    <p style={{ color: 'var(--text-main)', margin: 0 }}>{selectedRecovery.item?.conditionDescription}</p>
                  </div>

                  {/* Feature 1: Environmental Hazard & Eco Audit Report */}
                  {selectedRecovery.item?.ecoAssessment && (() => {
                    const eco = selectedRecovery.item.ecoAssessment
                    const isHarmful = eco.isHarmfulToEnvironment
                    const acknowledged = selectedRecovery.item.ecoHazardAcknowledged

                    return (
                      <div style={{
                        background: isHarmful ? '#FEF2F2' : '#F0FDF4',
                        border: `1px solid ${isHarmful ? '#FECACA' : '#BBF7D0'}`,
                        borderLeft: `4px solid ${isHarmful ? '#DC2626' : '#16A34A'}`,
                        borderRadius: 'var(--radius-sm)',
                        padding: '0.875rem 1rem',
                        marginBottom: '1rem'
                      }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.35rem' }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', fontWeight: 700, fontSize: '0.8125rem', color: isHarmful ? '#991B1B' : '#166534' }}>
                            {isHarmful ? <AlertTriangle size={15} color="#DC2626" /> : <Leaf size={15} color="#16A34A" />}
                            <span>Feature 1 Eco-Hazard Audit ({eco.hazardLevel?.toUpperCase()} HAZARD)</span>
                          </div>
                          <span style={{ fontSize: '0.75rem', color: isHarmful ? (acknowledged ? '#15803D' : '#B91C1C') : '#15803D', fontWeight: 600 }}>
                            {isHarmful ? (acknowledged ? '✓ Customer Acknowledged' : '⚠️ Unacknowledged') : '✓ Safe Device'}
                          </span>
                        </div>
                        <p style={{ margin: 0, fontSize: '0.8125rem', color: isHarmful ? '#7F1D1D' : '#166534', lineHeight: 1.4 }}>
                          {eco.environmentalAlert}
                        </p>
                        {eco.detectedHazards && eco.detectedHazards.length > 0 && (
                          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.25rem', marginTop: '0.5rem' }}>
                            {eco.detectedHazards.map((h, i) => (
                              <span key={i} style={{ background: '#FFFFFF', border: '1px solid #FECACA', color: '#B91C1C', fontSize: '0.6875rem', padding: '0.1rem 0.4rem', borderRadius: '3px', fontWeight: 500 }}>
                                ⚠️ {h}
                              </span>
                            ))}
                          </div>
                        )}
                      </div>
                    )
                  })()}

                  {/* Feature 2: Pre-Collection Readiness Checklist Status */}
                  {selectedRecovery.plan?.checklist && selectedRecovery.plan.checklist.length > 0 && (() => {
                    const total = selectedRecovery.plan.checklist.length
                    const done = selectedRecovery.plan.checklist.filter(c => c.isCompleted).length
                    const isVerified = selectedRecovery.plan.isPreparationVerified

                    return (
                      <div style={{
                        background: isVerified ? '#F0FDF4' : '#FFFBEB',
                        border: `1px solid ${isVerified ? '#BBF7D0' : '#FDE68A'}`,
                        borderRadius: 'var(--radius-sm)',
                        padding: '0.875rem 1rem',
                        marginBottom: '1rem'
                      }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.4rem' }}>
                          <div style={{ fontWeight: 700, fontSize: '0.8125rem', color: isVerified ? '#166534' : '#92400E', display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
                            <CheckSquare size={15} color={isVerified ? '#16A34A' : '#D97706'} />
                            <span>Feature 2 Preparation Checklist ({done}/{total} Done)</span>
                          </div>
                          <span style={{ fontSize: '0.75rem', fontWeight: 700, color: isVerified ? '#15803D' : '#B45309' }}>
                            {isVerified ? '✓ 100% Verified' : 'Pending Completion'}
                          </span>
                        </div>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.25rem' }}>
                          {selectedRecovery.plan.checklist.map((step) => (
                            <div key={step.id} style={{ display: 'flex', alignItems: 'center', gap: '0.35rem', fontSize: '0.75rem', color: step.isCompleted ? '#15803D' : '#94A3B8' }}>
                              {step.isCompleted ? <Check size={12} color="#16A34A" /> : <Square size={12} color="#CBD5E1" />}
                              <span>{step.title}</span>
                            </div>
                          ))}
                        </div>
                      </div>
                    )
                  })()}

                  {selectedRecovery.plan && (
                    <div style={{ marginBottom: '1.25rem' }}>
                      <div style={{ fontWeight: 600, fontSize: '0.875rem', marginBottom: '0.25rem' }}>Agent 2 Plan Summary</div>
                      <p style={{ fontSize: '0.875rem', color: 'var(--text-main)', marginBottom: '0.75rem' }}>
                        {selectedRecovery.plan.summary}
                      </p>

                      <div style={{ fontWeight: 600, fontSize: '0.8125rem', color: 'var(--text-muted)', marginBottom: '0.375rem' }}>
                        Key Preparation Steps ({selectedRecovery.plan.steps?.length || 0})
                      </div>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '0.375rem', marginBottom: '1rem' }}>
                        {selectedRecovery.plan.steps?.map((s, idx) => (
                          <div key={idx} style={{ fontSize: '0.8125rem', background: '#F8FAFC', padding: '0.5rem', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-light)' }}>
                            {(idx + 1)}. {s.stepText}
                          </div>
                        ))}
                      </div>
                    </div>
                  )}

                  {/* Decision area: Read-Only if already decided, editable if pending review */}
                  <div style={{ borderTop: '1px solid var(--border-light)', paddingTop: '1.25rem' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
                      <div style={{ fontWeight: 600, fontSize: '0.875rem' }}>
                        Admin Review Decision
                      </div>
                      {!isPending && (
                        <span style={{ display: 'inline-flex', alignItems: 'center', gap: '0.25rem', fontSize: '0.75rem', color: 'var(--text-muted)', background: 'var(--surface-subtle)', padding: '0.2rem 0.5rem', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-light)' }}>
                          <Lock size={12} />
                          <span>Read Only</span>
                        </span>
                      )}
                    </div>

                    {!isPending ? (
                      /* Read-Only Decision View */
                      <div style={{
                        padding: '1rem',
                        borderRadius: 'var(--radius-md)',
                        background: isApproved ? '#F0FDF4' : isRejected ? '#FEF2F2' : '#FFFBEB',
                        border: `1px solid ${isApproved ? '#BBF7D0' : isRejected ? '#FECACA' : '#FDE68A'}`,
                        display: 'flex',
                        flexDirection: 'column',
                        gap: '0.5rem'
                      }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                          {isApproved && <CheckCircle2 size={18} color="#16A34A" />}
                          {isRejected && <X size={18} color="#DC2626" />}
                          {isRevision && <RotateCcw size={18} color="#D97706" />}
                          <span style={{
                            fontWeight: 700,
                            fontSize: '0.875rem',
                            color: isApproved ? '#15803D' : isRejected ? '#B91C1C' : '#B45309'
                          }}>
                            Decision: {selectedRecovery.status}
                          </span>
                        </div>

                        {latestDecision?.reason ? (
                          <div style={{ marginTop: '0.25rem' }}>
                            <div style={{ fontSize: '0.75rem', fontWeight: 600, color: 'var(--text-muted)', marginBottom: '0.125rem' }}>
                              Recorded Notes / Reason:
                            </div>
                            <p style={{ fontSize: '0.8125rem', color: 'var(--text-main)', margin: 0, lineHeight: 1.4 }}>
                              {latestDecision.reason}
                            </p>
                          </div>
                        ) : (
                          <p style={{ fontSize: '0.8125rem', color: 'var(--text-muted)', margin: 0 }}>
                            No additional feedback notes recorded.
                          </p>
                        )}

                        {latestDecision?.decidedAt && (
                          <div style={{ display: 'flex', alignItems: 'center', gap: '0.25rem', fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.25rem' }}>
                            <Clock size={12} />
                            <span>Decided on: {new Date(latestDecision.decidedAt).toLocaleString()}</span>
                          </div>
                        )}

                        <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontStyle: 'italic', marginTop: '0.25rem' }}>
                          This request has already been finalized and cannot be modified.
                        </div>
                      </div>
                    ) : (
                      /* Editable Form for Pending Requests */
                      <>
                        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '0.5rem', marginBottom: '1rem' }}>
                          <button
                            type="button"
                            onClick={() => setDecision('Approved')}
                            className={`btn btn-sm ${decision === 'Approved' ? 'btn-primary' : 'btn-secondary'}`}
                          >
                            <Check size={14} />
                            <span>Approve</span>
                          </button>
                          <button
                            type="button"
                            onClick={() => setDecision('RevisionRequested')}
                            className={`btn btn-sm ${decision === 'RevisionRequested' ? 'btn-primary' : 'btn-secondary'}`}
                          >
                            <RotateCcw size={14} />
                            <span>Revision</span>
                          </button>
                          <button
                            type="button"
                            onClick={() => setDecision('Rejected')}
                            className={`btn btn-sm ${decision === 'Rejected' ? 'btn-danger' : 'btn-secondary'}`}
                          >
                            <X size={14} />
                            <span>Reject</span>
                          </button>
                        </div>

                        {/* Customer Confirmed Route (Read-Only) */}
                        <div style={{ marginBottom: '1rem', background: 'var(--surface-subtle)', padding: '0.75rem 0.875rem', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-light)', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                          <span style={{ fontSize: '0.8125rem', color: 'var(--text-muted)', fontWeight: 500 }}>
                            Confirmed Recovery Route:
                          </span>
                          <span style={{
                            fontWeight: 700,
                            fontSize: '0.8125rem',
                            color: selectedRecovery.selectedRoute === 'Donate' ? '#16A34A' : '#D97706',
                            background: selectedRecovery.selectedRoute === 'Donate' ? '#DCFCE7' : '#FEF3C7',
                            padding: '0.2rem 0.6rem',
                            borderRadius: '4px',
                            border: `1px solid ${selectedRecovery.selectedRoute === 'Donate' ? '#86EFAC' : '#FDE68A'}`
                          }}>
                            {selectedRecovery.selectedRoute}
                          </span>
                        </div>

                        {/* Feature 5: Custom Handling & Safety Instructions */}
                        <div className="form-group" style={{ marginBottom: '1rem' }}>
                          <label className="form-label" style={{ fontSize: '0.8125rem', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
                            <ShieldCheck size={14} color="var(--primary)" />
                            <span>Special Handling & Courier Directives (Optional)</span>
                          </label>
                          <textarea
                            rows={2}
                            className="form-textarea"
                            placeholder="e.g., Handle with insulated anti-static gloves; place in fire-resistant battery pouch; dispatch to specialized lithium recycler."
                            value={customHandling}
                            onChange={(e) => setCustomHandling(e.target.value)}
                            style={{ fontSize: '0.8125rem' }}
                          />
                        </div>

                        <div className="form-group">
                          <label className="form-label" style={{ fontSize: '0.8125rem' }}>
                            Feedback / Reason {(decision === 'Rejected' || decision === 'RevisionRequested') && '*'}
                          </label>
                          <textarea
                            rows={2}
                            className="form-textarea"
                            placeholder="Notes for the customer and audit history..."
                            value={reason}
                            onChange={(e) => setReason(e.target.value)}
                          />
                        </div>

                        <button
                          onClick={handleDecision}
                          disabled={!decision || submitting}
                          className="btn btn-primary"
                          style={{ width: '100%' }}
                        >
                          <span>{submitting ? 'Submitting...' : 'Confirm Decision'}</span>
                        </button>
                      </>
                    )}
                  </div>
                </div>
              )
            })()}
          </div>
        )}
      </div>
    </>
  )
}
