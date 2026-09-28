import React, { useState } from 'react'
import { Link, useNavigate } from 'react-router'
import { Repeat, AlertCircle, ArrowRight } from 'lucide-react'
import { useAuth } from '../../shared/context/AuthContext.jsx'

export function LoginPage() {
  const { login } = useAuth()
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')

    if (!email.trim() || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) {
      setError('Please enter a valid email address.')
      return
    }

    if (!password) {
      setError('Password is required.')
      return
    }

    setLoading(true)
    try {
      const user = await login(email, password)
      if (user.role === 'Admin') navigate('/admin')
      else if (user.role === 'CollectionAgent') navigate('/agent')
      else if (user.role === 'Partner') navigate('/partner')
      else navigate('/dashboard')
    } catch (err) {
      setError(err.response?.data?.error || 'Invalid email or password.')
    } finally {
      setLoading(false)
    }
  }

  const handleQuickLogin = (quickEmail, quickPass) => {
    setEmail(quickEmail)
    setPassword(quickPass)
  }

  return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', backgroundColor: 'var(--background)', padding: '2rem' }}>
      <div style={{ width: '100%', maxWidth: '440px' }}>
        <div style={{ textAlign: 'center', marginBottom: '2rem' }}>
          <div style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', background: 'var(--primary-light)', padding: '0.75rem', borderRadius: 'var(--radius-md)', marginBottom: '1rem' }}>
            <Repeat size={32} color="var(--primary)" />
          </div>
          <h1 style={{ fontSize: '1.75rem' }}>Welcome to LoopWorth</h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem', marginTop: '0.25rem' }}>
            Sign in to manage your waste recovery pipeline
          </p>
        </div>

        <div className="card">
          {error && (
            <div className="alert alert-error">
              <AlertCircle size={18} />
              <span>{error}</span>
            </div>
          )}

          <form onSubmit={handleSubmit}>
            <div className="form-group">
              <label className="form-label">Email Address</label>
              <input
                type="email"
                required
                className="form-input"
                placeholder="name@example.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </div>

            <div className="form-group">
              <label className="form-label">Password</label>
              <input
                type="password"
                required
                className="form-input"
                placeholder="••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>

            <button
              type="submit"
              disabled={loading}
              className="btn btn-primary"
              style={{ width: '100%', marginTop: '0.5rem' }}
            >
              <span>{loading ? 'Signing in...' : 'Sign In'}</span>
              <ArrowRight size={16} />
            </button>
          </form>

          {/* Quick Admin Login */}
          <div style={{ marginTop: '1.75rem', paddingTop: '1.25rem', borderTop: '1px solid var(--border-light)' }}>
            <div style={{ fontSize: '0.75rem', fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase', marginBottom: '0.75rem' }}>
              Quick Admin Login
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
              <button
                type="button"
                onClick={() => handleQuickLogin('loopworthadmin@gmail.com', 'Admin123!')}
                className="btn btn-secondary btn-sm"
                style={{ justifyContent: 'space-between' }}
              >
                <span>Admin Portal</span>
                <span style={{ color: 'var(--text-muted)', fontSize: '0.75rem' }}>loopworthadmin@gmail.com</span>
              </button>
            </div>
          </div>
        </div>

        <div style={{ textAlign: 'center', marginTop: '1.5rem', fontSize: '0.875rem', color: 'var(--text-muted)' }}>
          Don't have an account?{' '}
          <Link to="/register" style={{ fontWeight: 600 }}>Create an account</Link>
        </div>
      </div>
    </div>
  )
}
