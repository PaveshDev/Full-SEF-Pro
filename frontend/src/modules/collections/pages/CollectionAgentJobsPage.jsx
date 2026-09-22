import React, { useEffect, useState } from 'react'
import { Truck, CheckCircle2, AlertCircle, Calendar, Clock, MapPin, Package, ArrowRight, X, AlertTriangle, Phone, User, QrCode, ShieldCheck } from 'lucide-react'
import { apiClient } from '../../../shared/services/apiClient.js'
import { StatusChip } from '../../../shared/components/StatusChip.jsx'
import { TopBar } from '../../../shared/components/TopBar.jsx'
import { QrScannerModal } from '../../../shared/components/QrScannerModal.jsx'

export function CollectionAgentJobsPage() {
  const [jobs, setJobs] = useState([])
  const [selectedJob, setSelectedJob] = useState(null)
  const [targetJobForScan, setTargetJobForScan] = useState(null)
  const [rejectingId, setRejectingId] = useState(null)
  const [rejectReason, setRejectReason] = useState('')
  const [statusUpdate, setStatusUpdate] = useState('')
  const [note, setNote] = useState('')
  const [showScanner, setShowScanner] = useState(false)
  const [loading, setLoading] = useState(true)
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  useEffect(() => {
    loadJobs()
  }, [])

  const loadJobs = async () => {
    try {
      setLoading(true)
      const res = await apiClient.get('/api/agent/collections')
      setJobs(res.data)
    } catch {
      setError('Failed to load assigned jobs.')
    } finally {
      setLoading(false)
    }
  }

  const handleAcceptJob = async (id) => {
    try {
      setSubmitting(true)
      setError('')
      setSuccess('')
      await apiClient.post(`/api/agent/collections/${id}/accept`)
      setSuccess('Job accepted! Pickup is now scheduled. Duty status updated to Busy.')
      await loadJobs()
      if (selectedJob && selectedJob.id === id) {
        setSelectedJob(null)
      }
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to accept job.')
    } finally {
      setSubmitting(false)
    }
  }

  const handleRejectJob = async (id) => {
    try {
      setSubmitting(true)
      setError('')
      setSuccess('')
      await apiClient.post(`/api/agent/collections/${id}/reject`, {
        reason: rejectReason || 'Schedule conflict'
      })
      setSuccess('Job declined. Request returned to Admin queue for AI re-dispatch.')
      setRejectingId(null)
      setRejectReason('')
      await loadJobs()
      if (selectedJob && selectedJob.id === id) {
        setSelectedJob(null)
      }
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to decline job.')
    } finally {
      setSubmitting(false)
    }
  }

  const handleUpdateStatus = async () => {
    if (!statusUpdate) return
    setSubmitting(true)
    setError('')
    try {
      await apiClient.post(`/api/agent/collections/${selectedJob.id}/status`, {
        status: statusUpdate,
        note: note || null
      })
      if (statusUpdate === 'DeliveredToPartner' || statusUpdate === 'Completed') {
        setSuccess('Item successfully delivered to partner! Collection completed and duty status updated to Available.')
      } else {
        setSuccess(`Job marked as ${statusUpdate}.`)
      }
      setSelectedJob(null)
      setStatusUpdate('')
      setNote('')
      await loadJobs()
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to update job status.')
    } finally {
      setSubmitting(false)
    }
  }

  const activeJobs = jobs.filter(j => j.status === 'Scheduled' || j.status === 'Collected')
  const isBusy = activeJobs.length > 0

  return (
    <>
      <TopBar
        title="Assigned Pickups"
        action={
          <button
            onClick={() => setShowScanner(true)}
            className="btn btn-primary btn-sm"
            style={{ display: 'inline-flex', alignItems: 'center', gap: '0.375rem' }}
            title="Scan or Verify Customer QR Pass"
            type="button"
          >
            <QrCode size={15} />
            <span>Scan / Verify QR Pass</span>
          </button>
        }
      />

      <div className="content-container">
        <div className="page-header">
          <div className="page-title-group">
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', flexWrap: 'wrap' }}>
              <h1>My Collection Route & Jobs</h1>
              <span className={`status-chip ${isBusy ? 'status-revision' : 'status-approved'}`} style={{ fontSize: '0.75rem', padding: '0.2rem 0.5rem' }}>
                {isBusy ? `Busy (${activeJobs.length} active pickup in progress)` : 'Duty Status: Available'}
              </span>
            </div>
            <div className="page-subtitle">Confirm assigned orders, collect e-waste from customers, and hand over to designated partners</div>
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
            <p style={{ color: 'var(--text-muted)' }}>Loading assigned jobs...</p>
          </div>
        ) : jobs.length === 0 ? (
          <div className="card" style={{ textAlign: 'center', padding: '3.5rem 2rem' }}>
            <Truck size={36} color="var(--primary)" style={{ margin: '0 auto 1rem' }} />
            <h3>No jobs assigned yet</h3>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem', marginTop: '0.25rem' }}>
              When administrators dispatch pickups to your profile, they will appear here.
            </p>
          </div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: selectedJob || rejectingId ? '1.1fr 0.9fr' : '1fr', gap: '1.5rem', alignItems: 'start' }}>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              {jobs.map((job) => (
                <div
                  key={job.id}
                  className="card"
                  style={{
                    background: selectedJob?.id === job.id ? 'var(--primary-light)' : undefined,
                    borderColor: selectedJob?.id === job.id ? 'var(--primary)' : undefined
                  }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '0.75rem' }}>
                    <div>
                      <h3 style={{ fontSize: '1.125rem' }}>{job.item?.name}</h3>
                      <div style={{ fontSize: '0.8125rem', color: 'var(--text-muted)', marginTop: '0.125rem' }}>
                        Category: {job.item?.category?.name} • Target Partner: <strong>{job.partnerName}</strong>
                      </div>
                    </div>
                    <StatusChip status={job.status} />
                  </div>

                  <div style={{ display: 'flex', gap: '1.5rem', fontSize: '0.8125rem', color: 'var(--text-muted)', marginBottom: '0.75rem' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.375rem' }}>
                      <Calendar size={15} color="var(--primary)" />
                      <span>{job.scheduledPickupDate ? new Date(job.scheduledPickupDate).toLocaleDateString() : 'Unscheduled'}</span>
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.375rem' }}>
                      <Clock size={15} color="var(--primary)" />
                      <span>{job.scheduledStartTime?.slice(0, 5)} - {job.scheduledEndTime?.slice(0, 5)}</span>
                    </div>
                  </div>

                  {/* Customer Pickup Location & Contact details for Agent */}
                  <div style={{ background: 'var(--surface-subtle)', padding: '0.625rem 0.875rem', borderRadius: 'var(--radius-sm)', marginBottom: '0.75rem', fontSize: '0.8125rem' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.25rem' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.375rem', fontWeight: 600 }}>
                        <User size={14} color="var(--primary)" />
                        <span>{job.customerName || 'Customer'}</span>
                      </div>
                      {job.customerPhone && (
                        <a href={`tel:${job.customerPhone}`} style={{ display: 'flex', alignItems: 'center', gap: '0.25rem', color: 'var(--primary)', fontWeight: 600, textDecoration: 'none' }}>
                          <Phone size={13} />
                          <span>{job.customerPhone}</span>
                        </a>
                      )}
                    </div>
                    <div style={{ display: 'flex', alignItems: 'flex-start', gap: '0.375rem', color: 'var(--text-main)', marginTop: '0.25rem' }}>
                      <MapPin size={14} color="var(--primary)" style={{ flexShrink: 0, marginTop: '0.125rem' }} />
                      <span>
                        {job.customerAddress ? `${job.customerAddress}, ${job.customerTown || ''}, ${job.customerDistrict || ''}` : (job.customerTown || 'Address not specified')}
                      </span>
                    </div>
                  </div>

                  {job.status === 'AgentAssigned' && (
                    <div style={{
                      background: isBusy ? 'rgba(239, 68, 68, 0.08)' : '#FFFBEB',
                      border: `1px solid ${isBusy ? 'rgba(239, 68, 68, 0.3)' : '#FDE68A'}`,
                      padding: '0.625rem 0.875rem',
                      borderRadius: 'var(--radius-sm)',
                      marginBottom: '0.75rem',
                      fontSize: '0.8125rem',
                      color: isBusy ? 'var(--error)' : '#92400E'
                    }}>
                      {isBusy ? (
                        <>
                          <strong>Pickup In Progress:</strong> You have an active pickup in progress. You cannot accept this order until you complete and hand over your current accepted job, or decline so another agent can be assigned.
                        </>
                      ) : (
                        <>
                          <strong>New Order Assigned:</strong> Please confirm if you can take this job or decline so another agent can be assigned.
                        </>
                      )}
                    </div>
                  )}

                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderTop: '1px solid var(--border-light)', paddingTop: '0.75rem' }}>
                    <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                      Route: <StatusChip status={job.item?.selectedRecoveryRoute} type="route" />
                    </div>
                    <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
                      {job.status === 'AgentAssigned' && (
                        <>
                          <button
                            onClick={() => handleAcceptJob(job.id)}
                            disabled={submitting || isBusy}
                            className="btn btn-primary btn-sm"
                            style={isBusy ? { opacity: 0.5, cursor: 'not-allowed' } : undefined}
                            title={isBusy ? "Complete your current accepted pickup before accepting another job" : "Confirm and accept this collection job"}
                          >
                            <CheckCircle2 size={14} />
                            <span>Accept Job</span>
                          </button>
                          <button
                            onClick={() => { setRejectingId(job.id); setSelectedJob(null); }}
                            disabled={submitting}
                            className="btn btn-secondary btn-sm"
                            style={{ color: 'var(--error)' }}
                            title="Decline order so AI can reassign"
                          >
                            <X size={14} />
                            <span>Decline</span>
                          </button>
                        </>
                      )}
                      {job.status === 'Scheduled' && (
                        <button
                          onClick={() => { setSelectedJob(job); setRejectingId(null); setStatusUpdate('Collected'); setNote('Item collected from customer.'); }}
                          className="btn btn-primary btn-sm"
                        >
                          <Package size={14} />
                          <span>Mark Picked Up</span>
                        </button>
                      )}
                      {job.status === 'Collected' && (
                        <button
                          onClick={() => { setSelectedJob(job); setRejectingId(null); setStatusUpdate('DeliveredToPartner'); setNote(`Handed over item to ${job.partnerName}.`); }}
                          className="btn btn-primary btn-sm"
                        >
                          <Truck size={14} />
                          <span>Hand Over to Partner</span>
                        </button>
                      )}
                      {job.status !== 'AgentAssigned' && job.status !== 'Completed' && (
                        <button
                          onClick={() => { 
                            setSelectedJob(job); 
                            setRejectingId(null);
                            setStatusUpdate(job.status === 'Collected' ? 'DeliveredToPartner' : 'Collected'); 
                            setNote(''); 
                          }}
                          className="btn btn-secondary btn-sm"
                        >
                          <span>Details</span>
                          <ArrowRight size={14} />
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              ))}
            </div>

            {/* Decline Dialog */}
            {rejectingId && (
              <div className="card" style={{ border: '1px solid #FCA5A5', background: '#FFFDFD' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '1rem' }}>
                  <div>
                    <h3 style={{ color: 'var(--error)', fontSize: '1.125rem' }}>Decline Collection Order</h3>
                    <div style={{ fontSize: '0.8125rem', color: 'var(--text-muted)' }}>
                      The order will be returned to the Administrator queue with your reason for AI re-dispatch.
                    </div>
                  </div>
                  <button onClick={() => setRejectingId(null)} className="btn btn-secondary btn-sm">
                    <X size={14} />
                  </button>
                </div>

                <div className="form-group">
                  <label className="form-label">Reason for Declining (Optional)</label>
                  <textarea
                    rows={2}
                    className="form-textarea"
                    placeholder="e.g. Current workload, outside operational radius, vehicle maintenance..."
                    value={rejectReason}
                    onChange={(e) => setRejectReason(e.target.value)}
                  />
                </div>

                <div style={{ display: 'flex', gap: '0.5rem', justifyContent: 'flex-end', marginTop: '1rem' }}>
                  <button
                    onClick={() => setRejectingId(null)}
                    className="btn btn-secondary"
                    disabled={submitting}
                  >
                    Cancel
                  </button>
                  <button
                    onClick={() => handleRejectJob(rejectingId)}
                    disabled={submitting}
                    className="btn btn-secondary"
                    style={{ background: '#FEE2E2', color: '#B91C1C', borderColor: '#FCA5A5' }}
                  >
                    <span>{submitting ? 'Declining...' : 'Confirm Decline & Reassign'}</span>
                  </button>
                </div>
              </div>
            )}

            {/* Sidebar for Job Details and Milestone Updates */}
            {selectedJob && (
              <div className="card" style={{ position: 'sticky', top: '1rem' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
                  <h3 style={{ margin: 0, fontSize: '1.05rem' }}>Collection Milestone</h3>
                  <button onClick={() => setSelectedJob(null)} className="btn btn-secondary btn-sm">
                    <X size={14} />
                  </button>
                </div>

                <div style={{ background: 'var(--surface-subtle)', padding: '0.75rem', borderRadius: 'var(--radius-sm)', marginBottom: '1rem', fontSize: '0.8125rem' }}>
                  <div style={{ fontWeight: 600, fontSize: '0.9375rem', marginBottom: '0.25rem' }}>{selectedJob.item?.name}</div>
                  <div style={{ color: 'var(--text-muted)' }}>Status: <StatusChip status={selectedJob.status} /></div>
                  <div style={{ borderTop: '1px solid var(--border-light)', paddingTop: '0.5rem', marginTop: '0.5rem' }}>
                    <div><strong>Customer:</strong> {selectedJob.customerName}</div>
                    {selectedJob.customerPhone && <div><strong>Phone:</strong> {selectedJob.customerPhone}</div>}
                    <div>
                      <strong>Address:</strong>{' '}
                      <span>
                        {selectedJob.customerAddress ? `${selectedJob.customerAddress}, ${selectedJob.customerTown || ''} (${selectedJob.customerDistrict || ''})` : (selectedJob.customerTown || 'Address not specified')}
                      </span>
                    </div>
                  </div>
                  <div><strong>Customer Condition:</strong> {selectedJob.item?.conditionDescription}</div>
                  <div style={{ marginTop: '0.25rem' }}><strong>Target Partner for Handover:</strong> <strong>{selectedJob.partnerName}</strong></div>
                </div>

                {selectedJob.status === 'Scheduled' ? (
                  <div style={{ background: '#F8FAFC', border: '1px solid var(--border-light)', borderRadius: 'var(--radius-sm)', padding: '0.875rem', marginBottom: '1rem' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', color: 'var(--primary)', fontWeight: 600, fontSize: '0.875rem', marginBottom: '0.35rem' }}>
                      <ShieldCheck size={18} />
                      <span>Doorstep Handover Verification Required</span>
                    </div>
                    <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', lineHeight: 1.4, margin: '0 0 0.75rem 0' }}>
                      To mark this item as Picked Up (Collected), you must verify the customer's Digital Handover Pass QR code and tick off Agent 2's device preparation items.
                    </p>
                    <button
                      type="button"
                      onClick={() => {
                        setTargetJobForScan(selectedJob)
                        setShowScanner(true)
                      }}
                      className="btn btn-primary btn-sm"
                      style={{ width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.375rem', padding: '0.625rem' }}
                    >
                      <QrCode size={15} />
                      <span>Verify Pass &amp; Complete Agent 2 Checklist</span>
                    </button>
                  </div>
                ) : (
                  <>
                    <div className="form-group">
                      <label className="form-label">Next Milestone Action</label>
                      <button
                        type="button"
                        onClick={() => {
                          setStatusUpdate('DeliveredToPartner')
                          if (!note) setNote(`Handed over item to ${selectedJob.partnerName}.`)
                        }}
                        className={`btn ${statusUpdate === 'DeliveredToPartner' ? 'btn-primary' : 'btn-secondary'}`}
                        style={{ width: '100%', justifyContent: 'flex-start', textAlign: 'left' }}
                      >
                        <Truck size={16} />
                        <div>
                          <div style={{ fontWeight: 600 }}>Deliver &amp; Hand Over to Partner (Complete)</div>
                          <div style={{ fontSize: '0.75rem', opacity: 0.85 }}>Marks delivery to {selectedJob.partnerName} and finishes pickup route</div>
                        </div>
                      </button>
                    </div>

                    <div className="form-group">
                      <label className="form-label">Field Notes / Observations</label>
                      <textarea
                        rows={2}
                        className="form-textarea"
                        placeholder="e.g. Item handed over to partner representative..."
                        value={note}
                        onChange={(e) => setNote(e.target.value)}
                      />
                    </div>

                    <button
                      onClick={handleUpdateStatus}
                      disabled={!statusUpdate || submitting}
                      className="btn btn-primary"
                      style={{ width: '100%' }}
                    >
                      <span>{submitting ? 'Updating...' : 'Confirm Delivery to Partner'}</span>
                    </button>
                  </>
                )}
              </div>
            )}
          </div>
        )}
      </div>

      <QrScannerModal
        isOpen={showScanner}
        onClose={() => {
          setShowScanner(false)
          setTargetJobForScan(null)
        }}
        targetJob={targetJobForScan}
        onJobUpdated={loadJobs}
      />
    </>
  )
}
