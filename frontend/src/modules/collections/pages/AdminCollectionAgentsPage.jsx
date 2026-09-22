import React, { useEffect, useState } from 'react'
import { Plus, Users, Edit2, Trash2, CheckCircle2, AlertCircle, X, ShieldCheck } from 'lucide-react'
import { apiClient } from '../../../shared/services/apiClient.js'
import { TopBar } from '../../../shared/components/TopBar.jsx'

export function AdminCollectionAgentsPage() {
  const [agents, setAgents] = useState([])
  const [loading, setLoading] = useState(true)
  const [showModal, setShowModal] = useState(false)
  const [editingAgent, setEditingAgent] = useState(null)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  // Form
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [phone, setPhone] = useState('')
  const [serviceArea, setServiceArea] = useState('')
  const [townArea, setTownArea] = useState('')

  useEffect(() => {
    loadAgents()
  }, [])

  const loadAgents = async () => {
    try {
      setLoading(true)
      const res = await apiClient.get('/api/admin/collection-agents')
      setAgents(res.data)
    } catch {
      setError('Failed to load collection agents.')
    } finally {
      setLoading(false)
    }
  }

  const openAddModal = () => {
    setEditingAgent(null)
    setName('')
    setEmail('')
    setPassword('')
    setPhone('')
    setServiceArea('')
    setTownArea('')
    setShowModal(true)
  }

  const openEditModal = (a) => {
    setEditingAgent(a)
    setName(a.name)
    setEmail(a.email)
    setPhone(a.phone || '')
    setServiceArea(a.serviceArea)
    setTownArea(a.townArea || '')
    setShowModal(true)
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')
    try {
      if (editingAgent) {
        await apiClient.put(`/api/admin/collection-agents/${editingAgent.profileId}`, {
          phone: phone || null,
          serviceArea,
          townArea: townArea || null,
          isActive: editingAgent.isActive
        })
        setSuccess('Agent profile updated successfully.')
      } else {
        await apiClient.post('/api/admin/collection-agents', {
          name,
          email,
          password,
          phone: phone || null,
          serviceArea,
          townArea: townArea || null
        })
        setSuccess('Collection agent registered successfully.')
      }
      setShowModal(false)
      await loadAgents()
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to save collection agent.')
    }
  }

  const handleDelete = async (agent) => {
    if (!confirm(`Are you sure you want to permanently delete collection agent "${agent.name}" (${agent.email})?`)) return
    try {
      setError('')
      const res = await apiClient.delete(`/api/admin/collection-agents/${agent.profileId}`)
      setSuccess(res.data?.message || `Collection agent "${agent.name}" deleted successfully.`)
      await loadAgents()
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to delete collection agent.')
    }
  }

  return (
    <>
      <TopBar
        title="Collection Agents"
        action={
          <button onClick={openAddModal} className="btn btn-primary btn-sm">
            <Plus size={16} />
            <span>Add Collection Agent</span>
          </button>
        }
      />

      <div className="content-container">
        <div className="page-header">
          <div className="page-title-group">
            <h1>Collection Agent Fleet</h1>
            <div className="page-subtitle">Manage registered physical pickup agents, territories, and availability status</div>
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
            <p style={{ color: 'var(--text-muted)' }}>Loading collection agents...</p>
          </div>
        ) : (
          <div className="table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Agent Name</th>
                  <th>Service Territory</th>
                  <th>Town Area</th>
                  <th>Email & Phone</th>
                  <th>Availability</th>
                  <th>Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {agents.map((a) => (
                  <tr key={a.profileId}>
                    <td>
                      <div style={{ fontWeight: 600 }}>{a.name}</div>
                    </td>
                    <td>{a.serviceArea}</td>
                    <td style={{ fontSize: '0.8125rem' }}>
                      {a.townArea ? (
                        <span style={{ fontWeight: 500 }}>{a.townArea}</span>
                      ) : (
                        <span style={{ color: 'var(--text-muted)' }}>All towns</span>
                      )}
                    </td>
                    <td style={{ fontSize: '0.8125rem' }}>
                      <div>{a.email}</div>
                      <div style={{ color: 'var(--text-muted)' }}>{a.phone || 'No phone'}</div>
                    </td>
                    <td>
                      <span className={`status-chip ${a.isAvailable ? 'status-approved' : 'status-revision'}`}>
                        {a.isAvailable ? 'Available' : 'Busy (On Active Job)'}
                      </span>
                    </td>
                    <td>
                      <span className={`status-chip ${a.isActive ? 'status-approved' : 'status-rejected'}`}>
                        {a.isActive ? 'Active' : 'Inactive'}
                      </span>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: '0.5rem' }}>
                        <button onClick={() => openEditModal(a)} className="btn btn-secondary btn-sm" title="Edit Profile">
                          <Edit2 size={14} />
                        </button>
                        <button onClick={() => handleDelete(a)} className="btn btn-secondary btn-sm" title="Delete Agent">
                          <Trash2 size={14} color="var(--error)" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Modal */}
        {showModal && (
          <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: '1rem' }}>
            <div className="card" style={{ maxWidth: '500px', width: '100%' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem' }}>
                <h3>{editingAgent ? 'Edit Collection Agent' : 'Register New Collection Agent'}</h3>
                <button onClick={() => setShowModal(false)} className="btn btn-secondary btn-sm">
                  <X size={16} />
                </button>
              </div>

              <form onSubmit={handleSubmit}>
                {!editingAgent && (
                  <>
                    <div className="form-group">
                      <label className="form-label">Full Name *</label>
                      <input
                        type="text"
                        required
                        className="form-input"
                        value={name}
                        onChange={(e) => setName(e.target.value)}
                      />
                    </div>

                    <div className="form-group">
                      <label className="form-label">Email Address *</label>
                      <input
                        type="email"
                        required
                        className="form-input"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                      />
                    </div>

                    <div className="form-group">
                      <label className="form-label">Password *</label>
                      <input
                        type="password"
                        required
                        minLength={6}
                        className="form-input"
                        value={password}
                        onChange={(e) => setPassword(e.target.value)}
                      />
                    </div>
                  </>
                )}

                <div className="form-group">
                  <label className="form-label">Phone</label>
                  <input
                    type="text"
                    className="form-input"
                    placeholder="e.g. +94 77 123 4567"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                  />
                </div>

                <div className="form-group">
                  <label className="form-label">Service Territory / District *</label>
                  <input
                    type="text"
                    required
                    className="form-input"
                    placeholder="e.g. Colombo"
                    value={serviceArea}
                    onChange={(e) => setServiceArea(e.target.value)}
                  />
                </div>

                <div className="form-group">
                  <label className="form-label">Town Area / Vicinity *</label>
                  <input
                    type="text"
                    required
                    className="form-input"
                    placeholder="e.g. Colombo 03 / Kollupitiya, Bambalapitiya"
                    value={townArea}
                    onChange={(e) => setTownArea(e.target.value)}
                  />
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.25rem' }}>
                    Specific town or coverage zones assigned to this agent for collection logistics.
                  </div>
                </div>

                {editingAgent && (
                  <div className="form-group" style={{ background: 'var(--surface-subtle)', padding: '0.75rem 1rem', borderRadius: '8px', border: '1px solid var(--border)' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <span style={{ fontSize: '0.875rem', fontWeight: 500 }}>Live Operational Availability</span>
                      <span className={`status-chip ${editingAgent.isAvailable ? 'status-approved' : 'status-revision'}`}>
                        {editingAgent.isAvailable ? 'Available' : 'Busy (On Active Job)'}
                      </span>
                    </div>
                    <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.35rem' }}>
                      Availability is automated by collection job lifecycles (Busy during accepted pickups, Available when completed or idle).
                    </div>
                  </div>
                )}

                <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.75rem', marginTop: '1.5rem' }}>
                  <button type="button" onClick={() => setShowModal(false)} className="btn btn-secondary">
                    Cancel
                  </button>
                  <button type="submit" className="btn btn-primary">
                    {editingAgent ? 'Save Profile' : 'Register Agent'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}
      </div>
    </>
  )
}
