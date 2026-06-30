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

  // Thousands-separated integer formatting (e.g. 1045 -> "1,045").
  function formatNumber(value?: number | string | null): string {
    const n = typeof value === 'number' ? value : Number.parseInt(String(value ?? ''), 10)
    return Number.isFinite(n) ? new Intl.NumberFormat('en-US').format(n) : '—'
  }

  function summarizeText(value?: string | null, limit = 160): string {
    if (!value)
      return 'Summary not available.'
    return value.length > limit ? `${value.slice(0, limit).trim()}...` : value
  }

  // Maps a vote outcome to a Nuxt UI badge/button color.
  function voteResultColor(result?: string | null): 'success' | 'error' | 'neutral' {
    const n = String(result || '').toLowerCase()
    if (['passed', 'agreed', 'confirmed', 'approved', 'adopted', 'ratified', 'accepted'].some(w => n.includes(w)))
      return 'success'
    if (['failed', 'rejected', 'not agreed'].some(w => n.includes(w)))
      return 'error'
    return 'neutral'
  }

  // Maps a party code to a CSS color variable (defined in assets/css/main.css).
  function partyColor(party?: string | null): string {
    const p = String(party || '').toUpperCase()
    if (p === 'R') return 'var(--party-house)'
    if (p === 'D') return 'var(--party-senate)'
    if (p === 'I') return 'var(--party-independent)'
    return 'var(--ui-text-muted)'
  }

  return { formatDate, formatChamber, partyLabel, voteResultColor, partyColor, formatNumber, summarizeText }
}
