import React, { useEffect, useState, useRef } from 'react'
import { useNavigate } from 'react-router'
import { Html5Qrcode } from 'html5-qrcode'
import {
  QrCode,
  Camera,
  X,
  Search,
  AlertCircle,
  CheckCircle2,
  Package,
  MapPin,
  Phone,
  ShieldCheck,
  Check,
  ExternalLink
} from 'lucide-react'
import { apiClient } from '../services/apiClient.js'
import { StatusChip } from './StatusChip.jsx'

export function QrScannerModal({ isOpen, onClose, onJobUpdated, targetJob }) {
  const navigate = useNavigate()
  const [activeTab, setActiveTab] = useState('camera') // 'camera' or 'manual'
  const [manualCode, setManualCode] = useState('')
  const [scannerError, setScannerError] = useState('')
  const [isScanning, setIsScanning] = useState(false)
  const [scannedPass, setScannedPass] = useState(null)
  const [loadingPass, setLoadingPass] = useState(false)
  const [submittingPickup, setSubmittingPickup] = useState(false)
  const [pickupSuccess, setPickupSuccess] = useState('')
  const [agentNotes, setAgentNotes] = useState('')
  const [checklist, setChecklist] = useState({})

  const scannerRef = useRef(null)
  const html5QrCodeRef = useRef(null)

  // Initialize camera scanner when tab is camera and modal is open
  useEffect(() => {
    if (!isOpen || activeTab !== 'camera' || scannedPass) {
      stopCamera()
      return
    }

    let isMounted = true

    const startCamera = async () => {
      try {
        setScannerError('')
        const qrId = 'html5-qr-reader-container'
        const qrElem = document.getElementById(qrId)
        if (!qrElem) return

        if (!html5QrCodeRef.current) {
          html5QrCodeRef.current = new Html5Qrcode(qrId)
        }

        const cameras = await Html5Qrcode.getCameras()
        if (!cameras || cameras.length === 0) {
          setScannerError('No camera found on this device. Please use manual code entry.')
          return
        }

        const cameraId = cameras[cameras.length - 1].id // prefer back camera
        await html5QrCodeRef.current.start(
          cameraId,
          {
            fps: 10,
            qrbox: { width: 220, height: 220 }
          },
          (decodedText) => {
            if (isMounted) {
              handleQrDetected(decodedText)
            }
          },
          () => {}
        )
        if (isMounted) setIsScanning(true)
      } catch (err) {
        if (isMounted) {
          setScannerError(
            err?.name === 'NotAllowedError'
              ? 'Camera permission denied. Please allow camera access or use manual code entry.'
              : 'Unable to start camera. Please use manual code entry.'
          )
        }
      }
    }

    // Small delay to ensure DOM element is ready
    const timer = setTimeout(() => {
      startCamera()
    }, 150)

    return () => {
      isMounted = false
      clearTimeout(timer)
      stopCamera()
    }
  }, [isOpen, activeTab, scannedPass])

  const stopCamera = async () => {
    if (html5QrCodeRef.current && html5QrCodeRef.current.isScanning) {
      try {
        await html5QrCodeRef.current.stop()
      } catch {
        // ignore stop error
      }
    }
    setIsScanning(false)
  }

  const handleClose = () => {
    stopCamera()
    setScannedPass(null)
    setPickupSuccess('')
    setScannerError('')
    setManualCode('')
    onClose()
  }

  // Parse QR text to extract recoveryRequestId
  const extractRecoveryId = (text) => {
    if (!text) return ''
    const trimmed = text.trim()

    // Case 1: Full URL e.g. https://.../verify-handover/2ecabd0b-1133-46cd-8a2b-af9f73db8237
    const urlMatch = trimmed.match(/verify-handover\/([a-f0-9-]{36})/i)
    if (urlMatch && urlMatch[1]) return urlMatch[1]

    // Case 2: Direct GUID
    const guidMatch = trimmed.match(/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i)
    if (guidMatch) return trimmed

    // Case 3: Pass Reference Code e.g. LPW-PASS-2ECABD0B
    return trimmed
  }

  const handleQrDetected = async (rawText) => {
    stopCamera()
    await fetchPassData(rawText)
  }

  const handleManualSearch = async (e) => {
    e?.preventDefault()
    if (!manualCode.trim()) return
    await fetchPassData(manualCode)
  }

  const getChecklistItems = (pass) => {
    if (!pass) return []
    const items = [
      {
        id: 'identity',
        tag: 'Identity & Physical Condition',
        type: 'identity',
        label: `Item Identity Check: Verified ${pass.brand ? pass.brand + ' ' : ''}${pass.model ? pass.model + ' ' : ''}(${pass.itemName}) matches physical item. Reported condition: "${pass.conditionDescription || 'Good'}" verified at doorstep.`
      }
    ]

    if (pass.preparationSteps && pass.preparationSteps.length > 0) {
      pass.preparationSteps.forEach((step, idx) => {
        items.push({
          id: `step_${idx}`,
          tag: 'Agent 2 Preparation Protocol',
          type: 'agent2_prep',
          label: step
        })
      })
    } else {
      items.push({
        id: 'default_prep',
        tag: 'Preparation Protocol',
        type: 'agent2_prep',
        label: 'Device personal accounts signed out and factory reset verified.'
      })
    }

    if (pass.safetyNotes && pass.safetyNotes.length > 0) {
      pass.safetyNotes.forEach((note, idx) => {
        items.push({
          id: `safety_${idx}`,
          tag: 'Agent 2 Safety Precaution',
          type: 'agent2_safety',
          label: note
        })
      })
    }

    return items
  }

  const checklistItems = getChecklistItems(scannedPass)
  const isAllChecked = checklistItems.length > 0 && checklistItems.every((item) => !!checklist[item.id])
  const checkedCount = checklistItems.filter((item) => !!checklist[item.id]).length

  const handleToggleItem = (itemId) => {
    setChecklist((prev) => ({
      ...prev,
      [itemId]: !prev[itemId]
    }))
  }

  const handleCheckAll = () => {
    const next = {}
    checklistItems.forEach((item) => {
      next[item.id] = true
    })
    setChecklist(next)
  }

  const fetchPassData = async (inputCode) => {
    setLoadingPass(true)
    setScannerError('')
    setPickupSuccess('')
    try {
      const extracted = extractRecoveryId(inputCode)
      let recoveryId = extracted
      if (!recoveryId.includes('-') || recoveryId.length !== 36) {
        const cleanCode = inputCode.replace('LPW-PASS-', '').trim()
        recoveryId = cleanCode
      }

      const res = await apiClient.get(`/api/recovery/${recoveryId}/handover-pass`)
      const data = res.data

      if (targetJob && targetJob.recoveryRequestId && data.recoveryRequestId !== targetJob.recoveryRequestId) {
        setScannerError(`Mismatched Pass! This pass is for "${data.itemName}" (${data.customerName}), but your selected job is for "${targetJob.item?.name}". Please scan the pass for the correct order.`)
        setScannedPass(null)
        return
      }

      setScannedPass(data)
      setChecklist({})
      setAgentNotes(`Verified pass ${data.passReferenceCode} on-site. Agent 2 inspection checklist verified and confirmed doorstep pickup.`)
    } catch (err) {
      setScannerError(err.response?.data?.error || 'Handover pass not found. Check the code or scan again.')
    } finally {
      setLoadingPass(false)
    }
  }

  // Confirm Inspection & Mark Picked Up
  const handleConfirmPickup = async () => {
    if (!scannedPass?.collectionRequestId) {
      setScannerError('No active collection schedule found for this item.')
      return
    }

    if (!isAllChecked) {
      setScannerError('You must verify and check off all Agent 2 inspection checklist items before accepting this pickup.')
      return
    }

    try {
      setSubmittingPickup(true)
      setScannerError('')
      await apiClient.post(`/api/agent/collections/${scannedPass.collectionRequestId}/status`, {
        status: 'Collected',
        note: agentNotes || `Pass ${scannedPass.passReferenceCode} verified on-site. All Agent 2 preparation and safety checks completed.`
      })
      setPickupSuccess('Item successfully verified and marked as Picked Up (Collected)!')
      if (onJobUpdated) onJobUpdated()
      // Refresh pass data to reflect new status
      const res = await apiClient.get(`/api/recovery/${scannedPass.recoveryRequestId}/handover-pass`)
      setScannedPass(res.data)
    } catch (err) {
      setScannerError(err.response?.data?.error || 'Failed to update pickup status.')
    } finally {
      setSubmittingPickup(false)
    }
  }

  if (!isOpen) return null

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(15, 23, 42, 0.75)',
        backdropFilter: 'blur(4px)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 1000,
        padding: '1rem'
      }}
      onClick={handleClose}
    >
      <div
        className="card"
        style={{
          maxWidth: scannedPass ? '620px' : '480px',
          width: '100%',
          maxHeight: '90vh',
          overflowY: 'auto',
          padding: '1.5rem',
          background: '#FFFFFF'
        }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Modal Header */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.625rem' }}>
            <div
              style={{
                width: '36px',
                height: '36px',
                borderRadius: 'var(--radius-sm)',
                background: 'var(--primary-light)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: 'var(--primary)'
              }}
            >
              <QrCode size={20} />
            </div>
            <div>
              <h3 style={{ margin: 0, fontSize: '1.125rem', fontWeight: 700 }}>
                {scannedPass ? 'Verified Handover Proof' : 'Verify Customer QR Pass'}
              </h3>
              <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                Doorstep collection inspection &amp; verification
              </div>
            </div>
          </div>
          <button onClick={handleClose} className="btn btn-secondary btn-sm" type="button">
            <X size={16} />
          </button>
        </div>

        {scannerError && (
          <div className="alert alert-error" style={{ marginBottom: '1rem', fontSize: '0.8125rem' }}>
            <AlertCircle size={16} />
            <span>{scannerError}</span>
          </div>
        )}

        {pickupSuccess && (
          <div className="alert alert-success" style={{ marginBottom: '1rem', fontSize: '0.8125rem' }}>
            <CheckCircle2 size={16} />
            <span>{pickupSuccess}</span>
          </div>
        )}

        {/* View 1: When no pass has been scanned yet */}
        {!scannedPass && (
          <div>
            {/* Tabs: Camera Scan vs Manual Code */}
            <div style={{ display: 'flex', borderBottom: '1px solid var(--border-light)', marginBottom: '1rem' }}>
              <button
                type="button"
                onClick={() => setActiveTab('camera')}
                style={{
                  flex: 1,
                  padding: '0.625rem',
                  border: 'none',
                  background: 'none',
                  borderBottom: activeTab === 'camera' ? '2px solid var(--primary)' : '2px solid transparent',
                  fontWeight: activeTab === 'camera' ? 600 : 500,
                  color: activeTab === 'camera' ? 'var(--primary)' : 'var(--text-muted)',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '0.375rem',
                  fontSize: '0.875rem'
                }}
              >
                <Camera size={16} />
                <span>Camera Scanner</span>
              </button>
              <button
                type="button"
                onClick={() => setActiveTab('manual')}
                style={{
                  flex: 1,
                  padding: '0.625rem',
                  border: 'none',
                  background: 'none',
                  borderBottom: activeTab === 'manual' ? '2px solid var(--primary)' : '2px solid transparent',
                  fontWeight: activeTab === 'manual' ? 600 : 500,
                  color: activeTab === 'manual' ? 'var(--primary)' : 'var(--text-muted)',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '0.375rem',
                  fontSize: '0.875rem'
                }}
              >
                <Search size={16} />
                <span>Manual Code Entry</span>
              </button>
            </div>

            {loadingPass ? (
              <div style={{ padding: '2rem', textAlign: 'center' }}>
                <p style={{ color: 'var(--text-muted)' }}>Retrieving manifest proof details...</p>
              </div>
            ) : activeTab === 'camera' ? (
              <div>
                <div
                  id="html5-qr-reader-container"
                  style={{
                    width: '100%',
                    minHeight: '260px',
                    borderRadius: 'var(--radius-md)',
                    overflow: 'hidden',
                    background: '#0F172A'
                  }}
                />
                <p style={{ textAlign: 'center', fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.75rem' }}>
                  Point camera at customer's Digital Handover Pass QR Code
                </p>
              </div>
            ) : (
              <form onSubmit={handleManualSearch}>
                <div className="form-group" style={{ marginBottom: '1rem' }}>
                  <label className="form-label">Enter Pass Reference or Recovery ID</label>
                  <input
                    type="text"
                    className="form-input"
                    placeholder="e.g. 2ecabd0b-1133-46cd-8a2b-af9f73db8237"
                    value={manualCode}
                    onChange={(e) => setManualCode(e.target.value)}
                    autoFocus
                  />
                  <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.25rem', display: 'block' }}>
                    Type or paste the reference code shown on customer's pass
                  </span>
                </div>
                {targetJob && targetJob.recoveryRequestId && (
                  <div style={{ marginBottom: '0.75rem' }}>
                    <button
                      type="button"
                      onClick={() => fetchPassData(targetJob.recoveryRequestId)}
                      className="btn btn-secondary btn-sm"
                      style={{ width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.375rem', fontSize: '0.8125rem' }}
                    >
                      <ShieldCheck size={15} color="var(--primary)" />
                      <span>Verify Expected Pass for {targetJob.customerName || 'Customer'}</span>
                    </button>
                  </div>
                )}

                <button
                  type="submit"
                  disabled={!manualCode.trim()}
                  className="btn btn-primary"
                  style={{ width: '100%' }}
                >
                  <Search size={16} />
                  <span>Verify Manifest</span>
                </button>
              </form>
            )}
          </div>
        )}

        {/* View 2: When Pass is Scanned & Loaded */}
        {scannedPass && (
          <div>
            {/* Header Badge */}
            <div
              style={{
                background: '#F0FDF4',
                border: '1px solid #86EFAC',
                borderRadius: 'var(--radius-sm)',
                padding: '0.75rem 1rem',
                marginBottom: '1rem',
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center'
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', color: '#15803d', fontWeight: 600, fontSize: '0.875rem' }}>
                <ShieldCheck size={18} />
                <span>Verified Handover Pass</span>
              </div>
              <span style={{ fontFamily: 'monospace', fontWeight: 700, fontSize: '0.8125rem', color: 'var(--primary)' }}>
                {scannedPass.passReferenceCode}
              </span>
            </div>

            {/* Item details card */}
            <div style={{ background: '#F8FAFC', padding: '0.875rem', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-light)', marginBottom: '1rem', fontSize: '0.8125rem' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '0.5rem' }}>
                <div>
                  <h4 style={{ margin: 0, fontSize: '1.05rem', color: 'var(--dark)' }}>{scannedPass.itemName}</h4>
                  <div style={{ color: 'var(--text-muted)', fontSize: '0.75rem', marginTop: '0.15rem' }}>
                    {scannedPass.brand} {scannedPass.model} • {scannedPass.categoryName}
                  </div>
                </div>
                <StatusChip status={scannedPass.selectedRoute} type="route" />
              </div>

              <div style={{ marginTop: '0.5rem', paddingTop: '0.5rem', borderTop: '1px solid var(--border-light)' }}>
                <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)', textTransform: 'uppercase' }}>Reported Condition:</div>
                <div style={{ color: 'var(--text-main)', marginTop: '0.15rem', lineHeight: 1.4 }}>
                  {scannedPass.conditionDescription || 'Good'}
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.5rem', marginTop: '0.5rem', paddingTop: '0.5rem', borderTop: '1px solid var(--border-light)' }}>
                <div>
                  <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)' }}>CUSTOMER</div>
                  <div style={{ fontWeight: 600 }}>{scannedPass.customerName}</div>
                  {scannedPass.customerPhone && (
                    <a href={`tel:${scannedPass.customerPhone}`} style={{ color: 'var(--primary)', textDecoration: 'none', display: 'flex', alignItems: 'center', gap: '0.25rem', marginTop: '0.15rem' }}>
                      <Phone size={12} />
                      <span>{scannedPass.customerPhone}</span>
                    </a>
                  )}
                </div>
                <div>
                  <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)' }}>TARGET PARTNER</div>
                  <div style={{ fontWeight: 600 }}>{scannedPass.partnerName || 'Certified Partner'}</div>
                  <div style={{ color: 'var(--text-muted)', fontSize: '0.75rem' }}>
                    Status: <StatusChip status={scannedPass.collectionStatus || 'Scheduled'} />
                  </div>
                </div>
              </div>
            </div>

            {/* Agent 2 Preparation & Safety Inspection Checklist */}
            <div style={{ background: '#FFFFFF', border: '1px solid var(--border)', borderRadius: 'var(--radius-sm)', padding: '1rem', marginBottom: '1rem' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem', flexWrap: 'wrap', gap: '0.5rem' }}>
                <div>
                  <div style={{ fontWeight: 700, fontSize: '0.875rem', color: 'var(--dark)', display: 'flex', alignItems: 'center', gap: '0.375rem' }}>
                    <CheckCircle2 size={16} color="var(--primary)" />
                    <span>Agent 2 On-Site Inspection Checklist</span>
                  </div>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.125rem' }}>
                    Physically verify and tick all Agent 2 items before accepting pickup
                  </div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <button
                    type="button"
                    onClick={handleCheckAll}
                    className="btn btn-secondary btn-sm"
                    style={{ fontSize: '0.75rem', padding: '0.2rem 0.5rem' }}
                    title="Mark all items verified"
                  >
                    Check All
                  </button>
                  <span className={`status-chip ${isAllChecked ? 'status-approved' : 'status-revision'}`} style={{ fontSize: '0.75rem' }}>
                    {checkedCount} / {checklistItems.length} Verified
                  </span>
                </div>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                {checklistItems.map((item) => {
                  const checked = !!checklist[item.id]
                  return (
                    <label
                      key={item.id}
                      style={{
                        display: 'flex',
                        alignItems: 'flex-start',
                        gap: '0.625rem',
                        padding: '0.5rem 0.625rem',
                        borderRadius: 'var(--radius-sm)',
                        background: checked ? 'rgba(16, 185, 129, 0.06)' : 'var(--surface-subtle)',
                        border: `1px solid ${checked ? '#86EFAC' : 'var(--border-light)'}`,
                        cursor: 'pointer',
                        transition: 'all 0.15s ease'
                      }}
                    >
                      <input
                        type="checkbox"
                        checked={checked}
                        onChange={() => handleToggleItem(item.id)}
                        style={{ marginTop: '0.15rem', accentColor: 'var(--primary)', cursor: 'pointer' }}
                      />
                      <div style={{ flex: 1, fontSize: '0.8125rem', lineHeight: 1.4 }}>
                        <span style={{
                          fontSize: '0.7rem',
                          fontWeight: 700,
                          color: item.type === 'identity' ? 'var(--dark)' : item.type === 'agent2_safety' ? '#DC2626' : 'var(--primary)',
                          textTransform: 'uppercase',
                          display: 'block',
                          marginBottom: '0.15rem'
                        }}>
                          {item.tag}
                        </span>
                        <span style={{ color: checked ? 'var(--dark)' : 'var(--text-main)', fontWeight: checked ? 500 : 400 }}>
                          {item.label}
                        </span>
                      </div>
                    </label>
                  )
                })}
              </div>

              {!isAllChecked && (
                <div style={{ marginTop: '0.75rem', fontSize: '0.75rem', color: '#D97706', display: 'flex', alignItems: 'center', gap: '0.375rem' }}>
                  <AlertCircle size={14} />
                  <span>Please physically check off all {checklistItems.length} items to unlock pickup confirmation.</span>
                </div>
              )}

              {isAllChecked && (
                <div style={{ marginTop: '0.75rem', fontSize: '0.75rem', color: '#16A34A', display: 'flex', alignItems: 'center', gap: '0.375rem', fontWeight: 600 }}>
                  <CheckCircle2 size={14} />
                  <span>All Agent 2 preparation and safety criteria verified! You may now accept the pickup.</span>
                </div>
              )}
            </div>

            {/* Action buttons */}
            {scannedPass.collectionStatus === 'Collected' || scannedPass.collectionStatus === 'Completed' ? (
              <div style={{ textAlign: 'center', padding: '0.75rem', color: '#166534', fontWeight: 600, fontSize: '0.875rem', background: '#F0FDF4', borderRadius: 'var(--radius-sm)', border: '1px solid #BBF7D0' }}>
                <CheckCircle2 size={20} style={{ margin: '0 auto 0.25rem', display: 'block' }} />
                Item is already marked as {scannedPass.collectionStatus}.
              </div>
            ) : (
              <div>
                <div className="form-group" style={{ marginBottom: '1rem' }}>
                  <label className="form-label" style={{ fontSize: '0.75rem' }}>Field Handover Notes</label>
                  <input
                    type="text"
                    className="form-input"
                    value={agentNotes}
                    onChange={(e) => setAgentNotes(e.target.value)}
                    placeholder="e.g. Inspected at doorstep, verified screen & serial..."
                  />
                </div>

                <button
                  onClick={handleConfirmPickup}
                  disabled={!isAllChecked || submittingPickup}
                  className="btn btn-primary"
                  style={{
                    width: '100%',
                    padding: '0.75rem',
                    fontSize: '0.9375rem',
                    opacity: isAllChecked ? 1 : 0.5,
                    cursor: isAllChecked ? 'pointer' : 'not-allowed'
                  }}
                  title={!isAllChecked ? "Check off all Agent 2 checklist items above to accept pickup" : "Confirm and accept doorstep pickup"}
                >
                  <Check size={18} />
                  <span>{submittingPickup ? 'Updating...' : isAllChecked ? 'Confirm Inspection & Accept Pickup (Collected)' : `Verify All Items to Accept Pickup (${checkedCount}/${checklistItems.length})`}</span>
                </button>
              </div>
            )}

            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: '1rem', borderTop: '1px solid var(--border-light)', paddingTop: '0.75rem' }}>
              <button
                onClick={() => {
                  setScannedPass(null)
                  setPickupSuccess('')
                }}
                className="btn btn-secondary btn-sm"
              >
                Scan Another Pass
              </button>
              <button
                onClick={() => {
                  handleClose()
                  navigate(`/verify-handover/${scannedPass.recoveryRequestId}`)
                }}
                className="btn btn-secondary btn-sm"
                style={{ display: 'inline-flex', alignItems: 'center', gap: '0.25rem' }}
              >
                <span>Full Manifest Page</span>
                <ExternalLink size={13} />
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
