import React from 'react'
import { Link, useNavigate } from 'react-router'
import { Repeat, ArrowRight, Sparkles } from 'lucide-react'
import { useAuth } from '../../shared/context/AuthContext.jsx'

export function HomePage() {
  const { user, role } = useAuth()
  const navigate = useNavigate()

  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column', backgroundColor: '#FFFFFF' }}>
      {/* Header */}
      <header style={{ height: '72px', borderBottom: '1px solid var(--border-light)', display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 2.5rem' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
          <div style={{ background: 'var(--primary-light)', padding: '0.5rem', borderRadius: 'var(--radius-sm)', display: 'flex' }}>
            <Repeat size={24} color="var(--primary)" />
          </div>
          <div>
            <div style={{ fontWeight: 700, fontSize: '1.25rem', color: 'var(--primary)' }}>LoopWorth</div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Give Waste Another Worth</div>
          </div>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
          {user ? (
            <button
              onClick={() => navigate(role === 'Admin' ? '/admin' : role === 'CollectionAgent' ? '/agent' : role === 'Partner' ? '/partner' : '/dashboard')}
              className="btn btn-primary"
            >
              <span>Go to Dashboard</span>
              <ArrowRight size={16} />
            </button>
          ) : (
            <>
              <Link to="/login" className="btn btn-secondary">Sign In</Link>
              <Link to="/register" className="btn btn-primary">Get Started</Link>
            </>
          )}
        </div>
      </header>

      {/* Hero Section */}
      <section style={{ padding: '5rem 2.5rem', maxWidth: '1100px', margin: '0 auto', textAlign: 'center' }}>
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: '0.5rem', background: 'var(--primary-light)', color: 'var(--primary)', padding: '0.375rem 1rem', borderRadius: 'var(--radius-full)', fontSize: '0.875rem', fontWeight: 600, marginBottom: '1.5rem' }}>
          <Sparkles size={16} />
          <span>AI-Assisted Circular Economy Platform</span>
        </div>
        <h1 style={{ fontSize: '3rem', fontWeight: 800, color: 'var(--dark)', marginBottom: '1.25rem', lineHeight: 1.15 }}>
          Transform Electronic Waste Into Sustainable Value
        </h1>
        <p style={{ fontSize: '1.125rem', color: 'var(--text-muted)', maxWidth: '720px', margin: '0 auto 2.5rem', lineHeight: 1.6 }}>
          LoopWorth orchestrates an intelligent multi-agent pipeline: Advisory Item Assessment, Recovery Plan Generation, Certified Partner Matching, and Physical Collection Logistics.
        </p>
        <div style={{ display: 'flex', justifyContent: 'center', gap: '1rem' }}>
          <Link to="/register" className="btn btn-primary btn-lg">
            <span>Submit Your Waste Item</span>
            <ArrowRight size={18} />
          </Link>
          <Link to="/login" className="btn btn-secondary btn-lg">
            <span>Explore Demo Portal</span>
          </Link>
        </div>
      </section>

      {/* 7-Step Recovery Loop */}
      <section style={{ background: 'var(--background)', padding: '4rem 2.5rem', borderTop: '1px solid var(--border-light)' }}>
        <div style={{ maxWidth: '1100px', margin: '0 auto' }}>
          <div style={{ textAlign: 'center', marginBottom: '3rem' }}>
            <h2 style={{ fontSize: '2rem', marginBottom: '0.5rem' }}>The LoopWorth 7-Step Recovery Workflow</h2>
            <p style={{ color: 'var(--text-muted)' }}>Traceable, transparent, and verified across all participants</p>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '1.5rem' }}>
            <div className="card">
              <div style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--primary)', marginBottom: '0.5rem' }}>STEP 01</div>
              <h3 style={{ fontSize: '1.125rem', marginBottom: '0.5rem' }}>Item Submission</h3>
              <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem' }}>
                Customer submits item specs, description, brand, model, and uploads photos.
              </p>
            </div>

            <div className="card">
              <div style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--primary)', marginBottom: '0.5rem' }}>STEP 02</div>
              <h3 style={{ fontSize: '1.125rem', marginBottom: '0.5rem' }}>AI Advisory Assessment</h3>
              <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem' }}>
                Agent 1 inspects item details and condition to advise Donate or Recycle.
              </p>
            </div>

            <div className="card">
              <div style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--primary)', marginBottom: '0.5rem' }}>STEP 03</div>
              <h3 style={{ fontSize: '1.125rem', marginBottom: '0.5rem' }}>Route Selection & Prep Plan</h3>
              <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem' }}>
                Customer selects route; Agent 2 provides step-by-step preparation and safety measures.
              </p>
            </div>

            <div className="card">
              <div style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--primary)', marginBottom: '0.5rem' }}>STEP 04</div>
              <h3 style={{ fontSize: '1.125rem', marginBottom: '0.5rem' }}>Human Admin Approval</h3>
              <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem' }}>
                Admin reviews recovery plan with Approve, Reject, or Request Revision controls.
              </p>
            </div>

            <div className="card">
              <div style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--primary)', marginBottom: '0.5rem' }}>STEP 05</div>
              <h3 style={{ fontSize: '1.125rem', marginBottom: '0.5rem' }}>AI Partner Matching</h3>
              <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem' }}>
                Agent 3 ranks pre-filtered certified recyclers and charities; customer selects recipient.
              </p>
            </div>

            <div className="card">
              <div style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--primary)', marginBottom: '0.5rem' }}>STEP 06</div>
              <h3 style={{ fontSize: '1.125rem', marginBottom: '0.5rem' }}>Collection Logistics</h3>
              <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem' }}>
                Agent 4 optimizes pickup window and suggests agent; Admin assigns collection agent.
              </p>
            </div>

            <div className="card">
              <div style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--primary)', marginBottom: '0.5rem' }}>STEP 07</div>
              <h3 style={{ fontSize: '1.125rem', marginBottom: '0.5rem' }}>Handover & Completion</h3>
              <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem' }}>
                Collection agent marks Collected then Delivered to Partner; Admin confirms receipt.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer style={{ marginTop: 'auto', borderTop: '1px solid var(--border-light)', padding: '2rem 2.5rem', textAlign: 'center', color: 'var(--text-muted)', fontSize: '0.875rem' }}>
        LoopWorth &copy; {new Date().getFullYear()} — Give Waste Another Worth. All rights reserved.
      </footer>
    </div>
  )
}
