// Display formatting helpers shared across bill, vote, member, and committee pages.

export function useFormatters() {
  function formatDate(value?: string | null): string {
    if (!value)
      return '—'
    const date = new Date(value)
    if (Number.isNaN(date.getTime()))
      return value
    return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' }).format(date)
  }

  function formatChamber(value?: string | null): string {
    const normalized = String(value || '').toLowerCase()
    if (normalized === 'senate' || normalized === 's')
      return 'Senate'
    if (normalized === 'house' || normalized === 'h')
      return 'House'
    return value || 'Unknown chamber'
  }

  function partyLabel(party?: string | null): string {
    if (!party)
      return ''
    const map: Record<string, string> = { D: 'Democrat', R: 'Republican', I: 'Independent' }
    return map[party.toUpperCase()] || party
  }

  function voteResultClass(result?: string | null): string {
    const n = String(result || '').toLowerCase()
    if (['passed', 'agreed', 'confirmed', 'approved', 'adopted', 'ratified'].some(w => n.includes(w)))
      return 'vote-badge vote-badge--positive'
    if (['failed', 'rejected', 'not agreed'].some(w => n.includes(w)))
      return 'vote-badge vote-badge--negative'
    return 'vote-badge'
  }

  function summarizeText(value?: string | null, limit = 160): string {
    if (!value)
      return 'Summary not available.'
    return value.length > limit ? `${value.slice(0, limit).trim()}...` : value
  }

  return { formatDate, formatChamber, partyLabel, voteResultClass, summarizeText }
}
