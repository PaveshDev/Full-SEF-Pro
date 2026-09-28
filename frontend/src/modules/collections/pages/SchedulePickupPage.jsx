import React, { useEffect, useState } from 'react'
import { useParams, useNavigate, Link } from 'react-router'
import { ArrowLeft, Truck, Sparkles, CheckCircle2, AlertCircle, ArrowRight, Calendar, Clock, MapPin, Phone, ExternalLink } from 'lucide-react'
import { apiClient } from '../../../shared/services/apiClient.js'
import { useAuth } from '../../../shared/context/AuthContext.jsx'
import { StatusChip } from '../../../shared/components/StatusChip.jsx'
import { TopBar } from '../../../shared/components/TopBar.jsx'

export function SchedulePickupPage() {
  const { user } = useAuth()
  const { id } = useParams() // recoveryRequestId
  const navigate = useNavigate()
  const [recovery, setRecovery] = useState(null)
  const [collection, setCollection] = useState(null)
  const [preferredDate, setPreferredDate] = useState(() => {
    const d = new Date()
    d.setDate(d.getDate() + 1)
    return d.toISOString().split('T')[0]
  })
  const [startTime, setStartTime] = useState('09:00')
  const [endTime, setEndTime] = useState('12:00')
  const [loading, setLoading] = useState(true)
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  useEffect(() => {
    loadData()
  }, [id])

  const loadData = async () => {
    try {
      setLoading(true)
      const recRes = await apiClient.get(`/api/recovery/${id}`)
      setRecovery(recRes.data)

      const colRes = await apiClient.get('/api/collections')
      const existing = colRes.data.find((c) => c.recoveryRequestId === id)
      if (existing) {
        setCollection(existing)
        if (existing.preferredPickupDate) {
          setPreferredDate(existing.preferredPickupDate.split('T')[0])
        }
        if (existing.preferredStartTime) setStartTime(existing.preferredStartTime.slice(0, 5))
        if (existing.preferredEndTime) setEndTime(existing.preferredEndTime.slice(0, 5))
      }
    } catch {
      setError('Failed to load recovery details.')
    } finally {
      setLoading(false)
    }
  }

  const handleSchedule = async (e) => {
    e.preventDefault()
    setError('')

    if (!preferredDate) {
      setError('Please select your preferred pickup date.')
      return
    }

    if (!startTime || !endTime) {
      setError('Please select both window start and end times.')
      return
    }

    if (startTime >= endTime) {
      setError('Preferred start time must be earlier than end time.')
      return
    }

    setSubmitting(true)
    try {
      const res = await apiClient.post(`/api/recovery/${id}/collections`, {
        preferredPickupDate: new Date(preferredDate).toISOString(),
        preferredStartTime: `${startTime}:00`,
        preferredEndTime: `${endTime}:00`
      })
      setCollection(res.data)
      setSuccess('Pickup request submitted. Awaiting Admin dispatch.')
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to submit pickup request.')
    } finally {
      setSubmitting(false)
    }
  }

  if (loading) {
    return (
      <div style={{ padding: '3rem', textAlign: 'center' }}>
        <p style={{ color: 'var(--text-muted)' }}>Loading schedule details...</p>
      </div>
    )
  }

  return (
    <>
      <TopBar
        title="Schedule Collection"
        action={
          <Link to={`/matching-partners/${id}`} className="btn btn-secondary btn-sm">
            <ArrowLeft size={16} />
            <span>Back to Partner Matching</span>
          </Link>
        }
      />

      <div className="content-container" style={{ maxWidth: '720px' }}>
        <div className="page-header">
          <div className="page-title-group">
            <h1>Request Pickup & Collection</h1>
            <div className="page-subtitle">
              Submit your preferred pickup window. LoopWorth Admin will dispatch an available agent in your area.
            </div>
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

        {/* Customer Address Banner */}
        <div className="card" style={{ marginBottom: '1.25rem', background: '#F8FAF9', border: '1px solid var(--border)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '0.75rem' }}>
            <div style={{ display: 'flex', alignItems: 'flex-start', gap: '0.75rem' }}>
              <MapPin size={20} color="var(--primary)" style={{ marginTop: '0.125rem' }} />
              <div>
                <div style={{ fontWeight: 600, fontSize: '0.875rem', marginBottom: '0.25rem' }}>
                  Doorstep Pickup Address for Collection Agent:
                </div>
                <div style={{ fontSize: '0.8125rem', color: 'var(--text-muted)' }}>
                  {user?.address ? `${user.address}, ${user.town}, ${user.district}` : 'Address not configured'}
                </div>
                {user?.phone && (
                  <div style={{ fontSize: '0.8125rem', color: 'var(--text-muted)', marginTop: '0.25rem', display: 'flex', alignItems: 'center', gap: '0.375rem' }}>
                    <Phone size={12} color="var(--primary)" />
                    <span>Contact: {user.phone}</span>
                  </div>
                )}
              </div>
            </div>
            <Link to="/profile" className="btn btn-secondary btn-sm" style={{ alignSelf: 'flex-start' }}>
              <span>Edit Address</span>
              <ExternalLink size={12} />
            </Link>
          </div>
        </div>

        <div className="card" style={{ marginBottom: '1.5rem' }}>
          <h3 style={{ marginBottom: '0.25rem' }}>Customer Pickup Preferences</h3>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem', marginBottom: '1.5rem' }}>
            Enter your preferred pickup date and time window for collection.
          </p>

          <form onSubmit={handleSchedule}>
            <div className="form-group">
              <label className="form-label">Preferred Date *</label>
              <input
                type="date"
                required
                className="form-input"
                min={new Date().toISOString().split('T')[0]}
                value={preferredDate}
                onChange={(e) => setPreferredDate(e.target.value)}
              />
            </div>

            <div className="grid-2">
              <div className="form-group">
                <label className="form-label">Preferred Window Start *</label>
                <input
                  type="time"
                  required
                  className="form-input"
                  value={startTime}
                  onChange={(e) => setStartTime(e.target.value)}
                />
              </div>
              <div className="form-group">
                <label className="form-label">Preferred Window End *</label>
                <input
                  type="time"
                  required
                  className="form-input"
                  value={endTime}
                  onChange={(e) => setEndTime(e.target.value)}
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={submitting}
              className="btn btn-primary"
              style={{ width: '100%', marginTop: '0.5rem' }}
            >
              <Truck size={16} />
              <span>{submitting ? 'Submitting Pickup Request...' : 'Submit Pickup Request'}</span>
            </button>
          </form>
        </div>

        {/* Collection Request Status Card */}
        {collection && (
          <div className="card" style={{ border: '1px solid var(--primary)', background: '#FAFCFA' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.75rem', color: 'var(--primary)' }}>
              <CheckCircle2 size={20} />
              <h3 style={{ fontSize: '1.125rem' }}>Collection Request Submitted</h3>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '1rem', padding: '1rem', background: 'var(--surface)', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border)', marginBottom: '1.25rem' }}>
              <div>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Suggested Pickup Date</div>
                <div style={{ fontWeight: 600, marginTop: '0.25rem' }}>
                  {collection.suggestedPickupDate ? new Date(collection.suggestedPickupDate).toLocaleDateString() : 'Pending'}
                </div>
              </div>
              <div>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Suggested Time Window</div>
                <div style={{ fontWeight: 600, marginTop: '0.25rem' }}>
                  {collection.suggestedStartTime ? `${collection.suggestedStartTime.slice(0, 5)} - ${collection.suggestedEndTime?.slice(0, 5)}` : 'Flexible'}
                </div>
              </div>
              <div>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Status</div>
                <div style={{ marginTop: '0.25rem' }}>
                  <StatusChip status={collection.status} />
                </div>
              </div>
            </div>

            <p style={{ fontSize: '0.8125rem', color: 'var(--text-muted)', lineHeight: 1.5, marginBottom: '1.25rem' }}>
              Your collection pickup request has been submitted. LoopWorth Admin will review the request and assign an available collection agent in your area using Agentic AI dispatch.
            </p>

            <button
              onClick={() => navigate('/collections')}
              className="btn btn-primary"
              style={{ width: '100%' }}
            >
              <span>View In Collections Dashboard</span>
              <ArrowRight size={16} />
            </button>
          </div>
        )}
      </div>
    </>
  )
}
