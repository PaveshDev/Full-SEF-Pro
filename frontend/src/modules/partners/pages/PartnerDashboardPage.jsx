import React, { useEffect, useState } from 'react'
import {
  Package,
  CheckCircle2,
  AlertTriangle,
  Clock,
  Camera,
  UploadCloud,
  X,
  FileText,
  User,
  MapPin,
  Phone,
  Truck,
  ShieldCheck,
  Building2,
  Sparkles,
  ExternalLink,
  Info
} from 'lucide-react'
import { apiClient } from '../../../shared/services/apiClient.js'
import { useAuth } from '../../../shared/context/AuthContext.jsx'
import { StatusChip } from '../../../shared/components/StatusChip.jsx'
import { TopBar } from '../../../shared/components/TopBar.jsx'

export function PartnerDashboardPage() {
  const { user } = useAuth()
  const [collections, setCollections] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')
  const [activeTab, setActiveTab] = useState('incoming') // 'incoming' | 'history'

  // Modal inspection state
  const [inspectingItem, setInspectingItem] = useState(null)
  const [photoFile, setPhotoFile] = useState(null)
  const [photoPreview, setPhotoPreview] = useState(null)
  const [conditionOk, setConditionOk] = useState(true)
  const [feedback, setFeedback] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [modalError, setModalError] = useState('')

  useEffect(() => {
    loadPartnerData()
  }, [])

  const loadPartnerData = async () => {
    try {
      setLoading(true)
      const res = await apiClient.get('/api/partner/collections')
      setCollections(res.data || [])
    } catch (err) {
      console.error('Failed to load partner collections:', err)
      setError(err.response?.data?.error || 'Failed to load facility handover orders.')
    } finally {
      setLoading(false)
    }
  }

  const openInspectionModal = (col) => {
    setModalError('')
    setInspectingItem(col)
    setPhotoFile(null)
    setPhotoPreview(null)
    setConditionOk(true)
    setFeedback('')
  }

  const handlePhotoSelect = (e) => {
    const file = e.target.files?.[0]
    if (file) {
      if (file.size > 10 * 1024 * 1024) {
        setModalError('Photo size must be less than 10MB.')
        return
      }
      setPhotoFile(file)
      const reader = new FileReader()
      reader.onloadend = () => {
        setPhotoPreview(reader.result)
      }
      reader.readAsDataURL(file)
    }
  }

  const handleConfirmIntake = async (e) => {
    e.preventDefault()
    if (!inspectingItem) return
    setModalError('')
    setSubmitting(true)

    try {
      const formData = new FormData()
      if (photoFile) {
        formData.append('photo', photoFile)
      }
      formData.append('feedback', feedback || '')
      formData.append('conditionOk', conditionOk.toString())

      await apiClient.post(`/api/partner/collections/${inspectingItem.id}/receive`, formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
      })

      setSuccess(`Intake confirmed for item: ${inspectingItem.item?.name || 'Device'}. Recovery lifecycle completed.`)
      setInspectingItem(null)
      await loadPartnerData()
    } catch (err) {
      console.error('Intake confirmation error:', err)
      setModalError(err.response?.data?.error || 'Failed to confirm item receipt. Please try again.')
    } finally {
      setSubmitting(false)
    }
  }

  const incomingDeliveries = collections.filter(
    (c) => c.status === 'DeliveredToPartner'
  )

  const completedIntakes = collections.filter(
    (c) => c.status === 'Completed' || c.status === 'PartnerReceived'
  )

  const flaggedIssues = completedIntakes.filter(
    (c) => c.partnerReceivedConditionOk === false
  )

  return (
    <>
      <TopBar title="Partner Intake Dashboard" />

      <div className="content-container">
        {/* Partner Header Banner */}
        <div
          className="card"
          style={{
            background: 'linear-gradient(135deg, rgba(16, 185, 129, 0.08) 0%, rgba(59, 130, 246, 0.05) 100%)',
            border: '1px solid rgba(16, 185, 129, 0.2)',
            marginBottom: '1.5rem',
            padding: '1.5rem'
          }}
        >
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '1rem' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
              <div
                style={{
                  width: '52px',
                  height: '52px',
                  borderRadius: '12px',
                  background: 'var(--primary)',
                  color: '#fff',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  boxShadow: '0 4px 12px rgba(16, 185, 129, 0.25)'
                }}
              >
                <Building2 size={28} />
              </div>
              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.625rem' }}>
                  <h2 style={{ margin: 0, fontSize: '1.375rem' }}>{user?.name || 'Partner Facility'}</h2>
                  <span
                    style={{
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: '0.25rem',
                      padding: '0.2rem 0.5rem',
                      borderRadius: '12px',
                      background: 'rgba(16, 185, 129, 0.15)',
                      color: '#10b981',
                      fontSize: '0.6875rem',
                      fontWeight: 700,
                      textTransform: 'uppercase'
                    }}
                  >
                    <ShieldCheck size={12} />
                    <span>Certified Partner</span>
                  </span>
                </div>
                <div style={{ fontSize: '0.8125rem', color: 'var(--text-muted)', marginTop: '0.25rem', display: 'flex', gap: '1rem', flexWrap: 'wrap' }}>
                  <span>Official Account: <strong>{user?.email}</strong></span>
                  {user?.district && <span>Location: <strong>{user.town ? `${user.town}, ` : ''}{user.district}</strong></span>}
                </div>
              </div>
            </div>

            <div style={{ display: 'flex', gap: '0.75rem' }}>
              <button onClick={loadPartnerData} className="btn btn-secondary btn-sm">
                Refresh Deliveries
              </button>
            </div>
          </div>
        </div>

        {/* Top Metric Cards */}
        <div className="grid-3" style={{ marginBottom: '1.5rem' }}>
          <div className="card" style={{ borderLeft: '4px solid #f59e0b' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <div style={{ fontSize: '0.8125rem', color: 'var(--text-muted)', fontWeight: 600 }}>Awaiting Intake</div>
                <div style={{ fontSize: '1.75rem', fontWeight: 700, marginTop: '0.25rem' }}>{incomingDeliveries.length}</div>
                <div style={{ fontSize: '0.75rem', color: '#f59e0b', marginTop: '0.25rem' }}>Handed over at dock</div>
              </div>
              <div style={{ padding: '0.75rem', borderRadius: '50%', background: 'rgba(245, 158, 11, 0.1)', color: '#f59e0b' }}>
                <Clock size={24} />
              </div>
            </div>
          </div>

          <div className="card" style={{ borderLeft: '4px solid #10b981' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <div style={{ fontSize: '0.8125rem', color: 'var(--text-muted)', fontWeight: 600 }}>Confirmed Received</div>
                <div style={{ fontSize: '1.75rem', fontWeight: 700, marginTop: '0.25rem' }}>{completedIntakes.length}</div>
                <div style={{ fontSize: '0.75rem', color: '#10b981', marginTop: '0.25rem' }}>Verified & completed</div>
              </div>
              <div style={{ padding: '0.75rem', borderRadius: '50%', background: 'rgba(16, 185, 129, 0.1)', color: '#10b981' }}>
                <CheckCircle2 size={24} />
              </div>
            </div>
          </div>

          <div className="card" style={{ borderLeft: '4px solid #ef4444' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <div style={{ fontSize: '0.8125rem', color: 'var(--text-muted)', fontWeight: 600 }}>Defects / Issues Flagged</div>
                <div style={{ fontSize: '1.75rem', fontWeight: 700, marginTop: '0.25rem' }}>{flaggedIssues.length}</div>
                <div style={{ fontSize: '0.75rem', color: '#ef4444', marginTop: '0.25rem' }}>Intake condition notices</div>
              </div>
              <div style={{ padding: '0.75rem', borderRadius: '50%', background: 'rgba(239, 68, 68, 0.1)', color: '#ef4444' }}>
                <AlertTriangle size={24} />
              </div>
            </div>
          </div>
        </div>

        {error && (
          <div className="alert alert-error" style={{ marginBottom: '1rem' }}>
            <AlertTriangle size={18} />
            <span>{error}</span>
          </div>
        )}

        {success && (
          <div className="alert alert-success" style={{ marginBottom: '1rem' }}>
            <CheckCircle2 size={18} />
            <span>{success}</span>
          </div>
        )}

        {/* Tab Navigation */}
        <div style={{ display: 'flex', gap: '0.5rem', borderBottom: '1px solid var(--border)', marginBottom: '1.25rem' }}>
          <button
            onClick={() => setActiveTab('incoming')}
            style={{
              padding: '0.75rem 1.25rem',
              fontWeight: 600,
              fontSize: '0.875rem',
              background: 'none',
              border: 'none',
              borderBottom: activeTab === 'incoming' ? '2.5px solid var(--primary)' : '2.5px solid transparent',
              color: activeTab === 'incoming' ? 'var(--primary)' : 'var(--text-muted)',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '0.5rem'
            }}
          >
            <Package size={16} />
            <span>Incoming Deliveries ({incomingDeliveries.length})</span>
          </button>

          <button
            onClick={() => setActiveTab('history')}
            style={{
              padding: '0.75rem 1.25rem',
              fontWeight: 600,
              fontSize: '0.875rem',
              background: 'none',
              border: 'none',
              borderBottom: activeTab === 'history' ? '2.5px solid var(--primary)' : '2.5px solid transparent',
              color: activeTab === 'history' ? 'var(--primary)' : 'var(--text-muted)',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '0.5rem'
            }}
          >
            <CheckCircle2 size={16} />
            <span>Intake Archive & History ({completedIntakes.length})</span>
          </button>
        </div>

        {/* Content Tab 1: Incoming Deliveries */}
        {activeTab === 'incoming' && (
          <div>
            {incomingDeliveries.length === 0 ? (
              <div className="card" style={{ textAlign: 'center', padding: '3.5rem 1.5rem' }}>
                <div style={{ width: '48px', height: '48px', borderRadius: '50%', background: 'var(--surface-muted)', margin: '0 auto 1rem', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-muted)' }}>
                  <Package size={24} />
                </div>
                <h3 style={{ margin: '0 0 0.5rem 0' }}>No Pending Handovers</h3>
                <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem', maxWidth: '420px', margin: '0 auto' }}>
                  All items delivered to your facility have been verified and processed. When a collection agent hands over an item, it will immediately appear here for your intake inspection.
                </p>
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                {incomingDeliveries.map((c) => {
                  const item = c.item
                  const primaryImg = item?.images?.[0]?.imageUrl
                  const handoverTime = c.statusHistory?.slice().reverse().find((h) => h.status === 'DeliveredToPartner')?.changedAt

                  return (
                    <div
                      key={c.id}
                      className="card"
                      style={{
                        padding: '1.25rem',
                        border: '1px solid rgba(245, 158, 11, 0.3)',
                        boxShadow: '0 2px 8px rgba(0,0,0,0.04)'
                      }}
                    >
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '1rem' }}>
                        {/* Device Info */}
                        <div style={{ display: 'flex', gap: '1rem', flex: 1, minWidth: '280px' }}>
                          <div
                            style={{
                              width: '80px',
                              height: '80px',
                              borderRadius: 'var(--radius-sm)',
                              background: 'var(--surface-muted)',
                              border: '1px solid var(--border)',
                              display: 'flex',
                              alignItems: 'center',
                              justifyContent: 'center',
                              overflow: 'hidden',
                              flexShrink: 0
                            }}
                          >
                            {primaryImg ? (
                              <img src={primaryImg} alt={item?.name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                            ) : (
                              <Package size={32} color="var(--text-muted)" />
                            )}
                          </div>

                          <div>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.25rem' }}>
                              <h3 style={{ margin: 0, fontSize: '1.0625rem' }}>{item?.name || 'Electronic Item'}</h3>
                              <StatusChip status={item?.selectedRecoveryRoute || 'Donate'} type="route" />
                              <span
                                style={{
                                  fontSize: '0.6875rem',
                                  padding: '0.2rem 0.5rem',
                                  borderRadius: '12px',
                                  background: 'rgba(245, 158, 11, 0.15)',
                                  color: '#d97706',
                                  fontWeight: 600
                                }}
                              >
                                Delivered at Receiving Dock
                              </span>
                            </div>

                            <div style={{ fontSize: '0.8125rem', color: 'var(--text-muted)', marginBottom: '0.5rem' }}>
                              Category: <strong>{item?.category?.name || item?.brand || 'Electronics'}</strong> | Model: <strong>{item?.model || 'N/A'}</strong>
                            </div>

                            {item?.conditionDescription && (
                              <div
                                style={{
                                  fontSize: '0.8125rem',
                                  padding: '0.5rem 0.75rem',
                                  background: 'var(--surface-muted)',
                                  borderRadius: 'var(--radius-sm)',
                                  border: '1px solid var(--border)',
                                  maxWidth: '560px'
                                }}
                              >
                                <span style={{ fontWeight: 600, color: 'var(--text-muted)' }}>Customer Reported Condition: </span>
                                <span>{item.conditionDescription}</span>
                              </div>
                            )}
                          </div>
                        </div>

                        {/* Handover & Delivery Details */}
                        <div
                          style={{
                            minWidth: '220px',
                            background: 'var(--surface-muted)',
                            padding: '0.875rem 1rem',
                            borderRadius: 'var(--radius-sm)',
                            border: '1px solid var(--border)',
                            fontSize: '0.8125rem'
                          }}
                        >
                          <div style={{ display: 'flex', alignItems: 'center', gap: '0.375rem', marginBottom: '0.35rem' }}>
                            <Truck size={14} color="var(--primary)" />
                            <span>Delivered by: <strong>{c.assignedAgentName || 'Collection Agent'}</strong></span>
                          </div>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '0.375rem', marginBottom: '0.35rem', color: 'var(--text-muted)' }}>
                            <User size={14} />
                            <span>Customer: {c.customerName || 'Customer'}</span>
                          </div>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '0.375rem', color: 'var(--text-muted)' }}>
                            <Clock size={14} />
                            <span>{handoverTime ? new Date(handoverTime).toLocaleString() : 'Recently delivered'}</span>
                          </div>
                        </div>
                      </div>

                      {/* Action Bar */}
                      <div
                        style={{
                          marginTop: '1rem',
                          paddingTop: '0.875rem',
                          borderTop: '1px solid var(--border)',
                          display: 'flex',
                          justifyContent: 'space-between',
                          alignItems: 'center',
                          flexWrap: 'wrap',
                          gap: '0.75rem'
                        }}
                      >
                        <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                          Inspect the item, unbox package, take intake photo, and confirm receipt below.
                        </div>

                        <button
                          onClick={() => openInspectionModal(c)}
                          className="btn btn-primary btn-sm"
                          style={{ minWidth: '180px', display: 'flex', alignItems: 'center', gap: '0.375rem' }}
                        >
                          <Camera size={16} />
                          <span>Inspect & Confirm Receipt</span>
                        </button>
                      </div>
                    </div>
                  )
                })}
              </div>
            )}
          </div>
        )}

        {/* Content Tab 2: Intake Archive & History */}
        {activeTab === 'history' && (
          <div>
            {completedIntakes.length === 0 ? (
              <div className="card" style={{ textAlign: 'center', padding: '3.5rem 1.5rem' }}>
                <p style={{ color: 'var(--text-muted)' }}>No completed intakes in the archive yet.</p>
              </div>
            ) : (
              <div className="table-container">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>Received Item</th>
                      <th>Intake Photo</th>
                      <th>Intake Condition</th>
                      <th>Partner Feedback / Defect Notes</th>
                      <th>Delivered By</th>
                      <th>Confirmed At</th>
                    </tr>
                  </thead>
                  <tbody>
                    {completedIntakes.map((c) => (
                      <tr key={c.id}>
                        <td>
                          <div style={{ fontWeight: 600 }}>{c.item?.name || 'Device'}</div>
                          <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                            {c.item?.brand} {c.item?.model}
                          </div>
                        </td>
                        <td>
                          {c.partnerPhotoUrl ? (
                            <a
                              href={c.partnerPhotoUrl}
                              target="_blank"
                              rel="noreferrer"
                              title="Click to view full intake photo"
                              style={{ display: 'inline-block' }}
                            >
                              <img
                                src={c.partnerPhotoUrl}
                                alt="Intake receipt"
                                style={{
                                  width: '48px',
                                  height: '48px',
                                  objectFit: 'cover',
                                  borderRadius: 'var(--radius-sm)',
                                  border: '1px solid var(--border)'
                                }}
                              />
                            </a>
                          ) : (
                            <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>No photo</span>
                          )}
                        </td>
                        <td>
                          {c.partnerReceivedConditionOk === false ? (
                            <span
                              style={{
                                display: 'inline-flex',
                                alignItems: 'center',
                                gap: '0.25rem',
                                padding: '0.2rem 0.5rem',
                                borderRadius: '12px',
                                background: 'rgba(239, 68, 68, 0.1)',
                                color: '#ef4444',
                                fontSize: '0.75rem',
                                fontWeight: 600
                              }}
                            >
                              <AlertTriangle size={12} />
                              <span>Defect / Damaged</span>
                            </span>
                          ) : (
                            <span
                              style={{
                                display: 'inline-flex',
                                alignItems: 'center',
                                gap: '0.25rem',
                                padding: '0.2rem 0.5rem',
                                borderRadius: '12px',
                                background: 'rgba(16, 185, 129, 0.1)',
                                color: '#10b981',
                                fontSize: '0.75rem',
                                fontWeight: 600
                              }}
                            >
                              <CheckCircle2 size={12} />
                              <span>Condition Verified</span>
                            </span>
                          )}
                        </td>
                        <td style={{ fontSize: '0.8125rem', maxWidth: '280px' }}>
                          {c.partnerFeedback || <span style={{ color: 'var(--text-muted)' }}>No extra remarks</span>}
                        </td>
                        <td style={{ fontSize: '0.8125rem' }}>
                          <div>{c.assignedAgentName || 'Agent'}</div>
                          <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{c.customerName}</div>
                        </td>
                        <td style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                          {c.partnerConfirmedAt ? new Date(c.partnerConfirmedAt).toLocaleString() : new Date(c.createdAt).toLocaleDateString()}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}

        {/* Inspect & Confirm Intake Modal */}
        {inspectingItem && (
          <div
            style={{
              position: 'fixed',
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              backgroundColor: 'rgba(0,0,0,0.6)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              zIndex: 1000,
              padding: '1.25rem'
            }}
          >
            <div className="card" style={{ maxWidth: '640px', width: '100%', maxHeight: '92vh', overflowY: 'auto', padding: '1.75rem' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem', paddingBottom: '0.75rem', borderBottom: '1px solid var(--border)' }}>
                <div>
                  <h3 style={{ margin: 0, fontSize: '1.1875rem' }}>Facility Item Intake & Receipt Confirmation</h3>
                  <div style={{ fontSize: '0.8125rem', color: 'var(--text-muted)', marginTop: '0.2rem' }}>
                    Inspect the received package, take an unboxing photo, and record intake feedback.
                  </div>
                </div>
                <button onClick={() => setInspectingItem(null)} className="btn btn-secondary btn-sm">
                  <X size={16} />
                </button>
              </div>

              {modalError && (
                <div className="alert alert-error" style={{ marginBottom: '1rem' }}>
                  <AlertTriangle size={18} />
                  <span>{modalError}</span>
                </div>
              )}

              {/* Item Info Summary */}
              <div
                style={{
                  background: 'var(--surface-muted)',
                  padding: '0.875rem 1rem',
                  borderRadius: 'var(--radius-sm)',
                  border: '1px solid var(--border)',
                  marginBottom: '1.25rem',
                  fontSize: '0.8125rem'
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.25rem' }}>
                  <strong style={{ fontSize: '0.9375rem' }}>{inspectingItem.item?.name}</strong>
                  <StatusChip status={inspectingItem.item?.selectedRecoveryRoute || 'Donate'} type="route" />
                </div>
                <div style={{ color: 'var(--text-muted)' }}>
                  Customer: <strong>{inspectingItem.customerName}</strong> ({inspectingItem.customerAddress})
                </div>
                <div style={{ color: 'var(--text-muted)', marginTop: '0.2rem' }}>
                  Collection Agent: <strong>{inspectingItem.assignedAgentName || 'Agent'}</strong>
                </div>
              </div>

              <form onSubmit={handleConfirmIntake}>
                {/* Step 1: Upload Intake Photo */}
                <div className="form-group" style={{ marginBottom: '1.25rem' }}>
                  <label className="form-label" style={{ fontWeight: 600 }}>
                    1. Upload Intake Photo of Received Item *
                  </label>
                  <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', margin: '0 0 0.5rem 0' }}>
                    Capture or upload a clear photo of the unboxed device on your receiving dock for audit and condition verification.
                  </p>

                  {photoPreview ? (
                    <div style={{ position: 'relative', width: '100%', height: '200px', borderRadius: 'var(--radius-sm)', overflow: 'hidden', border: '1px solid var(--border)' }}>
                      <img src={photoPreview} alt="Intake Preview" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                      <button
                        type="button"
                        onClick={() => {
                          setPhotoFile(null)
                          setPhotoPreview(null)
                        }}
                        style={{
                          position: 'absolute',
                          top: '8px',
                          right: '8px',
                          padding: '0.35rem 0.6rem',
                          background: 'rgba(0,0,0,0.7)',
                          color: '#fff',
                          borderRadius: 'var(--radius-sm)',
                          border: 'none',
                          cursor: 'pointer',
                          fontSize: '0.75rem'
                        }}
                      >
                        Change Photo
                      </button>
                    </div>
                  ) : (
                    <label
                      style={{
                        display: 'flex',
                        flexDirection: 'column',
                        alignItems: 'center',
                        justifyContent: 'center',
                        border: '2px dashed var(--border)',
                        borderRadius: 'var(--radius-sm)',
                        padding: '1.5rem',
                        cursor: 'pointer',
                        background: 'var(--surface)'
                      }}
                    >
                      <Camera size={28} color="var(--primary)" style={{ marginBottom: '0.5rem' }} />
                      <span style={{ fontSize: '0.8125rem', fontWeight: 600 }}>Click to capture or upload received item photo</span>
                      <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.25rem' }}>PNG, JPG, or WebP up to 10MB</span>
                      <input
                        type="file"
                        accept="image/*"
                        onChange={handlePhotoSelect}
                        style={{ display: 'none' }}
                      />
                    </label>
                  )}
                </div>

                {/* Step 2: Physical Condition Assessment */}
                <div className="form-group" style={{ marginBottom: '1.25rem' }}>
                  <label className="form-label" style={{ fontWeight: 600 }}>
                    2. Physical Condition & Damage Inspection
                  </label>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem', marginTop: '0.35rem' }}>
                    <button
                      type="button"
                      onClick={() => setConditionOk(true)}
                      style={{
                        padding: '0.75rem',
                        borderRadius: 'var(--radius-sm)',
                        border: conditionOk ? '2px solid #10b981' : '1px solid var(--border)',
                        background: conditionOk ? 'rgba(16, 185, 129, 0.08)' : 'var(--surface-muted)',
                        textAlign: 'left',
                        cursor: 'pointer'
                      }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', fontWeight: 600, fontSize: '0.8125rem', color: conditionOk ? '#10b981' : 'var(--text-main)' }}>
                        <CheckCircle2 size={16} />
                        <span>Condition Matches</span>
                      </div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.25rem' }}>
                        No transit damages; physical state matches reported description.
                      </div>
                    </button>

                    <button
                      type="button"
                      onClick={() => setConditionOk(false)}
                      style={{
                        padding: '0.75rem',
                        borderRadius: 'var(--radius-sm)',
                        border: !conditionOk ? '2px solid #ef4444' : '1px solid var(--border)',
                        background: !conditionOk ? 'rgba(239, 68, 68, 0.08)' : 'var(--surface-muted)',
                        textAlign: 'left',
                        cursor: 'pointer'
                      }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', fontWeight: 600, fontSize: '0.8125rem', color: !conditionOk ? '#ef4444' : 'var(--text-main)' }}>
                        <AlertTriangle size={16} />
                        <span>Damages / Defects Detected</span>
                      </div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.25rem' }}>
                        Cracks, missing components, or transit damage observed upon unboxing.
                      </div>
                    </button>
                  </div>
                </div>

                {/* Step 3: Intake Feedback Remarks */}
                <div className="form-group" style={{ marginBottom: '1.5rem' }}>
                  <label className="form-label" style={{ fontWeight: 600 }}>
                    3. Intake Feedback & Service Remarks
                  </label>
                  <textarea
                    rows={3}
                    className="form-input"
                    placeholder="Enter notes on physical inspection, unboxing condition, serial verification, or defect assessment..."
                    value={feedback}
                    onChange={(e) => setFeedback(e.target.value)}
                    style={{ resize: 'vertical' }}
                  />
                </div>

                <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.75rem', paddingTop: '1rem', borderTop: '1px solid var(--border)' }}>
                  <button
                    type="button"
                    onClick={() => setInspectingItem(null)}
                    disabled={submitting}
                    className="btn btn-secondary"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={submitting}
                    className="btn btn-primary"
                    style={{ minWidth: '180px' }}
                  >
                    {submitting ? 'Confirming Intake...' : 'Confirm Received Item'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}
      </div>
    </>
  )
}
