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

  const isAdmin = user?.role === 'Admin'

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')
    setSuccess('')

    if (!formData.name.trim()) {
      setError(isAdmin ? 'Please provide the administrator name.' : 'Please provide your full name.')
      return
    }

    if (!formData.phone.trim()) {
      setError(isAdmin ? 'Please provide an official contact phone number.' : 'Please provide a contact phone number for collection agents.')
      return
    }

    let cleanPhone = formData.phone.trim().replace(/[\s\-()]/g, '')
    if (cleanPhone.startsWith('+94')) {
      cleanPhone = '0' + cleanPhone.slice(3)
    }
    if (!/^[0-9]{10}$/.test(cleanPhone)) {
      setError('Please provide a valid 10-digit phone number (e.g. 0771234567).')
      return
    }

    if (!formData.district) {
      setError('Please select your district.')
      return
    }

    if (!formData.town.trim()) {
      setError(isAdmin ? 'Please provide your office city or area.' : 'Please provide your town or area.')
      return
    }

    if (!formData.address.trim()) {
      setError(isAdmin ? 'Please provide your office / headquarters address.' : 'Please provide your street address.')
      return
    }

    try {
      setSubmitting(true)
      await updateProfile({
        name: formData.name.trim(),
        phone: cleanPhone,
        district: formData.district,
        town: formData.town.trim(),
        address: formData.address.trim()
      })
      setSuccess(isAdmin ? 'Admin profile and contact details have been updated successfully.' : 'Your profile and pickup details have been updated successfully.')
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
      <TopBar title={isAdmin ? 'Admin Profile' : 'My Profile'} />

      <div className="content-container" style={{ maxWidth: '840px' }}>
        <div className="page-header">
          <div className="page-title-group">
            <h1>{isAdmin ? 'Administrator Profile & Contact Details' : 'Account & Pickup Details'}</h1>
            <div className="page-subtitle">
              {isAdmin
                ? 'Manage your administrative credentials, official contact phone number, and headquarters location'
                : 'Manage your personal information and default pickup address used for collection agent dispatch'}
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
          {/* Personal / Admin Information */}
          <div className="card" style={{ marginBottom: '1.5rem' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.625rem', marginBottom: '1.25rem', borderBottom: '1px solid var(--border)', paddingBottom: '0.75rem' }}>
              <User size={20} color="var(--primary)" />
              <h3 style={{ fontSize: '1.0625rem', margin: 0 }}>
                {isAdmin ? 'Administrator Information' : 'Personal Information'}
              </h3>
            </div>

            <div className="grid-2">
              <div className="form-group">
                <label className="form-label">{isAdmin ? 'Administrator Name *' : 'Full Name *'}</label>
                <div style={{ position: 'relative' }}>
                  <User size={16} style={{ position: 'absolute', left: '0.75rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                  <input
                    type="text"
                    required
                    className="form-input"
                    style={{ paddingLeft: '2.25rem' }}
                    value={formData.name}
                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    placeholder={isAdmin ? 'System Admin' : 'e.g. Kasun Jayasuriya'}
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

          {/* Contact & Office / Doorstep Address */}
          <div className="card" style={{ marginBottom: '1.5rem' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.625rem', marginBottom: '0.5rem', borderBottom: '1px solid var(--border)', paddingBottom: '0.75rem' }}>
              <MapPin size={20} color="var(--primary)" />
              <h3 style={{ fontSize: '1.0625rem', margin: 0 }}>
                {isAdmin ? 'Administrative Office & Contact Information' : 'Doorstep Pickup & Contact Information'}
              </h3>
            </div>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.8125rem', marginBottom: '1.25rem' }}>
              {isAdmin
                ? 'These details represent your official administrative office and direct contact phone for platform management and system communications.'
                : 'These details are essential for our collection agents. Whenever an agent is assigned to collect your disused electronic items, they will use this address and phone number for navigation and pickup coordination.'}
            </p>

            <div className="grid-2">
              <div className="form-group">
                <label className="form-label">{isAdmin ? 'Official Phone Number *' : 'Contact Phone Number *'}</label>
                <div style={{ position: 'relative' }}>
                  <Phone size={16} style={{ position: 'absolute', left: '0.75rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                  <input
                    type="tel"
                    required
                    className="form-input"
                    style={{ paddingLeft: '2.25rem' }}
                    value={formData.phone}
                    onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                    placeholder={isAdmin ? '0757809030' : '+94 77 123 4567'}
                  />
                </div>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.25rem' }}>
                  {isAdmin
                    ? 'Primary administrative phone line for urgent notifications and platform coordination.'
                    : 'Used by the collection agent for calling before doorstep arrival.'}
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">{isAdmin ? 'Operating District (Sri Lanka) *' : 'District (Sri Lanka) *'}</label>
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
                <label className="form-label">{isAdmin ? 'City / Town Area *' : 'Town / City / Area *'}</label>
                <div style={{ position: 'relative' }}>
                  <MapPin size={16} style={{ position: 'absolute', left: '0.75rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                  <input
                    type="text"
                    required
                    className="form-input"
                    style={{ paddingLeft: '2.25rem' }}
                    value={formData.town}
                    onChange={(e) => setFormData({ ...formData, town: e.target.value })}
                    placeholder={isAdmin ? 'e.g. Colombo 03' : 'e.g. Nugegoda, Kollupitiya, Dehiwala'}
                  />
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">{isAdmin ? 'Office / Headquarters Address *' : 'Street Address & Landmark *'}</label>
                <div style={{ position: 'relative' }}>
                  <Home size={16} style={{ position: 'absolute', left: '0.75rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                  <input
                    type="text"
                    required
                    className="form-input"
                    style={{ paddingLeft: '2.25rem' }}
                    value={formData.address}
                    onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                    placeholder={isAdmin ? 'e.g. No. 45/2, Galle Road' : 'e.g. No. 45, Baseline Road'}
                  />
                </div>
              </div>
            </div>
          </div>

          {/* Preview / Summary Card */}
          {isAdmin ? (
            <div className="card" style={{ marginBottom: '1.5rem', background: '#F8FAF9', border: '1px solid var(--border)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.5rem', color: 'var(--primary)' }}>
                <Shield size={18} />
                <h4 style={{ fontSize: '0.9375rem', margin: 0, fontWeight: 600 }}>Administrator Profile Summary</h4>
              </div>
              <p style={{ fontSize: '0.8125rem', color: 'var(--text-muted)', marginBottom: '0.875rem' }}>
                Official platform administrator credentials and operational office registered on LoopWorth:
              </p>

              <div style={{ background: 'var(--surface)', padding: '1rem', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border)' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '0.5rem', marginBottom: '0.5rem' }}>
                  <div>
                    <div style={{ fontWeight: 600, fontSize: '0.9375rem', color: 'var(--text-main)', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                      <span>{formData.name || 'System Admin'}</span>
                      <span style={{ fontSize: '0.6875rem', padding: '0.125rem 0.5rem', background: 'var(--primary)', color: '#fff', borderRadius: 'var(--radius-full)', fontWeight: 600 }}>
                        Super Admin
                      </span>
                    </div>
                    <div style={{ fontSize: '0.8125rem', color: 'var(--text-muted)', marginTop: '0.25rem' }}>
                      Office Base: <strong>{formData.town || 'Colombo 03'}</strong>, {formData.district || 'Colombo'}
                    </div>
                  </div>
                  <div style={{ display: 'inline-flex', alignItems: 'center', gap: '0.375rem', padding: '0.25rem 0.625rem', background: 'var(--surface-subtle)', borderRadius: 'var(--radius-full)', fontSize: '0.8125rem', color: 'var(--primary)', fontWeight: 500 }}>
                    <Phone size={14} />
                    <span>{formData.phone || '0757809030'}</span>
                  </div>
                </div>

                <div style={{ fontSize: '0.8125rem', color: 'var(--text-muted)', display: 'flex', alignItems: 'center', gap: '0.375rem', borderTop: '1px solid var(--border)', paddingTop: '0.5rem', marginTop: '0.5rem' }}>
                  <MapPin size={14} color="var(--primary)" />
                  <span>
                    {formData.address ? `${formData.address}, ${formData.town}, ${formData.district}` : 'No office address provided yet'}
                  </span>
                </div>
              </div>
            </div>
          ) : (
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
          )}

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
