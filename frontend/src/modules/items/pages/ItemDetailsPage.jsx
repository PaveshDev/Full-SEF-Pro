import React, { useEffect, useState } from 'react'
import { useParams, useNavigate, Link, useLocation } from 'react-router'
import { ArrowLeft, Sparkles, AlertCircle, CheckCircle2, ArrowRight, ShieldCheck, Edit3, X, AlertTriangle } from 'lucide-react'
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
        setCategoryMismatch({
          reason: resp.mismatchReason || resp.error,
          detectedCategory: resp.detectedCategory
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
                  Agent 1 Inconsistency Detected: Category Mismatch
                </div>
                <p style={{ color: '#B91C1C', fontSize: '0.875rem', lineHeight: 1.5, margin: 0 }}>
                  {categoryMismatch.reason}
                </p>
                {categoryMismatch.detectedCategory && (
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
                    <span>Edit Mistaken Details</span>
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
                        <span>Category Correction Needed</span>
                      </div>
                      <p style={{ color: '#B91C1C', fontSize: '0.8125rem', margin: '0 0 0.5rem 0' }}>
                        Agent 1 detected that the item details do not match the selected category. Please edit the category before proceeding.
                      </p>
                      <button
                        type="button"
                        onClick={() => setEditModalOpen(true)}
                        className="btn btn-secondary btn-sm"
                        style={{ borderColor: '#FCA5A5', color: '#991B1B' }}
                      >
                        <Edit3 size={14} />
                        <span>Edit Item Category</span>
                      </button>
                    </div>
                  )}

                  <button
                    onClick={handleAssess}
                    disabled={assessing}
                    className="btn btn-primary"
                    style={{ width: '100%' }}
                  >
                    <Sparkles size={16} />
                    <span>{assessing ? 'Evaluating with Agent 1...' : 'Run Advisory Assessment'}</span>
                  </button>
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
                      {['Donate', 'Recycle'].map((route) => (
                        <button
                          key={route}
                          type="button"
                          disabled={routeSelecting}
                          onClick={() => handleSelectRoute(route)}
                          className={`btn btn-sm ${item.selectedRecoveryRoute === route ? 'btn-primary' : 'btn-secondary'}`}
                        >
                          {item.selectedRecoveryRoute === route && <CheckCircle2 size={14} />}
                          <span>{route}</span>
                        </button>
                      ))}
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
                        {c.name} {categoryMismatch?.detectedCategory && c.name.toLowerCase().includes(categoryMismatch.detectedCategory.toLowerCase()) ? '— Recommended by Agent 1' : ''}
                      </option>
                    ))}
                  </select>
                </div>

                <div className="form-group">
                  <label className="form-label">Brand</label>
                  <input
                    type="text"
                    className="form-input"
                    value={editForm.brand}
                    onChange={(e) => setEditForm({ ...editForm, brand: e.target.value })}
                  />
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">Model</label>
                <input
                  type="text"
                  className="form-input"
                  value={editForm.model}
                  onChange={(e) => setEditForm({ ...editForm, model: e.target.value })}
                />
              </div>

              <div className="form-group">
                <label className="form-label">Physical & Operational Condition *</label>
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
