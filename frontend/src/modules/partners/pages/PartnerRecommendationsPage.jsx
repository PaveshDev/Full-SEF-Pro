import React, { useEffect, useState } from 'react'
import { useParams, useNavigate, Link } from 'react-router'
import { ArrowLeft, Sparkles, Building2, CheckCircle2, AlertCircle, ArrowRight, Clock, MapPin } from 'lucide-react'
import { apiClient } from '../../../shared/services/apiClient.js'
import { StatusChip } from '../../../shared/components/StatusChip.jsx'
import { TopBar } from '../../../shared/components/TopBar.jsx'

export function PartnerRecommendationsPage() {
  const { id } = useParams() // recoveryRequestId
  const navigate = useNavigate()
  const [recovery, setRecovery] = useState(null)
  const [matches, setMatches] = useState([])
  const [selectedPartnerId, setSelectedPartnerId] = useState(null)
  const [loading, setLoading] = useState(true)
  const [matching, setMatching] = useState(false)
  const [selecting, setSelecting] = useState(false)
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

      // Fetch existing matches
      try {
        const matchesRes = await apiClient.get(`/api/recovery/${id}/partners/matches`)
        setMatches(matchesRes.data)
      } catch {
        setMatches([])
      }
    } catch {
      setError('Failed to load recovery details.')
    } finally {
      setLoading(false)
    }
  }

  // Run Agent 3 Partner Matching
  const handleRunMatching = async () => {
    setMatching(true)
    setError('')
    try {
      const res = await apiClient.post(`/api/recovery/${id}/partners/match`)
      setMatches(res.data)
      setSuccess('Agent 3 ranked available certified partners.')
    } catch (err) {
      setError(err.response?.data?.error || 'Partner matching failed.')
    } finally {
      setMatching(false)
    }
  }

  // Customer Selects Partner
  const handleSelectPartner = async (partnerId) => {
    setSelecting(true)
    setError('')
    try {
      await apiClient.post(`/api/recovery/${id}/partners/${partnerId}/select`)
      setSelectedPartnerId(partnerId)
      setSuccess('Partner selected successfully. Proceed to schedule collection.')
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to select partner.')
    } finally {
      setSelecting(false)
    }
  }

  if (loading) {
    return (
      <div style={{ padding: '3rem', textAlign: 'center' }}>
        <p style={{ color: 'var(--text-muted)' }}>Loading partners...</p>
      </div>
    )
  }

  return (
    <>
      <TopBar
        title="Partner Matching"
        action={
          <Link to={`/recovery/${id}`} className="btn btn-secondary btn-sm">
            <ArrowLeft size={16} />
            <span>Back to Plan</span>
          </Link>
        }
      />

      <div className="content-container">
        <div className="page-header">
          <div className="page-title-group">
            <h1>Select Certified Recovery Partner</h1>
            <div className="page-subtitle">
              Agent 3 pre-filters and ranks accredited facilities specializing in {recovery?.selectedRoute} for {recovery?.item?.category?.name}
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

        {matches.length === 0 ? (
          <div className="card" style={{ textAlign: 'center', padding: '3.5rem 2rem' }}>
            <Building2 size={36} color="var(--primary)" style={{ margin: '0 auto 1rem' }} />
            <h3 style={{ marginBottom: '0.5rem' }}>No Partner Matches Generated Yet</h3>
            <p style={{ color: 'var(--text-muted)', maxWidth: '480px', margin: '0 auto 1.5rem', fontSize: '0.875rem' }}>
              Run Agent 3 to evaluate accredited partners matching your item category and selected route ({recovery?.selectedRoute}).
            </p>
            <button
              onClick={handleRunMatching}
              disabled={matching}
              className="btn btn-primary"
            >
              <Sparkles size={16} />
              <span>{matching ? 'Matching with Agent 3...' : 'Run Partner Matching (Agent 3)'}</span>
            </button>
          </div>
        ) : (
          <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem' }}>
              <div style={{ fontSize: '0.875rem', color: 'var(--text-muted)' }}>
                Showing <strong>{matches.length}</strong> ranked partners
              </div>
              <button
                onClick={handleRunMatching}
                disabled={matching}
                className="btn btn-secondary btn-sm"
              >
                <Sparkles size={14} />
                <span>Re-run Agent 3 Matching</span>
              </button>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '1.25rem', marginBottom: '2rem' }}>
              {matches.map((m) => {
                const isSelected = selectedPartnerId === m.partnerId
                return (
                  <div
                    key={m.id}
                    className={`card ${isSelected ? 'border-primary' : ''}`}
                    style={{
                      borderWidth: isSelected ? '2px' : '1px',
                      borderColor: isSelected ? 'var(--primary)' : undefined,
                      display: 'flex',
                      flexDirection: 'column',
                      justifyContent: 'space-between'
                    }}
                  >
                    <div>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '0.75rem' }}>
                        <div>
                          <span style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--primary)', background: 'var(--primary-light)', padding: '0.2rem 0.5rem', borderRadius: 'var(--radius-full)' }}>
                            RANK #{m.rank}
                          </span>
                          <h3 style={{ fontSize: '1.125rem', marginTop: '0.5rem' }}>{m.partnerName}</h3>
                        </div>
                        {isSelected && (
                          <div style={{ background: 'var(--primary)', color: '#fff', borderRadius: 'var(--radius-full)', padding: '0.25rem' }}>
                            <CheckCircle2 size={16} />
                          </div>
                        )}
                      </div>

                      <div style={{ display: 'flex', gap: '1rem', fontSize: '0.8125rem', color: 'var(--text-muted)', marginBottom: '1rem' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.25rem' }}>
                          <MapPin size={14} />
                          <span>{m.serviceArea}</span>
                        </div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '0.25rem' }}>
                          <Clock size={14} />
                          <span>~{m.averageProcessingDays} days avg</span>
                        </div>
                      </div>

                      <div style={{ background: '#F8FAFC', padding: '0.75rem', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-light)', fontSize: '0.8125rem', color: 'var(--text-main)', marginBottom: '1.25rem' }}>
                        <div style={{ fontWeight: 600, color: 'var(--dark)', marginBottom: '0.25rem' }}>AI Matching Rationale:</div>
                        {m.reason}
                      </div>
                    </div>

                    <div>
                      <button
                        onClick={() => handleSelectPartner(m.partnerId)}
                        disabled={selecting}
                        className={`btn btn-sm ${isSelected ? 'btn-primary' : 'btn-secondary'}`}
                        style={{ width: '100%' }}
                      >
                        {isSelected ? 'Selected Partner' : 'Choose This Partner'}
                      </button>
                    </div>
                  </div>
                )
              })}
            </div>

            {selectedPartnerId && (
              <div className="card" style={{ background: 'var(--primary-light)', border: '1px solid var(--primary)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div>
                  <h3 style={{ color: 'var(--primary)', fontSize: '1.125rem' }}>Partner Selection Confirmed</h3>
                  <div style={{ fontSize: '0.875rem', color: 'var(--dark)', marginTop: '0.25rem' }}>
                    Next step: Set your preferred pickup time and have Agent 4 propose the collection schedule.
                  </div>
                </div>
                <button
                  onClick={() => navigate(`/recovery/${id}/schedule`)}
                  className="btn btn-primary"
                >
                  <span>Schedule Collection (Agent 4)</span>
                  <ArrowRight size={16} />
                </button>
              </div>
            )}
          </div>
        )}
      </div>
    </>
  )
}
