import React, { useEffect, useState } from 'react'
import { Plus, Edit2, Trash2, CheckCircle2, AlertCircle, X, ShieldCheck, Recycle, HeartHandshake, Eye, EyeOff } from 'lucide-react'
import { apiClient } from '../../../shared/services/apiClient.js'
import { StatusChip } from '../../../shared/components/StatusChip.jsx'
import { TopBar } from '../../../shared/components/TopBar.jsx'

export function AdminPartnersPage() {
  const [partners, setPartners] = useState([])
  const [categories, setCategories] = useState([])
  const [loading, setLoading] = useState(true)
  const [showModal, setShowModal] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  // Form state
  const [editingPartner, setEditingPartner] = useState(null)
  const [name, setName] = useState('')
  const [contactName, setContactName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [phone, setPhone] = useState('')
  const [serviceArea, setServiceArea] = useState('')
  const [operatingHours, setOperatingHours] = useState('')
  const [isActive, setIsActive] = useState(true)
  const [selectedServices, setSelectedServices] = useState([]) // [{ recoveryRoute, categoryId }]
  const [modalError, setModalError] = useState('')

  useEffect(() => {
    loadData()
  }, [])

  const loadData = async () => {
    try {
      setLoading(true)
      const [pRes, cRes] = await Promise.all([
        apiClient.get('/api/partners?activeOnly=false'),
        apiClient.get('/api/categories')
      ])
      setPartners(pRes.data)
      setCategories(cRes.data)
    } catch {
      setError('Failed to load partners data.')
    } finally {
      setLoading(false)
    }
  }

  const openAddModal = () => {
    setError('')
    setModalError('')
    setEditingPartner(null)
    setName('')
    setContactName('')
    setEmail('')
    setPassword('')
    setConfirmPassword('')
    setShowPassword(false)
    setPhone('')
    setServiceArea('')
    setOperatingHours('Mon-Fri 9:00-17:00')
    setIsActive(true)
    setSelectedServices([])
    setShowModal(true)
  }

  const openEditModal = (p) => {
    setError('')
    setModalError('')
    setEditingPartner(p)
    setName(p.name)
    setContactName(p.contactName)
    setEmail(p.email)
    setPassword('')
    setConfirmPassword('')
    setShowPassword(false)
    setPhone(p.phone || '')
    setServiceArea(p.serviceArea)
    setOperatingHours(p.operatingHours || '')
    setIsActive(p.isActive)
    setSelectedServices(p.services ? p.services.map((s) => ({ recoveryRoute: s.recoveryRoute, categoryId: s.categoryId })) : [])
    setShowModal(true)
  }

  const toggleService = (route, catId) => {
    const exists = selectedServices.some((s) => s.recoveryRoute === route && s.categoryId === catId)
    if (exists) {
      setSelectedServices(selectedServices.filter((s) => !(s.recoveryRoute === route && s.categoryId === catId)))
    } else {
      setSelectedServices([...selectedServices, { recoveryRoute: route, categoryId: catId }])
    }
  }

  const selectAllForRoute = (route) => {
    const otherServices = selectedServices.filter((s) => s.recoveryRoute !== route)
    const newServices = categories.map((c) => ({ recoveryRoute: route, categoryId: c.id }))
    setSelectedServices([...otherServices, ...newServices])
  }

  const clearAllForRoute = (route) => {
    setSelectedServices(selectedServices.filter((s) => s.recoveryRoute !== route))
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')
    setModalError('')

    if (!name.trim()) {
      setModalError('Organization Name is required.')
      return
    }

    if (!contactName.trim()) {
      setModalError('Contact Person is required.')
      return
    }

    if (!email.trim()) {
      setModalError('Official Email is required.')
      return
    }

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) {
      setModalError('Please enter a valid official email address.')
      return
    }

    if (!editingPartner) {
      if (!password || password.length < 8) {
        setModalError('Password must be at least 8 characters long.')
        return
      }
      if (!/[A-Z]/.test(password) || !/[0-9]/.test(password)) {
        setModalError('Password must include at least one uppercase letter and numbers.')
        return
      }
      if (password !== confirmPassword) {
        setModalError('Passwords do not match.')
        return
      }
    }

    if (!phone.trim()) {
      setModalError('Phone number is required.')
      return
    }

    let cleanPhone = phone.trim().replace(/[\s\-()]/g, '')
    if (cleanPhone.startsWith('+94')) {
      cleanPhone = '0' + cleanPhone.slice(3)
    }
    if (!/^[0-9]{10}$/.test(cleanPhone)) {
      setModalError('Phone number must be exactly 10 digits (e.g. 0771234567).')
      return
    }

    if (!serviceArea.trim()) {
      setModalError('Service Area / District is required.')
      return
    }

    if (!operatingHours.trim()) {
      setModalError('Operating Hours are required.')
      return
    }

    if (!selectedServices || selectedServices.length === 0) {
      setModalError('Please select at least one accepted route and category. Partners cannot operate without accepted services.')
      return
    }

    try {
      const payload = {
        name: name.trim(),
        contactName: contactName.trim(),
        email: email.trim(),
        phone: cleanPhone,
        serviceArea: serviceArea.trim(),
        operatingHours: operatingHours.trim(),
        services: selectedServices
      }

      if (editingPartner) {
        await apiClient.put(`/api/partners/${editingPartner.id}`, {
          ...payload,
          isActive: isActive
        })
        setSuccess('Partner updated successfully.')
      } else {
        await apiClient.post('/api/partners', {
          ...payload,
          password
        })
        setSuccess('Partner organization and login credentials created successfully.')
      }

      setShowModal(false)
      await loadData()
    } catch (err) {
      console.error('Save partner error:', err)
      const msg =
        err.response?.data?.error ||
        err.response?.data?.title ||
        (err.response?.data?.errors ? Object.values(err.response.data.errors).flat().join(', ') : null) ||
        err.message ||
        'Failed to save partner.'
      setModalError(msg)
    }
  }

  const handleDelete = async (id, partnerName) => {
    if (!confirm(`Are you sure you want to remove/deactivate "${partnerName}"?`)) return
    try {
      const res = await apiClient.delete(`/api/partners/${id}`)
      setSuccess(res.data?.message || 'Partner removed successfully.')
      await loadData()
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to delete partner.')
    }
  }

  const handleReactivate = async (id) => {
    try {
      await apiClient.post(`/api/partners/${id}/reactivate`)
      setSuccess('Partner reactivated.')
      await loadData()
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to reactivate partner.')
    }
  }

  const recycleCount = selectedServices.filter((s) => s.recoveryRoute === 'Recycle').length
  const donateCount = selectedServices.filter((s) => s.recoveryRoute === 'Donate').length

  return (
    <>
      <TopBar
        title="Partners Management"
        action={
          <button onClick={openAddModal} className="btn btn-primary btn-sm">
            <Plus size={16} />
            <span>Add Partner Organization</span>
          </button>
        }
      />

      <div className="content-container">
        <div className="page-header">
          <div className="page-title-group">
            <h1>Certified Recovery Partners</h1>
            <div className="page-subtitle">Manage accredited electronics recyclers and charitable donation partner facilities</div>
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
            <p style={{ color: 'var(--text-muted)' }}>Loading partners...</p>
          </div>
        ) : (
          <div className="table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Partner Organization</th>
                  <th>Service Area</th>
                  <th>Contact Info</th>
                  <th>Operating Hours</th>
                  <th>Supported Routes</th>
                  <th>Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {partners.map((p) => {
                  const uniqueRoutes = Array.from(new Set(p.services?.map((s) => s.recoveryRoute) || []))
                  return (
                    <tr key={p.id}>
                      <td>
                        <div style={{ fontWeight: 600 }}>{p.name}</div>
                        <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Contact: {p.contactName}</div>
                      </td>
                      <td>{p.serviceArea}</td>
                      <td style={{ fontSize: '0.8125rem' }}>
                        <div>{p.email}</div>
                        <div style={{ color: 'var(--text-muted)' }}>{p.phone || 'No phone'}</div>
                      </td>
                      <td style={{ fontSize: '0.8125rem' }}>{p.operatingHours || 'Standard'}</td>
                      <td>
                        <div style={{ display: 'flex', gap: '0.25rem', flexWrap: 'wrap' }}>
                          {uniqueRoutes.map((r) => (
                            <StatusChip key={r} status={r} type="route" />
                          ))}
                        </div>
                      </td>
                      <td>
                        <span className={`status-chip ${p.isActive ? 'status-approved' : 'status-rejected'}`}>
                          {p.isActive ? 'Active' : 'Inactive'}
                        </span>
                      </td>
                      <td>
                        <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
                          <button onClick={() => openEditModal(p)} className="btn btn-secondary btn-sm" title="Edit Partner">
                            <Edit2 size={14} />
                          </button>
                          {p.isActive ? (
                            <button onClick={() => handleDelete(p.id, p.name)} className="btn btn-secondary btn-sm" title="Delete / Deactivate">
                              <Trash2 size={14} color="var(--error)" />
                            </button>
                          ) : (
                            <button onClick={() => handleReactivate(p.id)} className="btn btn-secondary btn-sm" title="Reactivate Partner" style={{ color: 'var(--success)' }}>
                              <CheckCircle2 size={14} />
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}

        {/* Add/Edit Modal */}
        {showModal && (
          <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(0,0,0,0.55)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: '1.25rem' }}>
            <div className="card" style={{ maxWidth: '760px', width: '100%', maxHeight: '92vh', overflowY: 'auto', padding: '1.75rem' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem', paddingBottom: '0.75rem', borderBottom: '1px solid var(--border)' }}>
                <div>
                  <h3 style={{ margin: 0, fontSize: '1.25rem' }}>{editingPartner ? 'Edit Partner Details' : 'Register New Partner Organization'}</h3>
                  <p style={{ margin: '0.25rem 0 0 0', fontSize: '0.8125rem', color: 'var(--text-muted)' }}>
                    {editingPartner ? 'Update partner service coverage and contact details' : 'Create partner profile and system credentials for facility intake management'}
                  </p>
                </div>
                <button onClick={() => setShowModal(false)} className="btn btn-secondary btn-sm">
                  <X size={16} />
                </button>
              </div>

              {modalError && (
                <div className="alert alert-error" style={{ marginBottom: '1.25rem' }}>
                  <AlertCircle size={18} />
                  <span>{modalError}</span>
                </div>
              )}

              <form onSubmit={handleSubmit}>
                {/* Organization & Contact Info */}
                <div style={{ marginBottom: '1.25rem' }}>
                  <div className="form-group">
                    <label className="form-label">Organization Name *</label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. GreenCycle Eco Facilities"
                      className="form-input"
                      value={name}
                      onChange={(e) => setName(e.target.value)}
                    />
                  </div>

                  <div className="grid-2">
                    <div className="form-group">
                      <label className="form-label">Contact Person *</label>
                      <input
                        type="text"
                        required
                        placeholder="e.g. Priyantha Fernando"
                        className="form-input"
                        value={contactName}
                        onChange={(e) => setContactName(e.target.value)}
                      />
                    </div>
                    <div className="form-group">
                      <label className="form-label">Official Email (Username) *</label>
                      <input
                        type="email"
                        required
                        placeholder="e.g. intake@greencycle.lk"
                        className="form-input"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                      />
                    </div>
                  </div>

                  {/* Password & Confirm Password (For new partners) */}
                  {!editingPartner && (
                    <div className="grid-2" style={{ background: 'var(--surface-muted)', padding: '1rem', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border)', marginBottom: '1rem' }}>
                      <div className="form-group" style={{ margin: 0 }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                          <label className="form-label">Login Password *</label>
                          <button
                            type="button"
                            onClick={() => setShowPassword(!showPassword)}
                            style={{ background: 'none', border: 'none', color: 'var(--text-muted)', cursor: 'pointer', fontSize: '0.75rem', display: 'flex', alignItems: 'center', gap: '0.25rem' }}
                          >
                            {showPassword ? <EyeOff size={14} /> : <Eye size={14} />}
                            <span>{showPassword ? 'Hide' : 'Show'}</span>
                          </button>
                        </div>
                        <input
                          type={showPassword ? 'text' : 'password'}
                          required
                          placeholder="Min 8 chars, 1 uppercase, 1 digit"
                          className="form-input"
                          value={password}
                          onChange={(e) => setPassword(e.target.value)}
                        />
                      </div>
                      <div className="form-group" style={{ margin: 0 }}>
                        <label className="form-label">Confirm Password *</label>
                        <input
                          type={showPassword ? 'text' : 'password'}
                          required
                          placeholder="Repeat password"
                          className="form-input"
                          value={confirmPassword}
                          onChange={(e) => setConfirmPassword(e.target.value)}
                        />
                      </div>
                    </div>
                  )}

                  <div className="grid-2">
                    <div className="form-group">
                      <label className="form-label">Phone Number *</label>
                      <input
                        type="tel"
                        required
                        placeholder="e.g. 0771234567 or +94771234567"
                        className="form-input"
                        value={phone}
                        onChange={(e) => setPhone(e.target.value)}
                      />
                    </div>
                    <div className="form-group">
                      <label className="form-label">Service Area / District *</label>
                      <input
                        type="text"
                        required
                        className="form-input"
                        placeholder="e.g. Colombo, Western Province"
                        value={serviceArea}
                        onChange={(e) => setServiceArea(e.target.value)}
                      />
                    </div>
                  </div>

                  <div className="form-group">
                    <label className="form-label">Operating Hours *</label>
                    <input
                      type="text"
                      required
                      className="form-input"
                      placeholder="e.g. Mon-Fri 8:30-17:30"
                      value={operatingHours}
                      onChange={(e) => setOperatingHours(e.target.value)}
                    />
                  </div>
                </div>

                {/* Accepted Services & Categories Redesign */}
                <div style={{ marginBottom: '1.5rem' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: '0.75rem' }}>
                    <div>
                      <label className="form-label" style={{ fontSize: '0.9375rem', fontWeight: 700, margin: 0 }}>
                        Accepted Services & Categories
                      </label>
                      <div style={{ fontSize: '0.8125rem', color: 'var(--text-muted)' }}>
                        Select the recovery routes and device types this partner is accredited to process:
                      </div>
                    </div>
                  </div>

                  <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                    {/* Recycle Route Card */}
                    <div
                      style={{
                        border: '1px solid var(--border)',
                        borderRadius: 'var(--radius-md)',
                        padding: '1.125rem',
                        background: 'var(--surface)'
                      }}
                    >
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                          <span style={{ display: 'inline-flex', padding: '0.35rem', borderRadius: '50%', background: 'rgba(16, 185, 129, 0.1)', color: '#10b981' }}>
                            <Recycle size={18} />
                          </span>
                          <div>
                            <div style={{ fontWeight: 700, fontSize: '0.875rem' }}>Recycle Route</div>
                            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                              E-waste recycling, safe de-manufacturing, and raw material recovery
                            </div>
                          </div>
                        </div>

                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                          <span style={{ fontSize: '0.75rem', fontWeight: 600, color: recycleCount > 0 ? '#10b981' : 'var(--text-muted)' }}>
                            {recycleCount} / {categories.length} Selected
                          </span>
                          <button
                            type="button"
                            onClick={() => selectAllForRoute('Recycle')}
                            style={{ fontSize: '0.75rem', background: 'none', border: 'none', color: 'var(--primary)', cursor: 'pointer', padding: '0.2rem 0.4rem' }}
                          >
                            All
                          </button>
                          <span style={{ color: 'var(--border)' }}>|</span>
                          <button
                            type="button"
                            onClick={() => clearAllForRoute('Recycle')}
                            style={{ fontSize: '0.75rem', background: 'none', border: 'none', color: 'var(--text-muted)', cursor: 'pointer', padding: '0.2rem 0.4rem' }}
                          >
                            Clear
                          </button>
                        </div>
                      </div>

                      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(150px, 1fr))', gap: '0.625rem' }}>
                        {categories.map((c) => {
                          const active = selectedServices.some((s) => s.recoveryRoute === 'Recycle' && s.categoryId === c.id)
                          return (
                            <button
                              key={`rec-${c.id}`}
                              type="button"
                              onClick={() => toggleService('Recycle', c.id)}
                              style={{
                                display: 'flex',
                                alignItems: 'center',
                                gap: '0.5rem',
                                padding: '0.5rem 0.75rem',
                                borderRadius: 'var(--radius-sm)',
                                border: active ? '1.5px solid #10b981' : '1px solid var(--border)',
                                background: active ? 'rgba(16, 185, 129, 0.08)' : 'var(--surface-muted)',
                                color: active ? 'var(--text-main)' : 'var(--text-muted)',
                                fontWeight: active ? 600 : 500,
                                fontSize: '0.8125rem',
                                cursor: 'pointer',
                                transition: 'all 0.15s ease'
                              }}
                            >
                              <div
                                style={{
                                  width: '14px',
                                  height: '14px',
                                  borderRadius: '3px',
                                  border: active ? 'none' : '1.5px solid var(--text-muted)',
                                  background: active ? '#10b981' : 'transparent',
                                  display: 'flex',
                                  alignItems: 'center',
                                  justifyContent: 'center',
                                  flexShrink: 0
                                }}
                              >
                                {active && <CheckCircle2 size={12} color="#fff" />}
                              </div>
                              <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{c.name}</span>
                            </button>
                          )
                        })}
                      </div>
                    </div>

                    {/* Donate Route Card */}
                    <div
                      style={{
                        border: '1px solid var(--border)',
                        borderRadius: 'var(--radius-md)',
                        padding: '1.125rem',
                        background: 'var(--surface)'
                      }}
                    >
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                          <span style={{ display: 'inline-flex', padding: '0.35rem', borderRadius: '50%', background: 'rgba(59, 130, 246, 0.1)', color: '#3b82f6' }}>
                            <HeartHandshake size={18} />
                          </span>
                          <div>
                            <div style={{ fontWeight: 700, fontSize: '0.875rem' }}>Donate Route</div>
                            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                              Refurbishment, functional testing, and charitable distribution
                            </div>
                          </div>
                        </div>

                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                          <span style={{ fontSize: '0.75rem', fontWeight: 600, color: donateCount > 0 ? '#3b82f6' : 'var(--text-muted)' }}>
                            {donateCount} / {categories.length} Selected
                          </span>
                          <button
                            type="button"
                            onClick={() => selectAllForRoute('Donate')}
                            style={{ fontSize: '0.75rem', background: 'none', border: 'none', color: 'var(--primary)', cursor: 'pointer', padding: '0.2rem 0.4rem' }}
                          >
                            All
                          </button>
                          <span style={{ color: 'var(--border)' }}>|</span>
                          <button
                            type="button"
                            onClick={() => clearAllForRoute('Donate')}
                            style={{ fontSize: '0.75rem', background: 'none', border: 'none', color: 'var(--text-muted)', cursor: 'pointer', padding: '0.2rem 0.4rem' }}
                          >
                            Clear
                          </button>
                        </div>
                      </div>

                      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(150px, 1fr))', gap: '0.625rem' }}>
                        {categories.map((c) => {
                          const active = selectedServices.some((s) => s.recoveryRoute === 'Donate' && s.categoryId === c.id)
                          return (
                            <button
                              key={`don-${c.id}`}
                              type="button"
                              onClick={() => toggleService('Donate', c.id)}
                              style={{
                                display: 'flex',
                                alignItems: 'center',
                                gap: '0.5rem',
                                padding: '0.5rem 0.75rem',
                                borderRadius: 'var(--radius-sm)',
                                border: active ? '1.5px solid #3b82f6' : '1px solid var(--border)',
                                background: active ? 'rgba(59, 130, 246, 0.08)' : 'var(--surface-muted)',
                                color: active ? 'var(--text-main)' : 'var(--text-muted)',
                                fontWeight: active ? 600 : 500,
                                fontSize: '0.8125rem',
                                cursor: 'pointer',
                                transition: 'all 0.15s ease'
                              }}
                            >
                              <div
                                style={{
                                  width: '14px',
                                  height: '14px',
                                  borderRadius: '3px',
                                  border: active ? 'none' : '1.5px solid var(--text-muted)',
                                  background: active ? '#3b82f6' : 'transparent',
                                  display: 'flex',
                                  alignItems: 'center',
                                  justifyContent: 'center',
                                  flexShrink: 0
                                }}
                              >
                                {active && <CheckCircle2 size={12} color="#fff" />}
                              </div>
                              <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{c.name}</span>
                            </button>
                          )
                        })}
                      </div>
                    </div>
                  </div>
                </div>

                {editingPartner && (
                  <div className="form-group" style={{ display: 'flex', alignItems: 'center', gap: '0.625rem', marginTop: '1rem', padding: '0.75rem 1rem', background: 'var(--surface-muted)', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border)' }}>
                    <input
                      type="checkbox"
                      id="partnerIsActive"
                      checked={isActive}
                      onChange={(e) => setIsActive(e.target.checked)}
                      style={{ width: '1.125rem', height: '1.125rem', cursor: 'pointer' }}
                    />
                    <label htmlFor="partnerIsActive" style={{ fontWeight: 600, fontSize: '0.875rem', cursor: 'pointer', margin: 0 }}>
                      Partner Organization is Active
                    </label>
                  </div>
                )}

                <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.75rem', marginTop: '1.5rem', paddingTop: '1rem', borderTop: '1px solid var(--border)' }}>
                  <button type="button" onClick={() => setShowModal(false)} className="btn btn-secondary">
                    Cancel
                  </button>
                  <button type="submit" className="btn btn-primary" style={{ minWidth: '130px' }}>
                    {editingPartner ? 'Save Changes' : 'Create Partner'}
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
