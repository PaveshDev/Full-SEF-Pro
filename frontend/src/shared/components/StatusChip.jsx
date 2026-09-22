import React from 'react'

export function StatusChip({ status, type = 'status' }) {
  if (!status) return null

  const s = status.toLowerCase()
  let className = 'status-chip '

  if (type === 'route' || ['donate', 'recycle'].includes(s)) {
    if (s.includes('donate')) className += 'status-route-donate'
    else if (s.includes('recycle')) className += 'status-route-recycle'
  } else {
    if (s.includes('draft')) className += 'status-draft'
    else if (s.includes('submitted')) className += 'status-submitted'
    else if (s.includes('assessed')) className += 'status-assessed'
    else if (s.includes('pending') || s.includes('requested')) className += 'status-pending'
    else if (s.includes('approved')) className += 'status-approved'
    else if (s.includes('rejected')) className += 'status-rejected'
    else if (s.includes('revision')) className += 'status-revision'
    else if (s.includes('scheduled')) className += 'status-scheduled'
    else if (s.includes('assigned')) className += 'status-assigned'
    else if (s.includes('collected')) className += 'status-collected'
    else if (s.includes('delivered') || s.includes('partnerreceived') || s.includes('handover')) className += 'status-delivered'
    else if (s.includes('completed')) className += 'status-completed'
    else className += 'status-draft'
  }

  let displayLabel = status
  if (s === 'agentassigned') displayLabel = 'Agent Assigned'
  else if (s === 'collected') displayLabel = 'Item Picked Up'
  else if (s === 'deliveredtopartner') displayLabel = 'Handed Over to Partner'
  else if (s === 'partnerreceived') displayLabel = 'Partner Received'
  else if (s === 'completed') displayLabel = 'Completed'

  return <span className={className}>{displayLabel}</span>
}
