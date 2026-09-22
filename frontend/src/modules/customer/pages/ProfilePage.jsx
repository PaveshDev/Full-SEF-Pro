import React, { useState, useEffect } from 'react'
import {
  User,
  Mail,
  Phone,
  MapPin,
  Building,
  Home,
  Save,
  CheckCircle2,
  AlertCircle,
  Shield,
  Eye
} from 'lucide-react'
import { useAuth } from '../../../shared/context/AuthContext.jsx'
import { TopBar } from '../../../shared/components/TopBar.jsx'
import { apiClient } from '../../../shared/services/apiClient.js'

const SRI_LANKAN_DISTRICTS = [
  'Ampara', 'Anuradhapura', 'Badulla', 'Batticaloa', 'Colombo',
  'Galle', 'Gampaha', 'Hambantota', 'Jaffna', 'Kalutara',
  'Kandy', 'Kegalle', 'Kilinochchi', 'Kurunegala', 'Mannar',
  'Matale', 'Matara', 'Monaragala', 'Mullaitivu', 'Nuwara Eliya',
  'Polonnaruwa', 'Puttalam', 'Ratnapura', 'Trincomalee', 'Vavuniya'
]

export function ProfilePage() {
  const { user, updateProfile } = useAuth()
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    phone: '',
    district: '',
    town: '',
    address: ''
  })
  const [loading, setLoading] = useState(true)
  const [submitting, setSubmitting] = useState(false)
  const [success, setSuccess] = useState('')
  const [error, setError] = useState('')

  useEffect(() => {
    async function loadProfile() {
      try {
        setLoading(true)
        const res = await apiClient.get('/api/auth/me')
        const data = res.data
        setFormData({
          name: data.name || '',
          email: data.email || '',
          phone: data.phone || '',
          district: data.district || '',
          town: data.town || '',
          address: data.address || ''
        })
      } catch {
        // Fallback to user context
        if (user) {
          setFormData({
            name: user.name || '',
            email: user.email || '',
            phone: user.phone || '',
            district: user.district || '',
            town: user.town || '',
            address: user.address || ''
          })
        }
      } finally {
        setLoading(false)
      }
    }
    loadProfile()
  }, [user])

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')
    setSuccess('')

    if (!formData.name.trim()) {
      setError('Please provide your full name.')
      return
    }

    if (!formData.phone.trim()) {
      setError('Please provide a contact phone number for collection agents.')
      return
    }

    if (!formData.district) {
      setError('Please select your district.')
      return
    }

    if (!formData.town.trim()) {
      setError('Please provide your town or area.')
      return
    }

    if (!formData.address.trim()) {
      setError('Please provide your street address.')
      return
    }

    try {
      setSubmitting(true)
      await updateProfile({
        name: formData.name.trim(),
        phone: formData.phone.trim(),
        district: formData.district,
        town: formData.town.trim(),
        address: formData.address.trim()
      })
      setSuccess('Your profile and pickup details have been updated successfully.')
      window.scrollTo({ top: 0, behavior: 'smooth' })
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to update profile. Please try again.')
    } finally {
      setSubmitting(false)
    }
  }

  if (loading) {
    return (
      <div style={{ padding: '3rem', textAlign: 'center' }}>
        <p style={{ color: 'var(--text-muted)' }}>Loading your profile details...</p>
      </div>
    )
  }

  return (
    <>
      <TopBar title="My Profile" />

      <div className="content-container" style={{ maxWidth: '840px' }}>
        <div className="page-header">
          <div className="page-title-group">
            <h1>Account &amp; Pickup Details</h1>
            <div className="page-subtitle">
              Manage your personal information and default pickup address used for collection agent dispatch
            </div>
          </div>
        </div>

        {error && (
          <div className="alert alert-error" style={{ marginBottom: '1.25rem' }}>
            <AlertCircle size={18} />
            <span>{error}</span>
          </div>
        )}

        {success && (
          <div className="alert alert-success" style={{ marginBottom: '1.25rem' }}>
            <CheckCircle2 size={18} />
            <span>{success}</span>
          </div>
        )}

        <form onSubmit={handleSubmit}>
          {/* Personal Information */}
          <div className="card" style={{ marginBottom: '1.5rem' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.625rem', marginBottom: '1.25rem', borderBottom: '1px solid var(--border)', paddingBottom: '0.75rem' }}>
              <User size={20} color="var(--primary)" />
              <h3 style={{ fontSize: '1.0625rem', margin: 0 }}>Personal Information</h3>
            </div>

            <div className="grid-2">
              <div className="form-group">
                <label className="form-label">Full Name *</label>
                <div style={{ position: 'relative' }}>
                  <User size={16} style={{ position: 'absolute', left: '0.75rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                  <input
                    type="text"
                    required
                    className="form-input"
                    style={{ paddingLeft: '2.25rem' }}
                    value={formData.name}
                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    placeholder="e.g. Kasun Jayasuriya"
                  />
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">Email Address (Account Identifier)</label>
                <div style={{ position: 'relative' }}>
                  <Mail size={16} style={{ position: 'absolute', left: '0.75rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                  <input
                    type="email"
                    disabled
                    className="form-input"
                    style={{ paddingLeft: '2.25rem', background: 'var(--surface-subtle)', cursor: 'not-allowed', color: 'var(--text-muted)' }}
                    value={formData.email}
                  />
                </div>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.25rem' }}>
                  Email is locked to your account credentials.
                </div>
              </div>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', background: 'var(--surface-subtle)', padding: '0.625rem 1rem', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border)', marginTop: '0.5rem' }}>
              <Shield size={16} color="var(--primary)" />
              <span style={{ fontSize: '0.8125rem', color: 'var(--text-muted)' }}>
                Account Role: <strong style={{ color: 'var(--text-main)' }}>{user?.role || 'Customer'}</strong>
              </span>
            </div>
          </div>

          {/* Contact & Doorstep Pickup Address */}
          <div className="card" style={{ marginBottom: '1.5rem' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.625rem', marginBottom: '0.5rem', borderBottom: '1px solid var(--border)', paddingBottom: '0.75rem' }}>
              <MapPin size={20} color="var(--primary)" />
              <h3 style={{ fontSize: '1.0625rem', margin: 0 }}>Doorstep Pickup &amp; Contact Information</h3>
            </div>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.8125rem', marginBottom: '1.25rem' }}>
              These details are essential for our collection agents. Whenever an agent is assigned to collect your disused electronic items, they will use this address and phone number for navigation and pickup coordination.
            </p>

            <div className="grid-2">
              <div className="form-group">
                <label className="form-label">Contact Phone Number *</label>
                <div style={{ position: 'relative' }}>
                  <Phone size={16} style={{ position: 'absolute', left: '0.75rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                  <input
                    type="tel"
                    required
                    className="form-input"
                    style={{ paddingLeft: '2.25rem' }}
                    value={formData.phone}
                    onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                    placeholder="+94 77 123 4567"
                  />
                </div>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.25rem' }}>
                  Used by the collection agent for calling before doorstep arrival.
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">District (Sri Lanka) *</label>
                <div style={{ position: 'relative' }}>
                  <Building size={16} style={{ position: 'absolute', left: '0.75rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)', pointerEvents: 'none' }} />
                  <select
                    required
                    className="form-input"
                    style={{ paddingLeft: '2.25rem' }}
                    value={formData.district}
                    onChange={(e) => setFormData({ ...formData, district: e.target.value })}
                  >
                    <option value="">-- Select District --</option>
                    {SRI_LANKAN_DISTRICTS.map((d) => (
                      <option key={d} value={d}>{d}</option>
                    ))}
                  </select>
                </div>
              </div>
            </div>

            <div className="grid-2">
              <div className="form-group">
                <label className="form-label">Town / City / Area *</label>
                <div style={{ position: 'relative' }}>
                  <MapPin size={16} style={{ position: 'absolute', left: '0.75rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                  <input
                    type="text"
                    required
                    className="form-input"
                    style={{ paddingLeft: '2.25rem' }}
                    value={formData.town}
                    onChange={(e) => setFormData({ ...formData, town: e.target.value })}
                    placeholder="e.g. Nugegoda, Kollupitiya, Dehiwala"
                  />
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">Street Address &amp; Landmark *</label>
                <div style={{ position: 'relative' }}>
                  <Home size={16} style={{ position: 'absolute', left: '0.75rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                  <input
                    type="text"
                    required
                    className="form-input"
                    style={{ paddingLeft: '2.25rem' }}
                    value={formData.address}
                    onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                    placeholder="e.g. No. 45, Baseline Road"
                  />
                </div>
              </div>
            </div>
          </div>

          {/* Live Agent Preview Card */}
          <div className="card" style={{ marginBottom: '1.5rem', background: '#F8FAF9', border: '1px dashed var(--primary)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.5rem', color: 'var(--primary)' }}>
              <Eye size={18} />
              <h4 style={{ fontSize: '0.9375rem', margin: 0, fontWeight: 600 }}>Live Agent View Preview</h4>
            </div>
            <p style={{ fontSize: '0.8125rem', color: 'var(--text-muted)', marginBottom: '0.875rem' }}>
              This is how your contact and location details will be displayed to collection agents on their job dispatch card:
            </p>

            <div style={{ background: 'var(--surface)', padding: '1rem', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '0.5rem', marginBottom: '0.5rem' }}>
                <div>
                  <div style={{ fontWeight: 600, fontSize: '0.9375rem', color: 'var(--text-main)' }}>
                    {formData.name || 'Customer Name'}
                  </div>
                  <div style={{ fontSize: '0.8125rem', color: 'var(--text-muted)' }}>
                    Pickup Location: <strong>{formData.town || 'Town'}</strong>, {formData.district || 'District'}
                  </div>
                </div>
                <div style={{ display: 'inline-flex', alignItems: 'center', gap: '0.375rem', padding: '0.25rem 0.625rem', background: 'var(--surface-subtle)', borderRadius: 'var(--radius-full)', fontSize: '0.8125rem', color: 'var(--primary)', fontWeight: 500 }}>
                  <Phone size={14} />
                  <span>{formData.phone || '+94 XX XXX XXXX'}</span>
                </div>
              </div>

              <div style={{ fontSize: '0.8125rem', color: 'var(--text-muted)', display: 'flex', alignItems: 'center', gap: '0.375rem' }}>
                <MapPin size={14} color="var(--primary)" />
                <span>
                  {formData.address ? `${formData.address}, ${formData.town}, ${formData.district}` : 'No street address provided yet'}
                </span>
              </div>
            </div>
          </div>

          <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
            <button
              type="submit"
              disabled={submitting}
              className="btn btn-primary"
              style={{ minWidth: '160px' }}
            >
              <Save size={16} />
              <span>{submitting ? 'Saving Changes...' : 'Save Profile Changes'}</span>
            </button>
          </div>
        </form>
      </div>
    </>
  )
}
