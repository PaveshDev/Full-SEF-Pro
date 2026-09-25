import React, { useEffect, useState } from 'react'
import QRCode from 'qrcode'
import {
  QrCode,
  ShieldCheck,
  CheckCircle2,
  Printer,
  Maximize2,
  Copy,
  Check,
  Package,
  MapPin,
  Calendar,
  AlertTriangle,
  X
} from 'lucide-react'

export function HandoverPassCard({ recovery }) {
  const [qrSvg, setQrSvg] = useState('')
  const [qrDataUrl, setQrDataUrl] = useState('')
  const [copied, setCopied] = useState(false)
  const [showFullscreen, setShowFullscreen] = useState(false)
  const [checkedSteps, setCheckedSteps] = useState({})

  const passCode = `LPW-PASS-${(recovery?.id || '').slice(0, 8).toUpperCase()}`
  const verificationUrl = typeof window !== 'undefined'
    ? `${window.location.origin}/verify-handover/${recovery?.id}`
    : `/verify-handover/${recovery?.id}`

  useEffect(() => {
    if (!recovery?.id) return

    // Generate SVG QR Code
    QRCode.toString(verificationUrl, {
      type: 'svg',
      margin: 1,
      color: {
        dark: '#0F172A',
        light: '#FFFFFF'
      }
    })
      .then((svg) => setQrSvg(svg))
      .catch((err) => console.error('Failed to generate SVG QR:', err))

    // Generate DataURL for image/modal
    QRCode.toDataURL(verificationUrl, {
      margin: 2,
      width: 400,
      color: {
        dark: '#0F172A',
        light: '#FFFFFF'
      }
    })
      .then((url) => setQrDataUrl(url))
      .catch((err) => console.error('Failed to generate DataURL QR:', err))
  }, [recovery?.id, verificationUrl])

  const handleCopyCode = () => {
    navigator.clipboard?.writeText(passCode)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  const handlePrint = () => {
    window.print()
  }

  const toggleCheck = (idx) => {
    setCheckedSteps((prev) => ({ ...prev, [idx]: !prev[idx] }))
  }

  const steps = recovery?.plan?.steps || [
    { stepText: 'Back up all personal data and perform a factory reset.', sortOrder: 1 },
    { stepText: 'Remove SIM cards and external memory storage.', sortOrder: 2 },
    { stepText: 'Clean exterior surfaces and inspect battery condition.', sortOrder: 3 },
    { stepText: 'Package securely in a protective box or padded sleeve.', sortOrder: 4 }
  ]

  const totalSteps = steps.length
  const completedCount = steps.filter((_, idx) => checkedSteps[idx]).length
  const isAllChecked = totalSteps > 0 && completedCount === totalSteps

  return (
    <>
      <div
        className="card"
        style={{
          background: 'linear-gradient(180deg, #FFFFFF 0%, #F8FAFC 100%)',
          border: '2px solid var(--primary)',
          borderRadius: 'var(--radius-lg)',
          boxShadow: '0 8px 24px -6px rgba(15, 76, 129, 0.08)',
          marginBottom: '1.75rem',
          position: 'relative',
          overflow: 'hidden'
        }}
      >
        {/* Top security accent stripe */}
        <div
          style={{
            position: 'absolute',
            top: 0,
            left: 0,
            right: 0,
            height: '4px',
            background: 'linear-gradient(90deg, var(--primary) 0%, #10B981 50%, var(--primary) 100%)'
          }}
        />

        {/* Card Header */}
        <div
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'flex-start',
            borderBottom: '1px solid var(--border-light)',
            paddingBottom: '1rem',
            marginBottom: '1.25rem',
            flexWrap: 'wrap',
            gap: '0.75rem'
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
            <div
              style={{
                width: '42px',
                height: '42px',
                borderRadius: 'var(--radius-md)',
                background: 'var(--primary-light)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: 'var(--primary)'
              }}
            >
              <QrCode size={24} />
            </div>
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <h3 style={{ margin: 0, fontSize: '1.125rem', fontWeight: 700, color: 'var(--dark)' }}>
                  Digital Item Handover Pass
                </h3>
                <span
                  style={{
                    fontSize: '0.7rem',
                    fontWeight: 600,
                    color: '#065F46',
                    background: '#D1FAE5',
                    padding: '0.15rem 0.5rem',
                    borderRadius: 'var(--radius-full)',
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '0.25rem'
                  }}
                >
                  <ShieldCheck size={12} />
                  Admin Verified
                </span>
                {recovery?.plan?.isPreparationVerified && (
                  <span
                    style={{
                      fontSize: '0.7rem',
                      fontWeight: 600,
                      color: '#1E40AF',
                      background: '#DBEAFE',
                      padding: '0.15rem 0.5rem',
                      borderRadius: 'var(--radius-full)',
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: '0.25rem'
                    }}
                  >
                    <CheckCircle2 size={12} />
                    Prep Verified
                  </span>
                )}
              </div>
              <div style={{ fontSize: '0.8125rem', color: 'var(--text-muted)', marginTop: '0.15rem' }}>
                Present this QR pass to the LoopWorth collection agent at doorstep collection
              </div>
            </div>
          </div>

          {/* Action buttons */}
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            <button
              onClick={() => setShowFullscreen(true)}
              className="btn btn-secondary btn-sm"
              title="Show Large QR Code"
              type="button"
            >
              <Maximize2 size={14} />
              <span>Large QR</span>
            </button>
            <button
              onClick={handlePrint}
              className="btn btn-secondary btn-sm"
              title="Print Official Handover Slip"
              type="button"
            >
              <Printer size={14} />
              <span>Print</span>
            </button>
          </div>
        </div>

        {/* Pass Body (Grid layout: Left details & checklist, Right QR Code) */}
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
            gap: '1.5rem',
            alignItems: 'start'
          }}
        >
          {/* Left Column: Item Manifest & Checklist */}
          <div>
            <div
              style={{
                background: '#FFFFFF',
                borderRadius: 'var(--radius-md)',
                border: '1px solid var(--border-light)',
                padding: '1rem',
                marginBottom: '1rem'
              }}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.5rem' }}>
                <span style={{ fontSize: '0.75rem', fontWeight: 600, color: 'var(--text-muted)' }}>
                  PASS REFERENCE
                </span>
                <button
                  onClick={handleCopyCode}
                  style={{
                    background: 'none',
                    border: 'none',
                    cursor: 'pointer',
                    color: 'var(--primary)',
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '0.25rem',
                    fontSize: '0.75rem',
                    fontWeight: 600
                  }}
                  type="button"
                >
                  {copied ? <Check size={13} color="#10B981" /> : <Copy size={13} />}
                  <span>{copied ? 'Copied' : 'Copy Code'}</span>
                </button>
              </div>
              <div
                style={{
                  fontFamily: 'monospace',
                  fontSize: '1.125rem',
                  fontWeight: 700,
                  letterSpacing: '0.05em',
                  color: 'var(--primary)'
                }}
              >
                {passCode}
              </div>

              <div
                style={{
                  display: 'grid',
                  gridTemplateColumns: '1fr 1fr',
                  gap: '0.75rem',
                  marginTop: '0.75rem',
                  paddingTop: '0.75rem',
                  borderTop: '1px solid var(--border-light)',
                  fontSize: '0.8125rem'
                }}
              >
                <div>
                  <div style={{ color: 'var(--text-muted)', fontSize: '0.7rem' }}>ITEM DETAILS</div>
                  <div style={{ fontWeight: 600, color: 'var(--dark)' }}>{recovery?.item?.name}</div>
                  <div style={{ color: 'var(--text-muted)', fontSize: '0.75rem' }}>
                    {recovery?.item?.brand || ''} {recovery?.item?.model || ''}
                  </div>
                </div>
                <div>
                  <div style={{ color: 'var(--text-muted)', fontSize: '0.7rem' }}>SELECTED ROUTE</div>
                  <div style={{ fontWeight: 700, color: 'var(--primary)' }}>
                    {recovery?.selectedRoute || 'Recycle'}
                  </div>
                  <div style={{ color: 'var(--text-muted)', fontSize: '0.75rem' }}>
                    {recovery?.plan?.requiredPartnerType || 'Certified Facility'}
                  </div>
                </div>
              </div>

              {/* Feature 5: Admin Custom Handling Directives */}
              {(recovery?.plan?.adminHandlingInstructions || recovery?.approval?.decisionNotes) && (
                <div
                  style={{
                    marginTop: '0.75rem',
                    background: '#FFFBEB',
                    border: '1px solid #FDE68A',
                    borderRadius: '6px',
                    padding: '0.5rem 0.75rem',
                    display: 'flex',
                    gap: '0.5rem',
                    alignItems: 'flex-start'
                  }}
                >
                  <AlertTriangle size={15} color="#D97706" style={{ flexShrink: 0, marginTop: '2px' }} />
                  <div>
                    <div style={{ fontSize: '0.7rem', fontWeight: 700, color: '#B45309', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                      Special Courier / Handling Directives
                    </div>
                    <div style={{ fontSize: '0.75rem', color: '#92400E', marginTop: '2px', lineHeight: 1.4 }}>
                      {recovery?.plan?.adminHandlingInstructions || recovery?.approval?.decisionNotes}
                    </div>
                  </div>
                </div>
              )}
            </div>

            {/* Preparation Readiness Checklist */}
            <div
              style={{
                background: isAllChecked ? '#F0FDF4' : '#F8FAFC',
                border: `1px solid ${isAllChecked ? '#BBF7D0' : 'var(--border-light)'}`,
                borderRadius: 'var(--radius-md)',
                padding: '0.875rem'
              }}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.5rem' }}>
                <span style={{ fontSize: '0.75rem', fontWeight: 700, color: isAllChecked ? '#166534' : 'var(--text-main)' }}>
                  PRE-COLLECTION READINESS CHECKLIST
                </span>
                <span
                  style={{
                    fontSize: '0.75rem',
                    fontWeight: 600,
                    color: isAllChecked ? '#166534' : 'var(--text-muted)'
                  }}
                >
                  {completedCount}/{totalSteps} Ready
                </span>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.4rem' }}>
                {steps.map((st, idx) => (
                  <label
                    key={idx}
                    style={{
                      display: 'flex',
                      alignItems: 'flex-start',
                      gap: '0.5rem',
                      cursor: 'pointer',
                      fontSize: '0.8125rem',
                      color: checkedSteps[idx] ? 'var(--dark)' : 'var(--text-main)',
                      textDecoration: checkedSteps[idx] ? 'none' : 'none'
                    }}
                  >
                    <input
                      type="checkbox"
                      checked={Boolean(checkedSteps[idx])}
                      onChange={() => toggleCheck(idx)}
                      style={{ marginTop: '0.2rem', accentColor: 'var(--primary)' }}
                    />
                    <span>{st.stepText}</span>
                  </label>
                ))}
              </div>
            </div>
          </div>

          {/* Right Column: Scannable QR Code */}
          <div
            style={{
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              background: '#FFFFFF',
              borderRadius: 'var(--radius-md)',
              border: '1px solid var(--border-light)',
              padding: '1.25rem',
              textAlign: 'center'
            }}
          >
            <div
              style={{
                background: '#FFFFFF',
                padding: '0.75rem',
                borderRadius: 'var(--radius-md)',
                boxShadow: '0 4px 12px rgba(0, 0, 0, 0.06)',
                border: '1px solid var(--border-light)',
                display: 'inline-block',
                cursor: 'pointer'
              }}
              onClick={() => setShowFullscreen(true)}
              title="Click to expand QR Code"
            >
              {qrSvg ? (
                <div
                  dangerouslySetInnerHTML={{ __html: qrSvg }}
                  style={{ width: '180px', height: '180px', display: 'block' }}
                />
              ) : (
                <div style={{ width: '180px', height: '180px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <QrCode size={48} color="var(--text-muted)" />
                </div>
              )}
            </div>

            <div style={{ marginTop: '0.75rem' }}>
              <div style={{ fontWeight: 600, fontSize: '0.875rem', color: 'var(--dark)' }}>
                Scan to Verify Proof
              </div>
              <p style={{ margin: '0.25rem 0 0', fontSize: '0.75rem', color: 'var(--text-muted)', maxWidth: '240px' }}>
                Collection agent scans this code to verify item authenticity, customer address, and pre-collection safety checklist.
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Fullscreen QR Modal */}
      {showFullscreen && (
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
          onClick={() => setShowFullscreen(false)}
        >
          <div
            className="card"
            style={{
              maxWidth: '420px',
              width: '100%',
              textAlign: 'center',
              padding: '2rem',
              background: '#FFFFFF'
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem' }}>
              <div>
                <h3 style={{ margin: 0, fontSize: '1.25rem' }}>Handover QR Pass</h3>
                <span style={{ fontSize: '0.8125rem', color: 'var(--text-muted)' }}>{passCode}</span>
              </div>
              <button
                onClick={() => setShowFullscreen(false)}
                className="btn btn-secondary btn-sm"
                type="button"
              >
                <X size={16} />
              </button>
            </div>

            {qrDataUrl && (
              <div
                style={{
                  background: '#FFFFFF',
                  padding: '1rem',
                  borderRadius: 'var(--radius-md)',
                  display: 'inline-block',
                  boxShadow: '0 4px 16px rgba(0,0,0,0.1)',
                  marginBottom: '1rem'
                }}
              >
                <img
                  src={qrDataUrl}
                  alt="Handover Verification QR Code"
                  style={{ width: '260px', height: '260px', display: 'block' }}
                />
              </div>
            )}

            <div style={{ fontSize: '0.875rem', color: 'var(--text-main)', fontWeight: 500, marginBottom: '0.5rem' }}>
              {recovery?.item?.name}
            </div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
              Show this screen to the collection agent for direct on-site scanning and instant verification.
            </div>

            <button
              onClick={() => setShowFullscreen(false)}
              className="btn btn-secondary"
              style={{ width: '100%', marginTop: '1.25rem' }}
              type="button"
            >
              Close
            </button>
          </div>
        </div>
      )}
    </>
  )
}
