import React, { useEffect, useState } from 'react'
import { Cpu, CheckCircle2, AlertCircle, Clock, Eye, X } from 'lucide-react'
import { apiClient } from '../../shared/services/apiClient.js'
import { StatusChip } from '../../shared/components/StatusChip.jsx'
import { TopBar } from '../../shared/components/TopBar.jsx'

export function AIWorkflowHistoryPage() {
  const [workflows, setWorkflows] = useState([])
  const [selectedWf, setSelectedWf] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    loadWorkflows()
  }, [])

  const loadWorkflows = async () => {
    try {
      setLoading(true)
      const res = await apiClient.get('/api/admin/workflows')
      setWorkflows(res.data)
    } catch {
      setError('Failed to load AI workflow history.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <>
      <TopBar title="AI Agent Workflows" />

      <div className="content-container">
        <div className="page-header">
          <div className="page-title-group">
            <h1>Multi-Agent Execution Audit</h1>
            <div className="page-subtitle">Inspect structured inputs, outputs, and status across Agents 1 to 4</div>
          </div>
        </div>

        {error && (
          <div className="alert alert-error">
            <AlertCircle size={18} />
            <span>{error}</span>
          </div>
        )}

        {loading ? (
          <div className="card" style={{ textAlign: 'center', padding: '3rem' }}>
            <p style={{ color: 'var(--text-muted)' }}>Loading AI workflow history...</p>
          </div>
        ) : workflows.length === 0 ? (
          <div className="card" style={{ textAlign: 'center', padding: '3rem' }}>
            <Cpu size={36} color="var(--primary)" style={{ margin: '0 auto 1rem' }} />
            <h3>No AI workflows recorded yet</h3>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem', marginTop: '0.25rem' }}>
              Workflows are initiated automatically when items are submitted and progress through the agents.
            </p>
          </div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: selectedWf ? '1.1fr 0.9fr' : '1fr', gap: '1.5rem', alignItems: 'start' }}>
            <div className="table-container">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Item</th>
                    <th>Current Stage</th>
                    <th>Status</th>
                    <th>Steps Completed</th>
                    <th>Started</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {workflows.map((wf) => (
                    <tr
                      key={wf.id}
                      style={{ background: selectedWf?.id === wf.id ? 'var(--primary-light)' : undefined }}
                    >
                      <td>
                        <div style={{ fontWeight: 600 }}>{wf.itemName || 'Item'}</div>
                        <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>ID: {wf.itemId.slice(0, 8)}...</div>
                      </td>
                      <td>
                        <span style={{ fontWeight: 500, color: 'var(--primary)', background: 'var(--primary-light)', padding: '0.2rem 0.5rem', borderRadius: 'var(--radius-sm)', fontSize: '0.75rem' }}>
                          {wf.currentStage}
                        </span>
                      </td>
                      <td><StatusChip status={wf.status} /></td>
                      <td style={{ fontSize: '0.875rem' }}>{wf.steps?.length || 0} steps</td>
                      <td style={{ fontSize: '0.8125rem', color: 'var(--text-muted)' }}>
                        {new Date(wf.createdAt).toLocaleString()}
                      </td>
                      <td>
                        <button
                          onClick={() => setSelectedWf(wf)}
                          className="btn btn-secondary btn-sm"
                        >
                          <Eye size={14} />
                          <span>Inspect</span>
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {/* Steps Inspector */}
            {selectedWf && (
              <div className="card">
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '1rem' }}>
                  <div>
                    <h3>Agent Execution Trace</h3>
                    <div style={{ fontSize: '0.8125rem', color: 'var(--text-muted)' }}>
                      Objective: <strong>{selectedWf.objective}</strong>
                    </div>
                  </div>
                  <button onClick={() => setSelectedWf(null)} className="btn btn-secondary btn-sm">
                    <X size={16} />
                  </button>
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem', maxHeight: '550px', overflowY: 'auto' }}>
                  {selectedWf.steps && selectedWf.steps.length > 0 ? (
                    selectedWf.steps.map((step) => (
                      <div
                        key={step.id}
                        style={{
                          background: '#F8FAFC',
                          border: '1px solid var(--border-light)',
                          borderRadius: 'var(--radius-sm)',
                          padding: '0.875rem'
                        }}
                      >
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.375rem' }}>
                          <span style={{ fontWeight: 600, color: 'var(--dark)', fontSize: '0.875rem' }}>
                            {step.agentName}
                          </span>
                          <span className={`status-chip ${step.executionStatus === 'Succeeded' ? 'status-approved' : step.executionStatus === 'Failed' ? 'status-rejected' : 'status-revision'}`} style={{ fontSize: '0.7rem' }}>
                            {step.executionStatus}
                          </span>
                        </div>

                        <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginBottom: '0.5rem' }}>
                          Step: <strong>{step.stepName}</strong> • {new Date(step.startedAt).toLocaleTimeString()}
                        </div>

                        {step.inputSummary && (
                          <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginBottom: '0.25rem' }}>
                            <strong>Input:</strong> {step.inputSummary}
                          </div>
                        )}

                        {step.outputSummary && (
                          <div style={{ fontSize: '0.75rem', color: 'var(--text-main)', background: '#FFFFFF', padding: '0.375rem', borderRadius: '4px', border: '1px solid var(--border-light)' }}>
                            <strong>Output:</strong> {step.outputSummary}
                          </div>
                        )}

                        {step.errorMessage && (
                          <div style={{ fontSize: '0.75rem', color: 'var(--error)', background: '#FEE2E2', padding: '0.375rem', borderRadius: '4px', marginTop: '0.25rem' }}>
                            <strong>Error:</strong> {step.errorMessage}
                          </div>
                        )}
                      </div>
                    ))
                  ) : (
                    <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem' }}>No steps recorded in this workflow.</p>
                  )}
                </div>
              </div>
            )}
          </div>
        )}
      </div>
    </>
  )
}
