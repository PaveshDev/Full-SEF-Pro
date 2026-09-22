import React, { useState } from 'react'
import { Link, useNavigate } from 'react-router'
import { Repeat, AlertCircle, ArrowRight, Eye, EyeOff, Check, X } from 'lucide-react'
import { useAuth } from '../../shared/context/AuthContext.jsx'

export function RegisterPage() {
  const { register } = useAuth()
  const navigate = useNavigate()

  // Form values
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [phone, setPhone] = useState('')
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [district, setDistrict] = useState('Colombo')
  const [town, setTown] = useState('')
  const [address, setAddress] = useState('')

  // UI state
  const [showPassword, setShowPassword] = useState(false)
  const [showConfirmPassword, setShowConfirmPassword] = useState(false)
  const [fieldErrors, setFieldErrors] = useState({})
  const [touched, setTouched] = useState({})
  const [generalError, setGeneralError] = useState('')
  const [loading, setLoading] = useState(false)

  const SRI_LANKA_DISTRICTS = [
    'Colombo', 'Gampaha', 'Kalutara', 'Kandy', 'Matale', 'Nuwara Eliya',
    'Galle', 'Matara', 'Hambantota', 'Jaffna', 'Kilinochchi', 'Mannar',
    'Vavuniya', 'Mullaitivu', 'Batticaloa', 'Ampara', 'Trincomalee',
    'Kurunegala', 'Puttalam', 'Anuradhapura', 'Polonnaruwa', 'Badulla',
    'Monaragala', 'Ratnapura', 'Kegalle'
  ]

  // Password rule checks
  const passLengthOk = password.length >= 8
  const passUpperOk = /[A-Z]/.test(password)
  const passDigitOk = /[0-9]/.test(password)
  const passwordsMatch = confirmPassword.length > 0 && password === confirmPassword

  // Validation function
  const validate = (fields) => {
    const errors = {}

    // Full Name
    const trimmedName = (fields.name || '').trim()
    if (!trimmedName) {
      errors.name = 'Full name is required.'
    } else if (trimmedName.length < 2) {
      errors.name = 'Full name must be at least 2 characters.'
    } else if (!/^[a-zA-Z\s.'-]+$/.test(trimmedName)) {
      errors.name = 'Full name should only contain letters and spaces.'
    }

    // Email
    const trimmedEmail = (fields.email || '').trim()
    if (!trimmedEmail) {
      errors.email = 'Email address is required.'
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmedEmail)) {
      errors.email = 'Please enter a valid email address (e.g. name@example.com).'
    }

    // Phone
    const cleanPhone = (fields.phone || '').replace(/[\s-]/g, '')
    if (!cleanPhone) {
      errors.phone = 'Phone number is required.'
    } else if (!/^(?:\+94|0)?[0-9]{9,10}$/.test(cleanPhone)) {
      errors.phone = 'Please enter a valid phone number (e.g. 0771234567 or +94771234567).'
    }

    // Password
    if (!fields.password) {
      errors.password = 'Password is required.'
    } else {
      if (fields.password.length < 8) {
        errors.password = 'Password must be at least 8 characters.'
      } else if (!/[A-Z]/.test(fields.password)) {
        errors.password = 'Password must contain at least one uppercase letter (A-Z).'
      } else if (!/[0-9]/.test(fields.password)) {
        errors.password = 'Password must contain at least one number (0-9).'
      }
    }

    // Confirm Password
    if (!fields.confirmPassword) {
      errors.confirmPassword = 'Please confirm your password.'
    } else if (fields.password !== fields.confirmPassword) {
      errors.confirmPassword = 'Passwords do not match.'
    }

    // District
    if (!fields.district) {
      errors.district = 'Please select a district.'
    }

    // Town
    const trimmedTown = (fields.town || '').trim()
    if (!trimmedTown) {
      errors.town = 'Town or city is required.'
    } else if (trimmedTown.length < 2) {
      errors.town = 'Town or city must be at least 2 characters.'
    }

    // Street Address
    const trimmedAddress = (fields.address || '').trim()
    if (!trimmedAddress) {
      errors.address = 'Street address is required.'
    } else if (trimmedAddress.length < 5) {
      errors.address = 'Please provide a complete street address (minimum 5 characters).'
    }

    return errors
  }

  const handleBlur = (field) => {
    setTouched((prev) => ({ ...prev, [field]: true }))
    const currentFields = { name, email, phone, password, confirmPassword, district, town, address }
    const errors = validate(currentFields)
    setFieldErrors(errors)
  }

  const handleChange = (field, value, setter) => {
    setter(value)
    if (touched[field]) {
      const currentFields = { name, email, phone, password, confirmPassword, district, town, address, [field]: value }
      const errors = validate(currentFields)
      setFieldErrors(errors)
    }
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setGeneralError('')

    const currentFields = { name, email, phone, password, confirmPassword, district, town, address }
    const errors = validate(currentFields)
    setFieldErrors(errors)

    // Mark all as touched
    setTouched({
      name: true,
      email: true,
      phone: true,
      password: true,
      confirmPassword: true,
      district: true,
      town: true,
      address: true
    })

    if (Object.keys(errors).length > 0) {
      setGeneralError('Please resolve the errors highlighted below.')
      return
    }

    setLoading(true)
    try {
      await register({
        name: name.trim(),
        email: email.trim(),
        password,
        phone: phone.trim(),
        address: address.trim(),
        district,
        town: town.trim()
      })
      navigate('/dashboard')
    } catch (err) {
      setGeneralError(err.response?.data?.error || 'Registration failed. Please check inputs.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', backgroundColor: 'var(--background)', padding: '2rem 1rem' }}>
      <div style={{ width: '100%', maxWidth: '560px' }}>
        <div style={{ textAlign: 'center', marginBottom: '1.75rem' }}>
          <div style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', background: 'var(--primary-light)', padding: '0.75rem', borderRadius: 'var(--radius-md)', marginBottom: '0.75rem' }}>
            <Repeat size={32} color="var(--primary)" />
          </div>
          <h1 style={{ fontSize: '1.75rem', margin: 0 }}>Create Customer Account</h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem', marginTop: '0.25rem' }}>
            Enter your details for convenient e-waste collection and pickup
          </p>
        </div>

        <div className="card">
          {generalError && (
            <div className="alert alert-error" style={{ marginBottom: '1.25rem' }}>
              <AlertCircle size={18} />
              <span>{generalError}</span>
            </div>
          )}

          <form onSubmit={handleSubmit} noValidate>
            {/* Full Name */}
            <div className="form-group">
              <label className="form-label">Full Name *</label>
              <input
                type="text"
                className="form-input"
                style={{ borderColor: touched.name && fieldErrors.name ? 'var(--error)' : undefined }}
                placeholder="Kasun Silva"
                value={name}
                onChange={(e) => handleChange('name', e.target.value, setName)}
                onBlur={() => handleBlur('name')}
              />
              {touched.name && fieldErrors.name && (
                <div className="form-error">{fieldErrors.name}</div>
              )}
            </div>

            {/* Email & Phone */}
            <div className="grid-2">
              <div className="form-group">
                <label className="form-label">Email Address *</label>
                <input
                  type="email"
                  className="form-input"
                  style={{ borderColor: touched.email && fieldErrors.email ? 'var(--error)' : undefined }}
                  placeholder="kasun@example.com"
                  value={email}
                  onChange={(e) => handleChange('email', e.target.value, setEmail)}
                  onBlur={() => handleBlur('email')}
                />
                {touched.email && fieldErrors.email && (
                  <div className="form-error">{fieldErrors.email}</div>
                )}
              </div>

              <div className="form-group">
                <label className="form-label">Phone Number *</label>
                <input
                  type="tel"
                  className="form-input"
                  style={{ borderColor: touched.phone && fieldErrors.phone ? 'var(--error)' : undefined }}
                  placeholder="0771234567"
                  value={phone}
                  onChange={(e) => handleChange('phone', e.target.value, setPhone)}
                  onBlur={() => handleBlur('phone')}
                />
                {touched.phone && fieldErrors.phone && (
                  <div className="form-error">{fieldErrors.phone}</div>
                )}
              </div>
            </div>

            {/* Password & Confirm Password */}
            <div className="grid-2">
              <div className="form-group">
                <label className="form-label">Password *</label>
                <div style={{ position: 'relative' }}>
                  <input
                    type={showPassword ? 'text' : 'password'}
                    className="form-input"
                    style={{
                      paddingRight: '2.5rem',
                      borderColor: touched.password && fieldErrors.password ? 'var(--error)' : undefined
                    }}
                    placeholder="••••••••"
                    value={password}
                    onChange={(e) => handleChange('password', e.target.value, setPassword)}
                    onBlur={() => handleBlur('password')}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    style={{
                      position: 'absolute',
                      right: '0.625rem',
                      top: '50%',
                      transform: 'translateY(-50%)',
                      background: 'none',
                      border: 'none',
                      cursor: 'pointer',
                      color: 'var(--text-muted)',
                      display: 'flex',
                      alignItems: 'center',
                      padding: 0
                    }}
                    title={showPassword ? 'Hide password' : 'Show password'}
                  >
                    {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                  </button>
                </div>
                {touched.password && fieldErrors.password && (
                  <div className="form-error">{fieldErrors.password}</div>
                )}
              </div>

              <div className="form-group">
                <label className="form-label">Confirm Password *</label>
                <div style={{ position: 'relative' }}>
                  <input
                    type={showConfirmPassword ? 'text' : 'password'}
                    className="form-input"
                    style={{
                      paddingRight: '2.5rem',
                      borderColor: touched.confirmPassword && fieldErrors.confirmPassword ? 'var(--error)' : undefined
                    }}
                    placeholder="••••••••"
                    value={confirmPassword}
                    onChange={(e) => handleChange('confirmPassword', e.target.value, setConfirmPassword)}
                    onBlur={() => handleBlur('confirmPassword')}
                  />
                  <button
                    type="button"
                    onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                    style={{
                      position: 'absolute',
                      right: '0.625rem',
                      top: '50%',
                      transform: 'translateY(-50%)',
                      background: 'none',
                      border: 'none',
                      cursor: 'pointer',
                      color: 'var(--text-muted)',
                      display: 'flex',
                      alignItems: 'center',
                      padding: 0
                    }}
                    title={showConfirmPassword ? 'Hide password' : 'Show password'}
                  >
                    {showConfirmPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                  </button>
                </div>
                {touched.confirmPassword && fieldErrors.confirmPassword && (
                  <div className="form-error">{fieldErrors.confirmPassword}</div>
                )}
              </div>
            </div>

            {/* Password Requirement Guidance */}
            <div
              style={{
                background: '#F8FAFC',
                border: '1px solid var(--border-light)',
                borderRadius: 'var(--radius-sm)',
                padding: '0.625rem 0.875rem',
                marginBottom: '1rem',
                fontSize: '0.75rem'
              }}
            >
              <div style={{ fontWeight: 600, color: 'var(--text-main)', marginBottom: '0.25rem' }}>
                Password Requirements:
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: '0.25rem' }}>
                <span style={{ display: 'flex', alignItems: 'center', gap: '0.3rem', color: passLengthOk ? '#166534' : 'var(--text-muted)' }}>
                  {passLengthOk ? <Check size={13} color="#166534" /> : <span style={{ width: '13px', display: 'inline-block' }}>•</span>}
                  8+ characters
                </span>
                <span style={{ display: 'flex', alignItems: 'center', gap: '0.3rem', color: passUpperOk ? '#166534' : 'var(--text-muted)' }}>
                  {passUpperOk ? <Check size={13} color="#166534" /> : <span style={{ width: '13px', display: 'inline-block' }}>•</span>}
                  One uppercase (A-Z)
                </span>
                <span style={{ display: 'flex', alignItems: 'center', gap: '0.3rem', color: passDigitOk ? '#166534' : 'var(--text-muted)' }}>
                  {passDigitOk ? <Check size={13} color="#166534" /> : <span style={{ width: '13px', display: 'inline-block' }}>•</span>}
                  One number (0-9)
                </span>
                {confirmPassword && (
                  <span style={{ display: 'flex', alignItems: 'center', gap: '0.3rem', color: passwordsMatch ? '#166534' : 'var(--error)' }}>
                    {passwordsMatch ? <Check size={13} color="#166534" /> : <X size={13} color="var(--error)" />}
                    Passwords match
                  </span>
                )}
              </div>
            </div>

            {/* District & Town */}
            <div className="grid-2">
              <div className="form-group">
                <label className="form-label">District *</label>
                <select
                  className="form-select"
                  style={{ borderColor: touched.district && fieldErrors.district ? 'var(--error)' : undefined }}
                  value={district}
                  onChange={(e) => handleChange('district', e.target.value, setDistrict)}
                  onBlur={() => handleBlur('district')}
                >
                  {SRI_LANKA_DISTRICTS.map((d) => (
                    <option key={d} value={d}>{d}</option>
                  ))}
                </select>
                {touched.district && fieldErrors.district && (
                  <div className="form-error">{fieldErrors.district}</div>
                )}
              </div>

              <div className="form-group">
                <label className="form-label">Town / City *</label>
                <input
                  type="text"
                  className="form-input"
                  style={{ borderColor: touched.town && fieldErrors.town ? 'var(--error)' : undefined }}
                  placeholder="e.g. Kollupitiya, Akkaraipattu"
                  value={town}
                  onChange={(e) => handleChange('town', e.target.value, setTown)}
                  onBlur={() => handleBlur('town')}
                />
                {touched.town && fieldErrors.town && (
                  <div className="form-error">{fieldErrors.town}</div>
                )}
              </div>
            </div>

            {/* Street Address */}
            <div className="form-group">
              <label className="form-label">Pickup Street Address *</label>
              <input
                type="text"
                className="form-input"
                style={{ borderColor: touched.address && fieldErrors.address ? 'var(--error)' : undefined }}
                placeholder="e.g. No. 45, Galle Road, 2nd Floor"
                value={address}
                onChange={(e) => handleChange('address', e.target.value, setAddress)}
                onBlur={() => handleBlur('address')}
              />
              {touched.address && fieldErrors.address ? (
                <div className="form-error">{fieldErrors.address}</div>
              ) : (
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.25rem' }}>
                  Used by collection agents to navigate and pick up your items.
                </div>
              )}
            </div>

            <button
              type="submit"
              disabled={loading}
              className="btn btn-primary"
              style={{ width: '100%', marginTop: '0.75rem' }}
            >
              <span>{loading ? 'Creating account...' : 'Register as Customer'}</span>
              <ArrowRight size={16} />
            </button>
          </form>
        </div>

        <div style={{ textAlign: 'center', marginTop: '1.5rem', fontSize: '0.875rem', color: 'var(--text-muted)' }}>
          Already have an account?{' '}
          <Link to="/login" style={{ fontWeight: 600 }}>Sign In</Link>
        </div>
      </div>
    </div>
  )
}
