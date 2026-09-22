import React, { useEffect, useState } from 'react'
import { useParams, useNavigate, Link } from 'react-router'
import { Sparkles, Building2, CheckCircle2, AlertCircle, ArrowRight, Clock, MapPin, Repeat, Package, ShieldCheck, Truck } from 'lucide-react'
import { apiClient } from '../../../shared/services/apiClient.js'
import { StatusChip } from '../../../shared/components/StatusChip.jsx'
import { TopBar } from '../../../shared/components/TopBar.jsx'

export function CustomerPartnerMatchingPage() {
  const { id: routeId } = useParams()
  const navigate = useNavigate()

  const [approvedRecoveries, setApprovedRecoveries] = useState([])
  const [selectedRecovery, setSelectedRecovery] = useState(null)
  const [matches, setMatches] = useState([])
  const [selectedPartnerId, setSelectedPartnerId] = useState(null)
  const [existingCollection, setExistingCollection] = useState(null)

  const [loading, setLoading] = useState(true)
  const [loadingMatches, setLoadingMatches] = useState(false)
  const [matching, setMatching] = useState(false)
  const [selecting, setSelecting] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  // 1. Load all approved recovery requests for the customer
  useEffect(() => {
    loadApprovedRecoveries()
  }, [])

  // 2. When approved recoveries change or routeId changes, set selected recovery
  useEffect(() => {
    if (approvedRecoveries.length > 0) {
      if (routeId) {
        const found = approvedRecoveries.find(r => r.id === routeId)
        if (found) {
          setSelectedRecovery(found)
          return
        }
      }
      setSelectedRecovery(approvedRecoveries[0])
    } else {
      setSelectedRecovery(null)
    }
  }, [approvedRecoveries, routeId])

  // 3. When selected recovery changes, fetch matches and collection status
  useEffect(() => {
    if (selectedRecovery) {
      loadRecoveryPartnerData(selectedRecovery.id)
    } else {
      setMatches([])
      setSelectedPartnerId(null)
      setExistingCollection(null)
    }
  }, [selectedRecovery?.id])

  const loadApprovedRecoveries = async () => {
    try {
      setLoading(true)
      setError('')
      const res = await apiClient.get('/api/recovery?status=Approved')
      setApprovedRecoveries(res.data || [])
    } catch {
      setError('Failed to load approved recovery requests.')
    } finally {
      setLoading(false)
    }
  }

  const loadRecoveryPartnerData = async (recoveryId) => {
    try {
      setLoadingMatches(true)
      setError('')
      setSuccess('')

      // Fetch existing matches
      const matchesPromise = apiClient.get(`/api/recovery/${recoveryId}/partners/matches`)
        .then(res => res.data)
        .catch(() => [])

      // Fetch collections to check if a partner and collection were already scheduled
      const collectionsPromise = apiClient.get('/api/collections')
        .then(res => res.data.find(c => c.recoveryRequestId === recoveryId))
        .catch(() => null)

      const [loadedMatches, col] = await Promise.all([matchesPromise, collectionsPromise])

      setMatches(loadedMatches)
      setExistingCollection(col || null)

      if (col?.partnerId) {
        setSelectedPartnerId(col.partnerId)
      } else {
        setSelectedPartnerId(null)
      }
    } catch {
      setError('Failed to load partner matching details.')
    } finally {
      setLoadingMatches(false)
    }
  }

  // Run Agent 3 Partner Matching
  const handleRunMatching = async () => {
    if (!selectedRecovery) return
    setMatching(true)
    setError('')
    try {
      const res = await apiClient.post(`/api/recovery/${selectedRecovery.id}/partners/match`)
      setMatches(res.data)
      setSuccess('Agent 3 evaluated and ranked certified recovery partners.')
    } catch (err) {
      setError(err.response?.data?.error || 'Partner matching failed.')
    } finally {
      setMatching(false)
    }
  }

  // Customer Selects Partner
  const handleSelectPartner = async (partnerId) => {
    if (!selectedRecovery) return
    setSelecting(true)
    setError('')
    try {
      await apiClient.post(`/api/recovery/${selectedRecovery.id}/partners/${partnerId}/select`)
      setSelectedPartnerId(partnerId)
      setSuccess('Partner selected successfully! You can now proceed to schedule collection.')
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to select partner.')
    } finally {
      setSelecting(false)
    }
  }

  const handleSwitchRecovery = (rec) => {
    setSelectedRecovery(rec)
    navigate(`/matching-partners/${rec.id}`)
  }

  if (loading) {
    return (
      <div style={{ padding: '3rem', textAlign: 'center' }}>
        <p style={{ color: 'var(--text-muted)' }}>Loading approved recovery requests...</p>
      </div>
    )
  }

  return (
    <>
      <TopBar title="Partner Matching" />

      <div className="content-container">
        <div className="page-header">
          <div className="page-title-group">
            <h1>Certified Partner Matching</h1>
            <div className="page-subtitle">
              Agent 3 pre-filters and ranks accredited facilities for your admin-approved recovery requests
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

        {/* Empty state when customer has no approved recoveries */}
        {approvedRecoveries.length === 0 ? (
          <div className="card" style={{ textAlign: 'center', padding: '3.5rem 2rem' }}>
            <Building2 size={40} color="var(--primary)" style={{ margin: '0 auto 1rem' }} />
            <h3 style={{ marginBottom: '0.5rem' }}>No Approved Recovery Requests Ready for Matching</h3>
            <p style={{ color: 'var(--text-muted)', maxWidth: '520px', margin: '0 auto 1.5rem', fontSize: '0.875rem', lineHeight: 1.6 }}>
              Once you submit an item recovery preparation plan and it is verified and approved by the admin, it will appear here so you can match and select certified partners.
            </p>
            <div style={{ display: 'flex', gap: '0.75rem', justifyContent: 'center' }}>
              <Link to="/recovery" className="btn btn-secondary">
                <Repeat size={16} />
                <span>View Recovery Requests</span>
              </Link>
              <Link to="/items" className="btn btn-primary">
                <Package size={16} />
                <span>My Items</span>
              </Link>
            </div>
          </div>
        ) : (
          <div>
            {/* Approved item selector if customer has multiple items */}
            {approvedRecoveries.length > 1 && (
              <div style={{ marginBottom: '1.5rem' }}>
                <div style={{ fontSize: '0.8125rem', fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '0.5rem' }}>
                  Select Approved Item to Match:
                </div>
                <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap' }}>
                  {approvedRecoveries.map((rec) => {
                    const isCurrent = rec.id === selectedRecovery?.id
                    return (
                      <button
                        key={rec.id}
                        onClick={() => handleSwitchRecovery(rec)}
                        className={`btn ${isCurrent ? 'btn-primary' : 'btn-secondary'} btn-sm`}
                        style={{ display: 'inline-flex', alignItems: 'center', gap: '0.5rem' }}
                      >
                        <Package size={14} />
                        <span>{rec.item?.name || 'Unnamed Item'}</span>
                        <span style={{
                          fontSize: '0.7rem',
                          padding: '0.1rem 0.4rem',
                          borderRadius: 'var(--radius-full)',
                          background: isCurrent ? 'rgba(255,255,255,0.2)' : 'var(--border-light)'
                        }}>
                          {rec.selectedRoute}
                        </span>
                      </button>
                    )
                  })}
                </div>
              </div>
            )}

            {/* Selected item overview card */}
            {selectedRecovery && (
              <div className="card" style={{ marginBottom: '1.5rem' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '1rem' }}>
                  <div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.25rem' }}>
                      <span style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--primary)', background: 'var(--primary-light)', padding: '0.2rem 0.55rem', borderRadius: 'var(--radius-full)' }}>
                        {selectedRecovery.selectedRoute}
                      </span>
                      <span style={{ fontSize: '0.75rem', fontWeight: 600, color: '#15803d', background: '#DCFCE7', padding: '0.2rem 0.55rem', borderRadius: 'var(--radius-full)', display: 'inline-flex', alignItems: 'center', gap: '0.25rem' }}>
                        <ShieldCheck size={12} />
                        Admin Approved
                      </span>
                    </div>
                    <h2 style={{ fontSize: '1.25rem', marginTop: '0.25rem', marginBottom: '0.25rem' }}>
                      {selectedRecovery.item?.name}
                    </h2>
                    <div style={{ fontSize: '0.8125rem', color: 'var(--text-muted)' }}>
                      Category: <strong>{selectedRecovery.item?.category?.name || 'General'}</strong>
                      {selectedRecovery.item?.brand && ` • Brand: ${selectedRecovery.item.brand}`}
                      {selectedRecovery.item?.model && ` • Model: ${selectedRecovery.item.model}`}
                    </div>
                  </div>

                  <div style={{ textAlign: 'right' }}>
                    <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Required Partner Facility</div>
                    <div style={{ fontSize: '0.875rem', fontWeight: 600, color: 'var(--dark)' }}>
                      {selectedRecovery.plan?.requiredPartnerType || 'Certified Facility'}
                    </div>
                  </div>
                </div>
              </div>
            )}

            {/* Partner matching content */}
            {loadingMatches ? (
              <div style={{ padding: '2rem', textAlign: 'center' }}>
                <p style={{ color: 'var(--text-muted)' }}>Loading matching partners...</p>
              </div>
            ) : matches.length === 0 ? (
              <div className="card" style={{ textAlign: 'center', padding: '3.5rem 2rem' }}>
                <Building2 size={36} color="var(--primary)" style={{ margin: '0 auto 1rem' }} />
                <h3 style={{ marginBottom: '0.5rem' }}>No Partner Matches Generated Yet</h3>
                <p style={{ color: 'var(--text-muted)', maxWidth: '480px', margin: '0 auto 1.5rem', fontSize: '0.875rem' }}>
                  Run Agent 3 to evaluate accredited partners matching your item category and selected route ({selectedRecovery?.selectedRoute}).
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
                    Showing <strong>{matches.length}</strong> ranked certified partners
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

                {/* Next Step Banner */}
                {selectedPartnerId && (
                  <div className="card" style={{ background: 'var(--primary-light)', border: '1px solid var(--primary)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '1rem' }}>
                    <div>
                      <h3 style={{ color: 'var(--primary)', fontSize: '1.125rem' }}>Partner Selection Confirmed</h3>
                      <div style={{ fontSize: '0.875rem', color: 'var(--dark)', marginTop: '0.25rem' }}>
                        {existingCollection
                          ? 'A collection pickup request has already been initiated for this item.'
                          : 'Next step: Set your preferred pickup time and have Agent 4 propose the collection schedule.'}
                      </div>
                    </div>
                    {existingCollection ? (
                      <Link to="/collections" className="btn btn-primary">
                        <Truck size={16} />
                        <span>View Collections</span>
                      </Link>
                    ) : (
                      <button
                        onClick={() => navigate(`/recovery/${selectedRecovery.id}/schedule`)}
                        className="btn btn-primary"
                      >
                        <span>Schedule Collection (Agent 4)</span>
                        <ArrowRight size={16} />
                      </button>
                    )}
                  </div>
                )}
              </div>
            )}
          </div>
        )}
      </div>
    </>
  )
}
