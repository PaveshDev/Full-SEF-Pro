import React, { useState, useEffect } from 'react'
import { useNavigate, Link } from 'react-router'
import { ArrowLeft, Upload, AlertCircle, CheckCircle2 } from 'lucide-react'
import { apiClient } from '../../../shared/services/apiClient.js'
import { TopBar } from '../../../shared/components/TopBar.jsx'

export function AddItemPage() {
  const navigate = useNavigate()
  const [categories, setCategories] = useState([])
  const [name, setName] = useState('')
  const [categoryId, setCategoryId] = useState('')
  const [brand, setBrand] = useState('')
  const [model, setModel] = useState('')
  const [conditionDescription, setConditionDescription] = useState('')
  const [files, setFiles] = useState([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [fieldErrors, setFieldErrors] = useState({})

  useEffect(() => {
    async function loadCategories() {
      try {
        const res = await apiClient.get('/api/categories')
        setCategories(res.data)
        if (res.data.length > 0) {
          setCategoryId(res.data[0].id)
        }
      } catch {
        setError('Failed to load categories.')
      }
    }
    loadCategories()
  }, [])

  const handleSubmit = async (e) => {
    e.preventDefault()

    const errors = {}
    if (!name.trim()) errors.name = 'Item name is required.'
    if (!categoryId) errors.categoryId = 'Category is required.'
    if (!brand.trim()) errors.brand = 'Brand is required.'
    if (!model.trim()) errors.model = 'Model is required.'
    if (!conditionDescription.trim()) errors.conditionDescription = 'Condition description is required.'
    if (!files || files.length === 0) errors.photos = 'At least one item photo is required.'

    if (Object.keys(errors).length > 0) {
      setFieldErrors(errors)
      setError('Please fill in all required fields marked with an asterisk (*).')
      return
    }

    setFieldErrors({})
    setLoading(true)
    setError('')

    try {
      // 1. Create item
      const itemRes = await apiClient.post('/api/items', {
        name: name.trim(),
        categoryId,
        brand: brand.trim(),
        model: model.trim(),
        conditionDescription: conditionDescription.trim()
      })

      const itemId = itemRes.data.id

      // 2. Upload photos
      for (const file of files) {
        const formData = new FormData()
        formData.append('file', file)
        await apiClient.post(`/api/items/${itemId}/photos`, formData, {
          headers: { 'Content-Type': 'multipart/form-data' }
        })
      }

      // Navigate to item details for assessment
      navigate(`/items/${itemId}`)
    } catch (err) {
      console.error('Item submission error:', err)
      const message =
        err.response?.data?.error ||
        err.response?.data?.title ||
        (err.response?.data?.errors ? Object.values(err.response.data.errors).flat().join(', ') : null) ||
        err.message ||
        'Failed to submit item.'
      setError(message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <>
      <TopBar
        title="Submit New Item"
        action={
          <Link to="/items" className="btn btn-secondary btn-sm">
            <ArrowLeft size={16} />
            <span>Back to Items</span>
          </Link>
        }
      />

      <div className="content-container" style={{ maxWidth: '720px' }}>
        <div className="card">
          <h2 style={{ marginBottom: '0.25rem' }}>Item Registration</h2>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem', marginBottom: '1.5rem' }}>
            Provide accurate details to assist our AI assessment agent in recommending the optimal recovery route. All fields are required.
          </p>

          {error && (
            <div className="alert alert-error">
              <AlertCircle size={18} />
              <span>{error}</span>
            </div>
          )}

          <form onSubmit={handleSubmit} noValidate>
            <div className="form-group">
              <label className="form-label">
                Item Name <span style={{ color: 'var(--error)' }}>*</span>
              </label>
              <input
                type="text"
                required
                className="form-input"
                style={fieldErrors.name ? { borderColor: 'var(--error)' } : {}}
                placeholder="e.g., Old Samsung Galaxy S20"
                value={name}
                onChange={(e) => {
                  setName(e.target.value)
                  if (fieldErrors.name) setFieldErrors(prev => ({ ...prev, name: undefined }))
                }}
              />
              {fieldErrors.name && <div className="form-error">{fieldErrors.name}</div>}
            </div>

            <div className="grid-2">
              <div className="form-group">
                <label className="form-label">
                  Category <span style={{ color: 'var(--error)' }}>*</span>
                </label>
                <select
                  className="form-select"
                  style={fieldErrors.categoryId ? { borderColor: 'var(--error)' } : {}}
                  value={categoryId}
                  onChange={(e) => {
                    setCategoryId(e.target.value)
                    if (fieldErrors.categoryId) setFieldErrors(prev => ({ ...prev, categoryId: undefined }))
                  }}
                  required
                >
                  <option value="">Select Category...</option>
                  {categories.map((c) => (
                    <option key={c.id} value={c.id}>{c.name}</option>
                  ))}
                </select>
                {fieldErrors.categoryId && <div className="form-error">{fieldErrors.categoryId}</div>}
              </div>

              <div className="form-group">
                <label className="form-label">
                  Brand <span style={{ color: 'var(--error)' }}>*</span>
                </label>
                <input
                  type="text"
                  required
                  className="form-input"
                  style={fieldErrors.brand ? { borderColor: 'var(--error)' } : {}}
                  placeholder="e.g., Apple, Samsung, Dell"
                  value={brand}
                  onChange={(e) => {
                    setBrand(e.target.value)
                    if (fieldErrors.brand) setFieldErrors(prev => ({ ...prev, brand: undefined }))
                  }}
                />
                {fieldErrors.brand && <div className="form-error">{fieldErrors.brand}</div>}
              </div>
            </div>

            <div className="form-group">
              <label className="form-label">
                Model <span style={{ color: 'var(--error)' }}>*</span>
              </label>
              <input
                type="text"
                required
                className="form-input"
                style={fieldErrors.model ? { borderColor: 'var(--error)' } : {}}
                placeholder="e.g., iPhone 13 Pro Max, SM-G981B"
                value={model}
                onChange={(e) => {
                  setModel(e.target.value)
                  if (fieldErrors.model) setFieldErrors(prev => ({ ...prev, model: undefined }))
                }}
              />
              {fieldErrors.model && <div className="form-error">{fieldErrors.model}</div>}
            </div>

            <div className="form-group">
              <label className="form-label">
                Physical & Operational Condition <span style={{ color: 'var(--error)' }}>*</span>
              </label>
              <textarea
                required
                rows={3}
                className="form-textarea"
                style={fieldErrors.conditionDescription ? { borderColor: 'var(--error)' } : {}}
                placeholder="Describe flaws, screen condition, battery health, whether it powers on, etc."
                value={conditionDescription}
                onChange={(e) => {
                  setConditionDescription(e.target.value)
                  if (fieldErrors.conditionDescription) setFieldErrors(prev => ({ ...prev, conditionDescription: undefined }))
                }}
              />
              {fieldErrors.conditionDescription && <div className="form-error">{fieldErrors.conditionDescription}</div>}
            </div>

            <div className="form-group">
              <label className="form-label">
                Upload Item Photos <span style={{ color: 'var(--error)' }}>*</span>
              </label>
              <input
                type="file"
                multiple
                accept="image/*"
                className="form-input"
                style={fieldErrors.photos ? { borderColor: 'var(--error)' } : {}}
                onChange={(e) => {
                  const selected = Array.from(e.target.files)
                  setFiles(selected)
                  if (selected.length > 0 && fieldErrors.photos) {
                    setFieldErrors(prev => ({ ...prev, photos: undefined }))
                  }
                }}
              />
              {files.length > 0 && (
                <div style={{ fontSize: '0.75rem', color: 'var(--primary)', marginTop: '0.375rem', fontWeight: 600 }}>
                  ✓ {files.length} photo{files.length > 1 ? 's' : ''} selected ({files.map(f => f.name).join(', ')})
                </div>
              )}
              <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.375rem' }}>
                You can upload JPG, PNG, or WebP images to aid visual condition assessment. At least 1 photo is required.
              </div>
              {fieldErrors.photos && <div className="form-error">{fieldErrors.photos}</div>}
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '1rem', marginTop: '2rem' }}>
              <Link to="/items" className="btn btn-secondary">Cancel</Link>
              <button type="submit" disabled={loading} className="btn btn-primary">
                {loading ? 'Submitting...' : 'Save & Proceed to Assessment'}
              </button>
            </div>
          </form>
        </div>
      </div>
    </>
  )
}

