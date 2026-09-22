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
    if (!name || !categoryId || !conditionDescription) {
      setError('Please fill in all required fields.')
      return
    }

    setLoading(true)
    setError('')

    try {
      // 1. Create item
      const itemRes = await apiClient.post('/api/items', {
        name,
        categoryId,
        brand: brand || null,
        model: model || null,
        conditionDescription
      })

      const itemId = itemRes.data.id

      // 2. Upload photos if selected
      if (files.length > 0) {
        for (const file of files) {
          const formData = new FormData()
          formData.append('file', file)
          await apiClient.post(`/api/items/${itemId}/photos`, formData, {
            headers: { 'Content-Type': 'multipart/form-data' }
          })
        }
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
            Provide accurate details to assist our AI assessment agent in recommending the optimal recovery route.
          </p>

          {error && (
            <div className="alert alert-error">
              <AlertCircle size={18} />
              <span>{error}</span>
            </div>
          )}

          <form onSubmit={handleSubmit}>
            <div className="form-group">
              <label className="form-label">Item Name *</label>
              <input
                type="text"
                required
                className="form-input"
                placeholder="e.g., Old Samsung Galaxy S20"
                value={name}
                onChange={(e) => setName(e.target.value)}
              />
            </div>

            <div className="grid-2">
              <div className="form-group">
                <label className="form-label">Category *</label>
                <select
                  className="form-select"
                  value={categoryId}
                  onChange={(e) => setCategoryId(e.target.value)}
                  required
                >
                  {categories.map((c) => (
                    <option key={c.id} value={c.id}>{c.name}</option>
                  ))}
                </select>
              </div>

              <div className="form-group">
                <label className="form-label">Brand</label>
                <input
                  type="text"
                  className="form-input"
                  placeholder="e.g., Samsung"
                  value={brand}
                  onChange={(e) => setBrand(e.target.value)}
                />
              </div>
            </div>

            <div className="form-group">
              <label className="form-label">Model</label>
              <input
                type="text"
                className="form-input"
                placeholder="e.g., SM-G981B"
                value={model}
                onChange={(e) => setModel(e.target.value)}
              />
            </div>

            <div className="form-group">
              <label className="form-label">Physical & Operational Condition *</label>
              <textarea
                required
                rows={3}
                className="form-textarea"
                placeholder="Describe flaws, screen condition, battery health, whether it powers on, etc."
                value={conditionDescription}
                onChange={(e) => setConditionDescription(e.target.value)}
              />
            </div>

            <div className="form-group">
              <label className="form-label">Upload Item Photos</label>
              <input
                type="file"
                multiple
                accept="image/*"
                className="form-input"
                onChange={(e) => setFiles(Array.from(e.target.files))}
              />
              <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.375rem' }}>
                You can upload JPG, PNG, or WebP images to aid visual condition assessment.
              </div>
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
