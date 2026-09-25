import React, { useEffect, useState } from 'react'
import { useParams, useNavigate, Link, useLocation } from 'react-router'
import { ArrowLeft, Sparkles, AlertCircle, CheckCircle2, ArrowRight, ShieldCheck, Edit3, X, AlertTriangle, Lock, Leaf, RefreshCw } from 'lucide-react'
import { apiClient } from '../../../shared/services/apiClient.js'
import { StatusChip } from '../../../shared/components/StatusChip.jsx'
import { TopBar } from '../../../shared/components/TopBar.jsx'

export function ItemDetailsPage() {
  const { id } = useParams()
  const navigate = useNavigate()
  const location = useLocation()
  const [item, setItem] = useState(null)
  const [assessment, setAssessment] = useState(null)
  const [loading, setLoading] = useState(true)
  const [assessing, setAssessing] = useState(false)
  const [routeSelecting, setRouteSelecting] = useState(false)
  const [recoveryStarting, setRecoveryStarting] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')
  const [acknowledgingEco, setAcknowledgingEco] = useState(false)
  const [runningEco, setRunningEco] = useState(false)
  const [switchingRoute, setSwitchingRoute] = useState(false)

  // Category mismatch & edit modal states
  const [categoryMismatch, setCategoryMismatch] = useState(null)
  const [editModalOpen, setEditModalOpen] = useState(false)
  const [categories, setCategories] = useState([])
  const [editForm, setEditForm] = useState({
    name: '',
    categoryId: '',
    brand: '',
    model: '',
    conditionDescription: ''
  })
  const [savingEdit, setSavingEdit] = useState(false)

  useEffect(() => {
    loadData()
    loadCategories()
  }, [id])

  useEffect(() => {
    if (new URLSearchParams(location.search).get('edit') === 'true') {
      setEditModalOpen(true)
    }
  }, [location.search])

  const loadCategories = async () => {
    try {
      const res = await apiClient.get('/api/categories')
      setCategories(Array.isArray(res.data) ? res.data : [])
    } catch {
      // categories can fallback
    }
  }

  const loadData = async () => {
    try {
      setLoading(true)
      const res = await apiClient.get(`/api/items/${id}`)
      setItem(res.data)
      setEditForm({
        name: res.data.name || '',
        categoryId: res.data.categoryId || '',
        brand: res.data.brand || '',
        model: res.data.model || '',
        conditionDescription: res.data.conditionDescription || ''
      })

      // Auto-trigger eco evaluation if not yet assessed
      if (!res.data.ecoAssessment && !res.data.ecoHazardReportJson) {
        try {
          const ecoRes = await apiClient.post(`/api/items/${id}/eco-assessment`)
          setItem(prev => prev ? { ...prev, ecoAssessment: ecoRes.data, ecoHazardAcknowledged: !ecoRes.data.isHarmfulToEnvironment } : prev)
        } catch { }
      }

      try {
        const assessRes = await apiClient.get(`/api/items/${id}/assessment`)
        setAssessment(assessRes.data)
      } catch {
        setAssessment(null)
      }
    } catch (err) {
      setError('Failed to load item details.')
    } finally {
      setLoading(false)
    }
  }

  // Acknowledge environmental precautions
  const handleAcknowledgeEco = async () => {
    setAcknowledgingEco(true)
    setError('')
    try {
      await apiClient.post(`/api/items/${id}/eco-acknowledge`)
      setSuccess('Environmental precautions acknowledged. You may now proceed with advisory assessment.')
      await loadData()
    } catch {
      setError('Failed to acknowledge environmental precautions.')
    } finally {
      setAcknowledgingEco(false)
    }
  }

  // Directly change route to Recycle & acknowledge hazard precautions
  const handleSwitchToRecycle = async () => {
    setSwitchingRoute(true)
    setError('')
    try {
      await apiClient.post(`/api/items/${id}/switch-to-recycle`)
      setSuccess('Recovery route updated to Recycle and environmental safety precautions acknowledged!')
      await loadData()
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to update route to Recycle.')
    } finally {
      setSwitchingRoute(false)
    }
  }

  // Manually re-run Eco Assessment
  const handleRunEco = async () => {
    setRunningEco(true)
    setError('')
    try {
      await apiClient.post(`/api/items/${id}/eco-assessment`)
      setSuccess('Environmental hazard audit re-evaluated.')
      await loadData()
    } catch {
      setError('Failed to evaluate environmental hazards.')
    } finally {
      setRunningEco(false)
    }
  }

  // Trigger AI Advisory Assessment (Agent 1)
  const handleAssess = async () => {
    setAssessing(true)
    setError('')
    setCategoryMismatch(null)
    try {
      // Submit first if in Draft
      if (item.status === 'Draft') {
        await apiClient.post(`/api/items/${id}/submit`)
      }
      const assessRes = await apiClient.post(`/api/items/${id}/assess`)
      setAssessment(assessRes.data)
      setSuccess('Advisory assessment generated successfully.')
      await loadData()
    } catch (err) {
      const resp = err.response?.data
      if (resp?.isCategoryMismatch) {
        const isDescMismatch = resp.inconsistencyType === 'DescriptionMismatch' ||
          resp.mismatchReason?.toLowerCase().includes('description inconsistency') ||
          resp.error?.toLowerCase().includes('description inconsistency');
        setCategoryMismatch({
          reason: resp.mismatchReason || resp.error,
          detectedCategory: resp.detectedCategory,
          inconsistencyType: isDescMismatch ? 'DescriptionMismatch' : 'CategoryMismatch'
        })
        await loadData()
      } else {
        setError(resp?.error || 'AI assessment failed. Please try again.')
      }
    } finally {
      setAssessing(false)
    }
  }

  // Save edited item details
  const handleSaveEdit = async (e) => {
    e.preventDefault()
    if (!editForm.name || !editForm.categoryId || !editForm.conditionDescription) {
      setError('Please fill in all required fields.')
      return
    }

    setSavingEdit(true)
    setError('')
    try {
      await apiClient.put(`/api/items/${id}`, editForm)
      setCategoryMismatch(null)
      setAssessment(null)
      setEditModalOpen(false)
      setSuccess('Item details updated successfully! Click "Run Advisory Assessment" to re-assess.')
      await loadData()
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to update item details.')
    } finally {
      setSavingEdit(false)
    }
  }

  // Customer selects route
  const handleSelectRoute = async (selectedRoute) => {
    setRouteSelecting(true)
    setError('')
    try {
      await apiClient.post(`/api/items/${id}/select-route`, { selectedRoute })
      setSuccess(`Selected route: ${selectedRoute}`)
      await loadData()
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to set recovery route.')
    } finally {
      setRouteSelecting(false)
    }
  }

  // Create recovery request and navigate to preparation plan
  const handleCreateRecovery = async () => {
    setRecoveryStarting(true)
    setError('')
    try {
      const res = await apiClient.post('/api/recovery', { itemId: id })
      navigate(`/recovery/${res.data.id}`)
    } catch (err) {
      if (err.response?.status === 409) {
        // Recovery already exists, fetch it
        const listRes = await apiClient.get('/api/recovery')
        const existing = listRes.data.find((r) => r.itemId === id)
        if (existing) {
          navigate(`/recovery/${existing.id}`)
          return
        }
      }
      setError(err.response?.data?.error || 'Failed to initiate recovery.')
    } finally {
      setRecoveryStarting(false)
    }
  }

  if (loading) {
    return (
      <div style={{ padding: '3rem', textAlign: 'center' }}>
        <p style={{ color: 'var(--text-muted)' }}>Loading item details...</p>
      </div>
    )
  }

  if (!item) {
    return (
      <div style={{ padding: '3rem', textAlign: 'center' }}>
        <p style={{ color: 'var(--error)' }}>Item not found.</p>
        <Link to="/items" className="btn btn-secondary" style={{ marginTop: '1rem' }}>Back to Items</Link>
      </div>
    )
  }

  return (
    <>
      <TopBar
        title={item.name}
        action={
          <Link to="/items" className="btn btn-secondary btn-sm">
            <ArrowLeft size={16} />
            <span>Back to Items</span>
          </Link>
        }
      />

      <div className="content-container">
        {categoryMismatch && (
          <div className="card" style={{ borderLeft: '4px solid #EF4444', background: '#FEF2F2', padding: '1.25rem', marginBottom: '1.5rem' }}>
            <div style={{ display: 'flex', alignItems: 'flex-start', gap: '0.875rem' }}>
              <AlertTriangle size={24} color="#DC2626" style={{ flexShrink: 0, marginTop: '2px' }} />
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 700, color: '#991B1B', fontSize: '1rem', marginBottom: '0.25rem' }}>
                  {categoryMismatch.inconsistencyType === 'DescriptionMismatch'
                    ? 'Agent 1 Inconsistency Detected: Description Contradiction'
                    : 'Agent 1 Inconsistency Detected: Category Mismatch'}
                </div>
                <p style={{ color: '#B91C1C', fontSize: '0.875rem', lineHeight: 1.5, margin: 0 }}>
                  {categoryMismatch.reason}
                </p>
                {categoryMismatch.detectedCategory && categoryMismatch.inconsistencyType !== 'DescriptionMismatch' && (
                  <div style={{ marginTop: '0.5rem', fontSize: '0.8125rem', color: '#7F1D1D' }}>
                    Agent 1 detected category: <strong>{categoryMismatch.detectedCategory}</strong>
                  </div>
                )}
                <div style={{ marginTop: '0.875rem' }}>
                  <button
                    type="button"
                    onClick={() => setEditModalOpen(true)}
                    className="btn btn-sm"
                    style={{ background: '#DC2626', borderColor: '#DC2626', color: '#fff' }}
                  >
                    <Edit3 size={14} />
                    <span>
                      {categoryMismatch.inconsistencyType === 'DescriptionMismatch'
                        ? 'Edit Condition Description'
                        : 'Edit Mistaken Details'}
                    </span>
                  </button>
                </div>
              </div>
            </div>
          </div>
        )}

        {error && !categoryMismatch && (
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

        {/* Feature 1: Environmental Hazard & Eco-Impact Banner */}
        {item?.ecoAssessment && (() => {
          const eco = item.ecoAssessment
          const isHarmful = eco.isHarmfulToEnvironment
          const acknowledged = item.ecoHazardAcknowledged

          if (isHarmful && !acknowledged) {
            return (
              <div style={{
                background: '#FEF2F2',
                border: '1px solid #F87171',
                borderLeft: '5px solid #DC2626',
                borderRadius: 'var(--radius-md)',
                padding: '1.25rem',
                marginBottom: '1.5rem',
                boxShadow: '0 2px 4px rgba(220, 38, 38, 0.05)'
              }}>
                <div style={{ display: 'flex', gap: '0.875rem', alignItems: 'flex-start' }}>
                  <AlertTriangle size={24} color="#DC2626" style={{ flexShrink: 0, marginTop: '2px' }} />
                  <div style={{ flex: 1 }}>
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '0.5rem', marginBottom: '0.5rem' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                        <span style={{ fontWeight: 700, color: '#991B1B', fontSize: '1rem' }}>
                          Environmental Hazard Detected
                        </span>
                        <span style={{
                          background: '#FEE2E2',
                          color: '#991B1B',
                          fontSize: '0.75rem',
                          fontWeight: 700,
                          padding: '0.15rem 0.5rem',
                          borderRadius: '4px',
                          border: '1px solid #FCA5A5'
                        }}>
                          {eco.hazardLevel?.toUpperCase()} HAZARD LEVEL
                        </span>
                      </div>
                      <span style={{ fontSize: '0.75rem', color: '#991B1B', fontWeight: 600 }}>
                        Action Required Before Assessment
                      </span>
                    </div>

                    <p style={{ color: '#7F1D1D', fontSize: '0.875rem', lineHeight: 1.5, marginBottom: '0.75rem' }}>
                      {eco.environmentalAlert}
                    </p>

                    {/* Feature 1: Donation Ineligibility Notice & Direct Switch to Recycle */}
                    {eco.canBeDonated === false && (
                      <div style={{
                        background: '#FFF1F2',
                        border: '1px solid #FECDD3',
                        borderRadius: 'var(--radius-sm)',
                        padding: '0.75rem 1rem',
                        marginBottom: '0.875rem',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between',
                        flexWrap: 'wrap',
                        gap: '0.75rem'
                      }}>
                        <div style={{ flex: 1, minWidth: '220px' }}>
                          <div style={{ fontWeight: 700, color: '#9F1239', fontSize: '0.8125rem', display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
                            <AlertTriangle size={15} color="#E11D48" />
                            <span>Donation Not Permitted (Hazardous / Damaged Device)</span>
                          </div>
                          <div style={{ fontSize: '0.75rem', color: '#BE123C', marginTop: '0.25rem', lineHeight: 1.4 }}>
                            {eco.donationUnsuitabilityReason || 'Because of the hazards and damage identified in the condition description, this item is unsafe to donate. It must be processed through certified recycling.'}
                          </div>
                        </div>
                        {item.selectedRecoveryRoute !== 'Recycle' ? (
                          <button
                            type="button"
                            onClick={handleSwitchToRecycle}
                            disabled={switchingRoute}
                            className="btn btn-sm"
                            style={{ background: '#E11D48', borderColor: '#E11D48', color: '#FFF', fontWeight: 600, fontSize: '0.75rem' }}
                          >
                            <RefreshCw size={13} className={switchingRoute ? 'spin' : ''} />
                            <span>{switchingRoute ? 'Switching to Recycle...' : 'Switch Route to Recycle'}</span>
                          </button>
                        ) : (
                          <span style={{ fontSize: '0.75rem', fontWeight: 700, color: '#166534', background: '#DCFCE7', padding: '0.2rem 0.6rem', borderRadius: '4px', border: '1px solid #86EFAC' }}>
                            ✓ Route Switched to Recycle
                          </span>
                        )}
                      </div>
                    )}

                    {/* Detected Hazards */}
                    {eco.detectedHazards && eco.detectedHazards.length > 0 && (
                      <div style={{ marginBottom: '0.75rem' }}>
                        <div style={{ fontSize: '0.75rem', fontWeight: 700, color: '#991B1B', marginBottom: '0.35rem', textTransform: 'uppercase' }}>
                          Detected Hazardous Components:
                        </div>
                        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.375rem' }}>
                          {eco.detectedHazards.map((hazard, idx) => (
                            <span key={idx} style={{
                              background: '#FFFFFF',
                              border: '1px solid #FECACA',
                              color: '#B91C1C',
                              fontSize: '0.75rem',
                              padding: '0.2rem 0.5rem',
                              borderRadius: '4px',
                              fontWeight: 500
                            }}>
                              ⚠️ {hazard}
                            </span>
                          ))}
                        </div>
                      </div>
                    )}

                    {/* Handling Precautions */}
                    {eco.handlingPrecautions && eco.handlingPrecautions.length > 0 && (
                      <div style={{
                        background: 'rgba(255, 255, 255, 0.85)',
                        border: '1px solid #FECACA',
                        borderRadius: 'var(--radius-sm)',
                        padding: '0.75rem 1rem',
                        marginBottom: '1rem'
                      }}>
                        <div style={{ fontSize: '0.75rem', fontWeight: 700, color: '#991B1B', marginBottom: '0.35rem', textTransform: 'uppercase' }}>
                          Mandatory Safety & Environmental Precautions:
                        </div>
                        <ul style={{ margin: 0, paddingLeft: '1.25rem', fontSize: '0.8125rem', color: '#7F1D1D', lineHeight: 1.5 }}>
                          {eco.handlingPrecautions.map((precaution, idx) => (
                            <li key={idx}>{precaution}</li>
                          ))}
                        </ul>
                      </div>
                    )}

                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', flexWrap: 'wrap' }}>
                      {eco.canBeDonated === false && item.selectedRecoveryRoute !== 'Recycle' ? (
                        <button
                          type="button"
                          onClick={handleSwitchToRecycle}
                          disabled={switchingRoute}
                          className="btn btn-sm"
                          style={{ background: '#DC2626', borderColor: '#DC2626', color: '#FFFFFF', fontWeight: 600 }}
                        >
                          <ShieldCheck size={16} />
                          <span>{switchingRoute ? 'Switching to Recycle...' : 'Change Route to Recycle & Acknowledge Safety'}</span>
                        </button>
                      ) : (
                        <button
                          type="button"
                          onClick={handleAcknowledgeEco}
                          disabled={acknowledgingEco}
                          className="btn btn-sm"
                          style={{ background: '#DC2626', borderColor: '#DC2626', color: '#FFFFFF', fontWeight: 600 }}
                        >
                          <ShieldCheck size={16} />
                          <span>{acknowledgingEco ? 'Saving Acknowledgment...' : 'I Acknowledge These Environmental Precautions'}</span>
                        </button>
                      )}

                      <button
                        type="button"
                        onClick={handleRunEco}
                        disabled={runningEco}
                        className="btn btn-secondary btn-sm"
                        style={{ fontSize: '0.75rem' }}
                      >
                        <RefreshCw size={12} />
                        <span>Re-check Hazards</span>
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            )
          }

          if (isHarmful && acknowledged) {
            const isWrongRoute = eco.canBeDonated === false && item.selectedRecoveryRoute === 'Donate'
            return (
              <div style={{
                background: isWrongRoute ? '#FEF2F2' : '#FFFBEB',
                border: `1px solid ${isWrongRoute ? '#FCA5A5' : '#FDE68A'}`,
                borderLeft: `5px solid ${isWrongRoute ? '#DC2626' : '#D97706'}`,
                borderRadius: 'var(--radius-md)',
                padding: '0.875rem 1.25rem',
                marginBottom: '1.5rem',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                flexWrap: 'wrap',
                gap: '0.5rem'
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <ShieldCheck size={20} color={isWrongRoute ? '#DC2626' : '#D97706'} />
                  <div>
                    <span style={{ fontWeight: 600, color: isWrongRoute ? '#991B1B' : '#92400E', fontSize: '0.875rem' }}>
                      Environmental Hazard Precautions Acknowledged ({eco.hazardLevel} Hazard Level)
                    </span>
                    <div style={{ fontSize: '0.75rem', color: isWrongRoute ? '#B91C1C' : '#B45309' }}>
                      {isWrongRoute
                        ? '⚠️ This item cannot be donated due to hazard severity. You must switch your route to Recycle to proceed.'
                        : 'Hazardous components logged for courier & partner safe handling. Safe for certified recycling.'}
                    </div>
                  </div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  {isWrongRoute && (
                    <button
                      type="button"
                      onClick={handleSwitchToRecycle}
                      disabled={switchingRoute}
                      className="btn btn-sm"
                      style={{ background: '#DC2626', borderColor: '#DC2626', color: '#FFF', fontSize: '0.75rem', fontWeight: 600 }}
                    >
                      <RefreshCw size={12} className={switchingRoute ? 'spin' : ''} />
                      <span>{switchingRoute ? 'Switching...' : 'Switch Route to Recycle'}</span>
                    </button>
                  )}
                  <button
                    type="button"
                    onClick={handleRunEco}
                    disabled={runningEco}
                    className="btn btn-secondary btn-sm"
                    style={{ fontSize: '0.75rem', padding: '0.2rem 0.5rem' }}
                  >
                    <RefreshCw size={12} />
                    <span>Re-audit</span>
                  </button>
                </div>
              </div>
            )
          }

          return (
            <div style={{
              background: '#F0FDF4',
              border: '1px solid #BBF7D0',
              borderLeft: '5px solid #16A34A',
              borderRadius: 'var(--radius-md)',
              padding: '0.875rem 1.25rem',
              marginBottom: '1.5rem',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              flexWrap: 'wrap',
              gap: '0.5rem'
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <Leaf size={20} color="#16A34A" />
                <div>
                  <span style={{ fontWeight: 600, color: '#166534', fontSize: '0.875rem' }}>
                    🌱 Eco-Safe & Circular Eligible
                  </span>
                  <div style={{ fontSize: '0.75rem', color: '#15803D' }}>
                    No critical environmental hazards detected. Device is cleared for standard circular recovery.
                  </div>
                </div>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                <span style={{ fontSize: '0.8125rem', fontWeight: 600, color: '#166534' }}>
                  ~{eco.estimatedCo2OffsetKg || 70} kg CO₂ Offset Potential
                </span>
                <button
                  type="button"
                  onClick={handleRunEco}
                  disabled={runningEco}
                  className="btn btn-secondary btn-sm"
                  style={{ fontSize: '0.75rem', padding: '0.2rem 0.5rem' }}
                >
                  <RefreshCw size={12} />
                </button>
              </div>
            </div>
          )
        })()}

        <div className="grid-2" style={{ alignItems: 'start' }}>
          {/* Left Column: Item Overview & Photos */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
            <div className="card">
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '1rem' }}>
                <div>
                  <h2 style={{ fontSize: '1.375rem' }}>{item.name}</h2>
                  <div style={{ color: 'var(--text-muted)', fontSize: '0.875rem' }}>
                    Category: <strong>{item.category?.name}</strong>
                  </div>
                </div>
                <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
                  <button
                    type="button"
                    onClick={() => setEditModalOpen(true)}
                    className="btn btn-secondary btn-sm"
                    title="Edit Item Details"
                  >
                    <Edit3 size={14} />
                    <span>Edit</span>
                  </button>
                  <StatusChip status={item.status} />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem', padding: '1rem', background: 'var(--surface-subtle)', borderRadius: 'var(--radius-sm)', marginBottom: '1.25rem' }}>
                <div>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 500 }}>Brand</div>
                  <div style={{ fontWeight: 600 }}>{item.brand || 'N/A'}</div>
                </div>
                <div>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 500 }}>Model</div>
                  <div style={{ fontWeight: 600 }}>{item.model || 'N/A'}</div>
                </div>
              </div>

              <div>
                <div style={{ fontSize: '0.8125rem', fontWeight: 600, color: 'var(--text-muted)', marginBottom: '0.375rem' }}>
                  Reported Condition
                </div>
                <p style={{ fontSize: '0.875rem', lineHeight: 1.6, color: 'var(--text-main)' }}>
                  {item.conditionDescription}
                </p>
              </div>

              {/* Photos Gallery */}
              {item.images && item.images.length > 0 && (
                <div style={{ marginTop: '1.5rem', paddingTop: '1.25rem', borderTop: '1px solid var(--border-light)' }}>
                  <div style={{ fontSize: '0.8125rem', fontWeight: 600, color: 'var(--text-muted)', marginBottom: '0.75rem' }}>
                    Item Photos ({item.images.length})
                  </div>
                  <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap' }}>
                    {item.images.map((img) => (
                      <img
                        key={img.id}
                        src={img.imageUrl?.startsWith('http') ? img.imageUrl : `${apiClient.defaults.baseURL || ''}${img.imageUrl}`}
                        alt="Item photo"
                        style={{ width: '90px', height: '90px', objectFit: 'cover', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border)' }}
                      />
                    ))}
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Right Column: AI Advisory & Route Selection */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
            {/* Step 2: Advisory Assessment Card */}
            <div className="card">
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.75rem' }}>
                <Sparkles size={20} color="var(--primary)" />
                <h3 style={{ fontSize: '1.125rem' }}>Agent 1 Advisory Assessment</h3>
              </div>

              {!assessment ? (
                <div>
                  <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem', marginBottom: '1.25rem' }}>
                    The item assessment agent analyzes device characteristics, categories, and condition to provide an advisory recovery route recommendation.
                  </p>

                  {categoryMismatch && (
                    <div style={{ background: '#FEF2F2', border: '1px solid #FCA5A5', borderRadius: 'var(--radius-sm)', padding: '0.875rem', marginBottom: '1.25rem' }}>
                      <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center', fontWeight: 600, color: '#991B1B', fontSize: '0.875rem', marginBottom: '0.25rem' }}>
                        <AlertTriangle size={16} color="#DC2626" />
                        <span>
                          {categoryMismatch.inconsistencyType === 'DescriptionMismatch'
                            ? 'Description Correction Needed'
                            : 'Category Correction Needed'}
                        </span>
                      </div>
                      <p style={{ color: '#B91C1C', fontSize: '0.8125rem', margin: '0 0 0.5rem 0' }}>
                        {categoryMismatch.inconsistencyType === 'DescriptionMismatch'
                          ? `Agent 1 detected that your condition description describes a different device. Please edit the description to describe your ${item.name}.`
                          : 'Agent 1 detected that the item details do not match the selected category. Please edit the category before proceeding.'}
                      </p>
                      <button
                        type="button"
                        onClick={() => setEditModalOpen(true)}
                        className="btn btn-secondary btn-sm"
                        style={{ borderColor: '#FCA5A5', color: '#991B1B' }}
                      >
                        <Edit3 size={14} />
                        <span>
                          {categoryMismatch.inconsistencyType === 'DescriptionMismatch'
                            ? 'Edit Description'
                            : 'Edit Item Category'}
                        </span>
                      </button>
                    </div>
                  )}

                  {item?.ecoAssessment?.isHarmfulToEnvironment && !item?.ecoHazardAcknowledged ? (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                      <button
                        disabled={true}
                        className="btn btn-secondary"
                        style={{ width: '100%', opacity: 0.75, cursor: 'not-allowed' }}
                      >
                        <Lock size={16} />
                        <span>Locked: Environmental Acknowledgment Required</span>
                      </button>
                      <div style={{ fontSize: '0.75rem', color: '#DC2626', textAlign: 'center', fontWeight: 500 }}>
                        ⚠️ Please click "Change Route to Recycle & Acknowledge Safety" above to unlock advisory assessment.
                      </div>
                    </div>
                  ) : item?.ecoAssessment?.canBeDonated === false && item?.selectedRecoveryRoute === 'Donate' ? (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                      <button
                        disabled={true}
                        className="btn btn-secondary"
                        style={{ width: '100%', opacity: 0.75, cursor: 'not-allowed' }}
                      >
                        <Lock size={16} />
                        <span>Locked: Hazardous Item Must Be Switched to Recycle</span>
                      </button>
                      <div style={{ fontSize: '0.75rem', color: '#DC2626', textAlign: 'center', fontWeight: 500 }}>
                        ⚠️ This item contains defects/hazards and cannot be submitted for Donation. Click "Switch Route to Recycle" above to unlock assessment.
                      </div>
                    </div>
                  ) : (
                    <button
                      onClick={handleAssess}
                      disabled={assessing}
                      className="btn btn-primary"
                      style={{ width: '100%' }}
                    >
                      <Sparkles size={16} />
                      <span>{assessing ? 'Evaluating with Agent 1...' : 'Run Advisory Assessment'}</span>
                    </button>
                  )}
                </div>
              ) : (
                <div>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem', marginBottom: '1.25rem' }}>
                    <div style={{ background: 'var(--surface-subtle)', padding: '0.75rem', borderRadius: 'var(--radius-sm)' }}>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Estimated Condition</div>
                      <div style={{ fontWeight: 600, marginTop: '0.25rem' }}>{assessment.conditionLevel}</div>
                    </div>
                    <div style={{ background: 'var(--surface-subtle)', padding: '0.75rem', borderRadius: 'var(--radius-sm)' }}>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Confidence Level</div>
                      <div style={{ fontWeight: 600, marginTop: '0.25rem' }}>{assessment.confidenceLevel}</div>
                    </div>
                  </div>

                  <div style={{ marginBottom: '1rem' }}>
                    <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 500, marginBottom: '0.375rem' }}>
                      Recommended Route
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                      <StatusChip status={assessment.recommendedRoute} type="route" />
                      {assessment.alternativeRoute && (
                        <span style={{ fontSize: '0.8125rem', color: 'var(--text-muted)' }}>
                          Alternative: <StatusChip status={assessment.alternativeRoute} type="route" />
                        </span>
                      )}
                    </div>
                  </div>

                  <div style={{ background: '#F8FAFC', padding: '1rem', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-light)', fontSize: '0.875rem', color: 'var(--text-main)', lineHeight: 1.5, marginBottom: '1.5rem' }}>
                    <div style={{ fontWeight: 600, fontSize: '0.8125rem', color: 'var(--dark)', marginBottom: '0.25rem' }}>
                      Advisory Assessment Rationale
                    </div>
                    {assessment.explanation}
                  </div>

                  {/* Step 3: Customer Confirms / Selects Route */}
                  <div style={{ borderTop: '1px solid var(--border-light)', paddingTop: '1.25rem' }}>
                    <div style={{ fontSize: '0.875rem', fontWeight: 600, marginBottom: '0.5rem' }}>
                      Confirm Your Preferred Route
                    </div>
                    <p style={{ color: 'var(--text-muted)', fontSize: '0.8125rem', marginBottom: '1rem' }}>
                      You maintain full autonomy to choose your desired recovery path.
                    </p>

                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '0.75rem', marginBottom: '1.5rem' }}>
                      {['Donate', 'Recycle'].map((route) => {
                        const isDonateBlocked = route === 'Donate' && item.ecoAssessment?.canBeDonated === false
                        return (
                          <button
                            key={route}
                            type="button"
                            disabled={routeSelecting || isDonateBlocked}
                            onClick={() => !isDonateBlocked && handleSelectRoute(route)}
                            className={`btn btn-sm ${item.selectedRecoveryRoute === route ? 'btn-primary' : 'btn-secondary'}`}
                            style={isDonateBlocked ? { opacity: 0.5, cursor: 'not-allowed' } : {}}
                            title={isDonateBlocked ? 'Hazardous/damaged item cannot be donated.' : ''}
                          >
                            {item.selectedRecoveryRoute === route && <CheckCircle2 size={14} />}
                            <span>{route} {isDonateBlocked ? '(Ineligible: Hazard)' : ''}</span>
                          </button>
                        )
                      })}
                    </div>

                    {item.selectedRecoveryRoute && (
                      <button
                        onClick={handleCreateRecovery}
                        disabled={recoveryStarting}
                        className="btn btn-primary btn-lg"
                        style={{ width: '100%' }}
                      >
                        <span>{recoveryStarting ? 'Generating Preparation Plan...' : 'Generate Preparation Plan (Agent 2)'}</span>
                        <ArrowRight size={18} />
                      </button>
                    )}
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Edit Item Details Modal */}
      {editModalOpen && (
        <div style={{
          position: 'fixed',
          inset: 0,
          backgroundColor: 'rgba(0, 0, 0, 0.5)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000,
          padding: '1rem'
        }}>
          <div className="card" style={{ width: '100%', maxWidth: '600px', maxHeight: '90vh', overflowY: 'auto' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem', borderBottom: '1px solid var(--border-light)', paddingBottom: '0.75rem' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <Edit3 size={18} color="var(--primary)" />
                <h3 style={{ margin: 0, fontSize: '1.2rem' }}>Edit Item Details</h3>
              </div>
              <button
                type="button"
                onClick={() => setEditModalOpen(false)}
                style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)' }}
              >
                <X size={20} />
              </button>
            </div>

            {categoryMismatch && (
              <div style={{ background: '#FEF2F2', border: '1px solid #FCA5A5', padding: '0.75rem 1rem', borderRadius: 'var(--radius-sm)', marginBottom: '1.25rem', fontSize: '0.875rem', color: '#991B1B' }}>
                <div style={{ fontWeight: 600, marginBottom: '0.25rem' }}>Agent 1 Identified Issue:</div>
                <div>{categoryMismatch.reason}</div>
              </div>
            )}

            <form onSubmit={handleSaveEdit}>
              <div className="form-group">
                <label className="form-label">Item Name *</label>
                <input
                  type="text"
                  required
                  className="form-input"
                  value={editForm.name}
                  onChange={(e) => setEditForm({ ...editForm, name: e.target.value })}
                />
              </div>

              <div className="grid-2">
                <div className="form-group">
                  <label className="form-label">Category *</label>
                  <select
                    className="form-select"
                    required
                    value={editForm.categoryId}
                    onChange={(e) => setEditForm({ ...editForm, categoryId: e.target.value })}
                  >
                    {categories.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name} {categoryMismatch?.detectedCategory && categoryMismatch.inconsistencyType !== 'DescriptionMismatch' && c.name.toLowerCase().includes(categoryMismatch.detectedCategory.toLowerCase()) ? '— Recommended by Agent 1' : ''}
                      </option>
                    ))}
                  </select>
                </div>

                <div className="form-group">
                  <label className="form-label">Brand *</label>
                  <input
                    type="text"
                    required
                    className="form-input"
                    value={editForm.brand}
                    onChange={(e) => setEditForm({ ...editForm, brand: e.target.value })}
                  />
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">Model *</label>
                <input
                  type="text"
                  required
                  className="form-input"
                  value={editForm.model}
                  onChange={(e) => setEditForm({ ...editForm, model: e.target.value })}
                />
              </div>

              <div className="form-group">
                <label className="form-label">Physical & Operational Condition *</label>
                {categoryMismatch?.inconsistencyType === 'DescriptionMismatch' && (
                  <div style={{ fontSize: '0.8125rem', color: '#B91C1C', marginBottom: '0.375rem', fontWeight: 500 }}>
                    ✏️ Agent 1 flagged this description as inconsistent with your {item.name}. Please enter the correct condition.
                  </div>
                )}
                <textarea
                  required
                  rows={4}
                  className="form-textarea"
                  value={editForm.conditionDescription}
                  onChange={(e) => setEditForm({ ...editForm, conditionDescription: e.target.value })}
                />
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.75rem', marginTop: '1.5rem', borderTop: '1px solid var(--border-light)', paddingTop: '1rem' }}>
                <button
                  type="button"
                  disabled={savingEdit}
                  onClick={() => setEditModalOpen(false)}
                  className="btn btn-secondary"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={savingEdit}
                  className="btn btn-primary"
                >
                  {savingEdit ? 'Saving...' : 'Save & Update Item'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </>
  )
}
