import React, { useEffect, useState } from 'react'
import { useParams, Link, useNavigate } from 'react-router'
import {
  ShieldCheck,
  CheckCircle2,
  AlertCircle,
  Package,
  MapPin,
  Phone,
  Calendar,
  Clock,
  Truck,
  User,
  ExternalLink,
  Check,
  Building2,
  Lock,
  ArrowLeft,
  ArrowRight
} from 'lucide-react'
import { apiClient } from '../../../shared/services/apiClient.js'
import { useAuth } from '../../../shared/context/AuthContext.jsx'
import { StatusChip } from '../../../shared/components/StatusChip.jsx'
import { TopBar } from '../../../shared/components/TopBar.jsx'

export function HandoverVerificationPage() {
  const { id } = useParams() // recoveryRequestId
  const navigate = useNavigate()
  const { user } = useAuth()

  const [pass, setPass] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [success, setSuccess] = useState('')
  const [agentNote, setAgentNote] = useState('Inspected and collected on-site via Digital Handover Pass verification.')
  const [inspectionChecks, setInspectionChecks] = useState({})

  const handleBackToRoute = () => {
    const jobId = pass?.collectionRequestId
    const recoveryId = pass?.recoveryRequestId || id
    navigate(`/agent/jobs${jobId ? `?jobId=${jobId}` : ''}`, {
      state: {
        selectedJobId: jobId,
        recoveryRequestId: recoveryId
      }
    })
  }

  useEffect(() => {
    loadPassData()
  }, [id])

  const loadPassData = async () => {
    try {
      setLoading(true)
      setError('')
      const res = await apiClient.get(`/api/recovery/${id}/handover-pass`)
      setPass(res.data)
      setInspectionChecks({})
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to load handover pass. Please verify the QR code.')
    } finally {
      setLoading(false)
    }
  }

  const getChecklistItems = (passData) => {
    if (!passData) return []
    const items = [
      {
        id: 'identity',
        tag: 'Identity & Condition',
        type: 'identity',
        label: `Item Identity Check: Physically verified brand & model (${passData.brand || ''} ${passData.model || ''} - ${passData.itemName}) matches customer manifest. Reported condition: "${passData.conditionDescription || 'Good'}" confirmed.`
      }
    ]

    if (passData.preparationSteps && passData.preparationSteps.length > 0) {
      passData.preparationSteps.forEach((step, idx) => {
        items.push({
          id: `step_${idx}`,
          tag: 'Agent 2 Preparation Protocol',
          type: 'agent2_prep',
          label: step
        })
      })
    } else {
      items.push({
        id: 'default_prep',
        tag: 'Preparation Protocol',
        type: 'agent2_prep',
        label: 'Customer personal accounts signed out and factory reset verified.'
      })
    }

    if (passData.safetyNotes && passData.safetyNotes.length > 0) {
      passData.safetyNotes.forEach((note, idx) => {
        items.push({
          id: `safety_${idx}`,
          tag: 'Agent 2 Safety Precaution',
          type: 'agent2_safety',
          label: note
        })
      })
    }

    return items
  }

  const checklistItems = getChecklistItems(pass)
  const isAllInspected = checklistItems.length > 0 && checklistItems.every((item) => !!inspectionChecks[item.id])
  const checkedCount = checklistItems.filter((item) => !!inspectionChecks[item.id]).length

  const toggleCheck = (key) => {
    setInspectionChecks((prev) => ({ ...prev, [key]: !prev[key] }))
  }

  const handleCheckAll = () => {
    const next = {}
    checklistItems.forEach((item) => {
      next[item.id] = true
    })
    setInspectionChecks(next)
  }

  const isAgent = user?.role === 'CollectionAgent' || user?.role === 'Admin'
  const isAssignedAgent = user && pass && (user.id === pass.assignedAgentId || user.role === 'Admin')

  // Agent confirms on-site pickup
  const handleMarkPickedUp = async () => {
    if (!pass?.collectionRequestId) {
      setError('No active collection schedule found for this item.')
      return
    }

    try {
      setSubmitting(true)
      setError('')
      setSuccess('')

      await apiClient.post(`/api/agent/collections/${pass.collectionRequestId}/status`, {
        status: 'Collected',
        note: agentNote || 'Item physically verified and collected via Digital QR Pass.'
      })

      setSuccess('Item successfully verified and marked as Picked Up!')
      // Refresh pass data to reflect new status
      await loadPassData()
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to update pickup status.')
    } finally {
      setSubmitting(false)
    }
  }

  if (loading) {
    return (
      <div style={{ padding: '4rem 1rem', textAlign: 'center' }}>
        <p style={{ color: 'var(--text-muted)' }}>Verifying digital handover manifest...</p>
      </div>
    )
  }

  if (error && !pass) {
    return (
      <div className="content-container" style={{ maxWidth: '640px', padding: '3rem 1rem', textAlign: 'center' }}>
        <div className="card" style={{ padding: '3rem 2rem' }}>
          <AlertCircle size={44} color="var(--error)" style={{ margin: '0 auto 1rem' }} />
          <h2>Handover Pass Not Found</h2>
          <p style={{ color: 'var(--text-muted)', margin: '0.5rem 0 1.5rem', fontSize: '0.875rem' }}>
            {error}
          </p>
          <Link to="/" className="btn btn-secondary">
            Return to Home
          </Link>
        </div>
      </div>
    )
  }

  return (
    <>
      <TopBar
        title="Handover Verification"
        action={
          user?.role === 'CollectionAgent' || user?.role === 'Admin' ? (
            <button
              onClick={handleBackToRoute}
              className="btn btn-secondary btn-sm"
              type="button"
              style={{ display: 'inline-flex', alignItems: 'center', gap: '0.375rem' }}
            >
              <ArrowLeft size={16} />
              <span>Back to Route</span>
            </button>
          ) : null
        }
      />

      <div className="content-container" style={{ maxWidth: '780px' }}>
        {/* Verification Success / Error alerts */}
        {error && (
          <div className="alert alert-error" style={{ marginBottom: '1.25rem' }}>
            <AlertCircle size={18} />
            <span>{error}</span>
          </div>
        )}

        {success && (
          <div className="alert alert-success" style={{ marginBottom: '1.25rem', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '0.75rem' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <CheckCircle2 size={18} />
              <span>{success}</span>
            </div>
            {(user?.role === 'CollectionAgent' || user?.role === 'Admin') && (
              <button
                onClick={handleBackToRoute}
                className="btn btn-primary btn-sm"
                type="button"
                style={{ padding: '0.35rem 0.75rem', fontSize: '0.8125rem', display: 'inline-flex', alignItems: 'center', gap: '0.375rem' }}
              >
                <span>Continue Route &amp; Hand Over</span>
                <ArrowRight size={14} />
              </button>
            )}
          </div>
        )}

        {/* Official Header Banner */}
        <div
          className="card"
          style={{
            background: 'linear-gradient(135deg, #0F172A 0%, #1E293B 100%)',
            color: '#FFFFFF',
            borderRadius: 'var(--radius-lg)',
            padding: '1.5rem',
            marginBottom: '1.5rem',
            boxShadow: '0 8px 24px rgba(0, 0, 0, 0.12)'
          }}
        >
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '1rem' }}>
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.35rem' }}>
                <span
                  style={{
                    background: 'rgba(16, 185, 129, 0.2)',
                    color: '#34D399',
                    border: '1px solid #059669',
                    fontSize: '0.7rem',
                    fontWeight: 700,
                    letterSpacing: '0.05em',
                    padding: '0.2rem 0.6rem',
                    borderRadius: 'var(--radius-full)',
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '0.3rem'
                  }}
                >
                  <ShieldCheck size={13} />
                  AUTHENTICATED MANIFEST
                </span>
                <span style={{ fontSize: '0.8rem', color: '#94A3B8' }}>• LoopWorth Secure Handover Protocol</span>
              </div>
              <h1 style={{ color: '#FFFFFF', fontSize: '1.5rem', margin: '0.25rem 0' }}>
                {pass.itemName}
              </h1>
              <div style={{ color: '#94A3B8', fontSize: '0.8125rem' }}>
                Category: <strong style={{ color: '#F8FAFC' }}>{pass.categoryName}</strong>
                {pass.brand && ` • Brand: ${pass.brand}`}
                {pass.model && ` • Model: ${pass.model}`}
              </div>
            </div>

            <div style={{ textAlign: 'right' }}>
              <div style={{ fontSize: '0.7rem', color: '#94A3B8', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                Pass Reference
              </div>
              <div style={{ fontFamily: 'monospace', fontSize: '1.125rem', fontWeight: 700, color: '#38BDF8', marginTop: '0.15rem' }}>
                {pass.passReferenceCode}
              </div>
              <div style={{ marginTop: '0.35rem' }}>
                <span
                  style={{
                    fontSize: '0.75rem',
                    fontWeight: 600,
                    padding: '0.2rem 0.5rem',
                    borderRadius: 'var(--radius-full)',
                    background: pass.selectedRoute === 'Recycle' ? 'rgba(59, 130, 246, 0.2)' : 'rgba(16, 185, 129, 0.2)',
                    color: pass.selectedRoute === 'Recycle' ? '#93C5FD' : '#A7F3D0'
                  }}
                >
                  Route: {pass.selectedRoute}
                </span>
              </div>
            </div>
          </div>
        </div>

        {/* Grid: Item Proof & Customer Details */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '1.25rem', marginBottom: '1.5rem' }}>
          {/* Item Proof & Condition */}
          <div className="card">
            <h3 style={{ fontSize: '1rem', fontWeight: 600, marginBottom: '0.75rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <Package size={16} color="var(--primary)" />
              <span>Item Identity & Proof</span>
            </h3>

            {pass.primaryImageUrl && (
              <div style={{ marginBottom: '0.75rem', borderRadius: 'var(--radius-sm)', overflow: 'hidden', maxHeight: '180px', background: '#F1F5F9' }}>
                <img
                  src={pass.primaryImageUrl}
                  alt={pass.itemName}
                  style={{ width: '100%', height: '180px', objectFit: 'cover', display: 'block' }}
                />
              </div>
            )}

            <div style={{ fontSize: '0.8125rem', color: 'var(--text-main)', marginBottom: '0.75rem' }}>
              <div style={{ fontSize: '0.7rem', fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase', marginBottom: '0.25rem' }}>
                Customer Reported Condition:
              </div>
              <p style={{ margin: 0, lineHeight: 1.5, background: '#F8FAFC', padding: '0.625rem', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-light)' }}>
                {pass.conditionDescription || 'No condition details provided.'}
              </p>
            </div>

            <div style={{ fontSize: '0.8125rem', borderTop: '1px solid var(--border-light)', paddingTop: '0.625rem' }}>
              <span style={{ color: 'var(--text-muted)' }}>Target Facility: </span>
              <strong>{pass.partnerName || pass.requiredPartnerType || 'Certified Recovery Facility'}</strong>
            </div>
          </div>

          {/* Customer Pickup Location & Admin Audit */}
          <div className="card">
            <h3 style={{ fontSize: '1rem', fontWeight: 600, marginBottom: '0.75rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <User size={16} color="var(--primary)" />
              <span>Customer Verification</span>
            </h3>

            <div style={{ background: '#F8FAFC', padding: '0.75rem', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-light)', marginBottom: '0.75rem' }}>
              <div style={{ fontWeight: 600, color: 'var(--dark)', fontSize: '0.9375rem', marginBottom: '0.25rem' }}>
                {pass.customerName}
              </div>

              {pass.customerPhone && (
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.375rem', fontSize: '0.8125rem', marginTop: '0.25rem' }}>
                  <Phone size={13} color="var(--primary)" />
                  <a href={`tel:${pass.customerPhone}`} style={{ color: 'var(--primary)', fontWeight: 600, textDecoration: 'none' }}>
                    {pass.customerPhone}
                  </a>
                </div>
              )}

              <div style={{ display: 'flex', alignItems: 'flex-start', gap: '0.375rem', fontSize: '0.8125rem', color: 'var(--text-main)', marginTop: '0.4rem' }}>
                <MapPin size={14} color="var(--primary)" style={{ flexShrink: 0, marginTop: '0.15rem' }} />
                <span>
                  {pass.customerAddress ? `${pass.customerAddress}, ${pass.customerTown || ''} (${pass.customerDistrict || ''})` : (pass.customerTown || 'Address not specified')}
                </span>
              </div>
            </div>

            {/* Admin Audit Stamp */}
            <div style={{ borderTop: '1px solid var(--border-light)', paddingTop: '0.75rem', fontSize: '0.8125rem' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.375rem', color: '#065F46', fontWeight: 600, marginBottom: '0.25rem' }}>
                <ShieldCheck size={15} />
                <span>LoopWorth Admin Approved</span>
              </div>
              <div style={{ color: 'var(--text-muted)', fontSize: '0.75rem' }}>
                Verified on: {pass.approvedAt ? new Date(pass.approvedAt).toLocaleDateString() : 'Audited'}
              </div>
              {pass.adminNote && (
                <div style={{ fontStyle: 'italic', color: 'var(--text-main)', marginTop: '0.25rem', fontSize: '0.75rem' }}>
                  "{pass.adminNote}"
                </div>
              )}
            </div>

            {/* Collection schedule status */}
            <div style={{ borderTop: '1px solid var(--border-light)', paddingTop: '0.75rem', marginTop: '0.75rem', fontSize: '0.8125rem' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ color: 'var(--text-muted)' }}>Collection Status:</span>
                <StatusChip status={pass.collectionStatus || 'Scheduled'} />
              </div>
              {pass.assignedAgentName && (
                <div style={{ marginTop: '0.25rem', fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                  Assigned Agent: <strong style={{ color: 'var(--dark)' }}>{pass.assignedAgentName}</strong>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* On-Site Inspection Checklist for the Agent */}
        <div className="card" style={{ marginBottom: '1.5rem', background: '#FFFFFF', border: '1px solid var(--border)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem', flexWrap: 'wrap', gap: '0.5rem' }}>
            <div>
              <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <CheckCircle2 size={16} color="var(--primary)" />
                <span>Agent 2 On-Site Inspection Checklist</span>
              </h3>
              <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                Physically inspect and check off all items before accepting pickup
              </span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <button
                type="button"
                onClick={handleCheckAll}
                className="btn btn-secondary btn-sm"
                style={{ fontSize: '0.75rem', padding: '0.2rem 0.5rem' }}
                title="Mark all verified"
              >
                Check All
              </button>
              <span className={`status-chip ${isAllInspected ? 'status-approved' : 'status-revision'}`} style={{ fontSize: '0.75rem' }}>
                {checkedCount} / {checklistItems.length} Verified
              </span>
            </div>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
            {checklistItems.map((item) => {
              const checked = !!inspectionChecks[item.id]
              return (
                <label
                  key={item.id}
                  style={{
                    display: 'flex',
                    alignItems: 'flex-start',
                    gap: '0.625rem',
                    padding: '0.5rem 0.625rem',
                    borderRadius: 'var(--radius-sm)',
                    background: checked ? 'rgba(16, 185, 129, 0.06)' : 'var(--surface-subtle)',
                    border: `1px solid ${checked ? '#86EFAC' : 'var(--border-light)'}`,
                    cursor: 'pointer',
                    transition: 'all 0.15s ease'
                  }}
                >
                  <input
                    type="checkbox"
                    checked={checked}
                    onChange={() => toggleCheck(item.id)}
                    style={{ marginTop: '0.15rem', accentColor: 'var(--primary)', cursor: 'pointer' }}
                  />
                  <div style={{ flex: 1, fontSize: '0.8125rem', lineHeight: 1.4 }}>
                    <span style={{
                      fontSize: '0.7rem',
                      fontWeight: 700,
                      color: item.type === 'identity' ? 'var(--dark)' : item.type === 'agent2_safety' ? '#DC2626' : 'var(--primary)',
                      textTransform: 'uppercase',
                      display: 'block',
                      marginBottom: '0.15rem'
                    }}>
                      {item.tag}
                    </span>
                    <span style={{ color: checked ? 'var(--dark)' : 'var(--text-main)', fontWeight: checked ? 500 : 400 }}>
                      {item.label}
                    </span>
                  </div>
                </label>
              )
            })}
          </div>

          {!isAllInspected && (
            <div style={{ marginTop: '0.75rem', fontSize: '0.75rem', color: '#D97706', display: 'flex', alignItems: 'center', gap: '0.375rem' }}>
              <AlertCircle size={14} />
              <span>Please physically verify and tick all {checklistItems.length} items above to unlock pickup.</span>
            </div>
          )}

          {isAllInspected && (
            <div style={{ marginTop: '0.75rem', fontSize: '0.75rem', color: '#16A34A', display: 'flex', alignItems: 'center', gap: '0.375rem', fontWeight: 600 }}>
              <CheckCircle2 size={14} />
              <span>All Agent 2 criteria verified! You may now confirm and accept doorstep pickup.</span>
            </div>
          )}
        </div>

        {/* Action Panel for Collection Agent */}
        <div
          className="card"
          style={{
            background: isAllInspected ? '#F0FDF4' : '#F8FAFC',
            border: `1px solid ${isAllInspected ? '#86EFAC' : 'var(--border)'}`,
            padding: '1.25rem'
          }}
        >
          {pass.collectionStatus === 'Collected' || pass.collectionStatus === 'DeliveredToPartner' || pass.collectionStatus === 'Completed' ? (
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', color: '#15803d' }}>
              <CheckCircle2 size={24} />
              <div>
                <div style={{ fontWeight: 700, fontSize: '1rem' }}>Handover Already Completed</div>
                <div style={{ fontSize: '0.8125rem', color: '#166534' }}>
                  This item has already been marked as <strong>{pass.collectionStatus}</strong>.
                </div>
              </div>
            </div>
          ) : isAgent ? (
            <div>
              <div style={{ marginBottom: '1rem' }}>
                <h4 style={{ margin: '0 0 0.25rem', color: 'var(--dark)' }}>Complete Doorstep Verification</h4>
                <div style={{ fontSize: '0.8125rem', color: 'var(--text-muted)' }}>
                  Once the checklist items are physically verified, confirm pickup to immediately update both the customer and operations team.
                </div>
              </div>

              <div className="form-group" style={{ marginBottom: '1rem' }}>
                <label className="form-label" style={{ fontSize: '0.75rem' }}>Field Handover Notes / Observations</label>
                <input
                  type="text"
                  className="form-input"
                  value={agentNote}
                  onChange={(e) => setAgentNote(e.target.value)}
                  placeholder="e.g. Verified serial, packaged securely, collected from customer..."
                />
              </div>

              <button
                onClick={handleMarkPickedUp}
                disabled={!isAllInspected || submitting}
                className="btn btn-primary"
                style={{ width: '100%', padding: '0.75rem 1.25rem', fontSize: '0.9375rem' }}
              >
                <Check size={18} />
                <span>
                  {submitting
                    ? 'Updating Pickup Status...'
                    : 'Confirm Physical Inspection & Mark Picked Up'}
                </span>
              </button>

              {!isAllInspected && (
                <div style={{ fontSize: '0.75rem', color: 'var(--warning)', marginTop: '0.5rem', textAlign: 'center' }}>
                  Please confirm all physical inspection checklist items above before completing handover.
                </div>
              )}
            </div>
          ) : (
            <div style={{ textAlign: 'center', padding: '0.5rem' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.5rem', color: 'var(--primary)', fontWeight: 600, marginBottom: '0.25rem' }}>
                <Lock size={16} />
                <span>Collection Agent Authorization</span>
              </div>
              <p style={{ fontSize: '0.8125rem', color: 'var(--text-muted)', margin: '0 0 0.75rem' }}>
                Are you the assigned collection agent for this item? Sign in to complete physical verification and mark it as picked up.
              </p>
              <Link
                to={`/login?redirect=/verify-handover/${id}`}
                className="btn btn-primary btn-sm"
              >
                Sign In as Collection Agent
              </Link>
            </div>
          )}
        </div>
      </div>
    </>
  )
}
