// ─── Bill list (returned by /latest/:billtype and /search/:table/:filter) ─────

export interface BillRecord {
  billid: string
  billnumber: string
  billtype: string
  congress: string
  shorttitle?: string | null
  officialtitle?: string | null
  introducedat?: string | null
  statusat: string
  summary_text?: string | null
  sponsor_name?: string | null
  sponsor_party?: string | null
  sponsor_state?: string | null
  sponsor_bioguide_id?: string | null
  origin_chamber?: string | null
  policy_area?: string | null
  update_date?: string | null
  latest_action_date?: string | null
  cosponsor_count?: number | null
}

// ─── Bill detail (returned by /bills/:billtype/:congress/:billnumber) ─────────

export interface BillAction {
  acted_at: string
  action_text?: string | null
  action_type?: string | null
  action_code?: string | null
}

export interface BillCosponsor {
  bioguide_id: string
  full_name?: string | null
  state?: string | null
  party?: string | null
  sponsorship_date?: string | null
  is_original_cosponsor?: boolean | null
}

export interface BillVote {
  voteid: string
  congress?: string | null
  chamber?: string | null
  question?: string | null
  result?: string | null
  votedate?: string | null
  votetype?: string | null
}

export interface BillDetail extends BillRecord {
  summary_date?: string | null
  actions: BillAction[]
  cosponsors: BillCosponsor[]
  votes: BillVote[]
  committees: CommitteeRecord[]
}

// ─── Votes ────────────────────────────────────────────────────────────────────

export interface VoteRecord {
  congress?: string | number | null
  votenumber?: string | number | null
  votedate?: string | null
  question?: string | null
  votesession?: string | null
  result?: string | null
  chamber?: string | null
  votetype?: string | null
  voteid: string
  yea?: number | null
  nay?: number | null
  present?: number | null
  notvoting?: number | null
  // explore vote-search-example returns these names
  yea_count?: number | null
  nay_count?: number | null
  source_url?: string | null
}

export interface VoteMember {
  bioguide_id: string
  display_name?: string | null
  party?: string | null
  state?: string | null
  position: string
}

export interface VoteDetail extends VoteRecord {
  members: VoteMember[]
}

// ─── Members ──────────────────────────────────────────────────────────────────

export interface MemberCounts {
  sponsored: number
  cosponsored: number
}

export interface MemberProfile {
  bioguide_id: string
  name: string
  party?: string | null
  state?: string | null
}

export interface MemberDetail extends MemberProfile {
  counts: MemberCounts
  sponsoredBills: BillRecord[]
  recentVotes: VoteRecord[]
}

// ─── Committees ───────────────────────────────────────────────────────────────

export interface CommitteeRecord {
  committee_code: string
  committee_name?: string | null
  chamber?: string | null
  bill_count?: string | number
}

export interface CommitteeDetail extends CommitteeRecord {
  bills: BillRecord[]
}

// ─── Explore ──────────────────────────────────────────────────────────────────

export interface ExploreParameter {
  name: string
  type: string
  default: string | number | null
  min?: number
  max?: number
}

export interface ExploreQuery {
  id: string
  number: number
  title: string
  path: string
  parameters: ExploreParameter[]
}

export interface ExploreListResponse {
  queries: ExploreQuery[]
}

export interface ExploreQueryResponse {
  query: ExploreQuery
  sql: string
  bindings: Array<string | number | null>
  results: Array<Record<string, unknown>>
}

// ─── UI constants ─────────────────────────────────────────────────────────────

export interface BillTypeOption {
  code: string
  shortLabel: string
  longLabel: string
  chamber: 'house' | 'senate'
  description: string
}

export interface VoteChamberOption {
  value: 'house' | 'senate'
  label: string
}

export const BILL_TYPE_OPTIONS: BillTypeOption[] = [
  { code: 's', shortLabel: 'S', longLabel: 'Senate bills', chamber: 'senate', description: 'Standard Senate legislation.' },
  { code: 'sconres', shortLabel: 'S.Con.Res.', longLabel: 'Senate concurrent resolutions', chamber: 'senate', description: 'Concurrent measures shared across both chambers.' },
  { code: 'sjres', shortLabel: 'S.J.Res.', longLabel: 'Senate joint resolutions', chamber: 'senate', description: 'Joint measures commonly used for authorizations and approvals.' },
  { code: 'sres', shortLabel: 'S.Res.', longLabel: 'Senate simple resolutions', chamber: 'senate', description: 'Senate-only resolutions and chamber business.' },
  { code: 'hr', shortLabel: 'H.R.', longLabel: 'House bills', chamber: 'house', description: 'Standard House legislation.' },
  { code: 'hconres', shortLabel: 'H.Con.Res.', longLabel: 'House concurrent resolutions', chamber: 'house', description: 'Concurrent measures shared across both chambers.' },
  { code: 'hjres', shortLabel: 'H.J.Res.', longLabel: 'House joint resolutions', chamber: 'house', description: 'Joint measures with broader congressional use.' },
  { code: 'hres', shortLabel: 'H.Res.', longLabel: 'House simple resolutions', chamber: 'house', description: 'House-only resolutions and procedural business.' },
]

export const VOTE_CHAMBER_OPTIONS: VoteChamberOption[] = [
  { value: 'senate', label: 'Senate' },
  { value: 'house', label: 'House' },
]

export const BILL_FILTER_OPTIONS = [
  { value: 'relevance', label: 'Relevance' },
  { value: 'date', label: 'Date' },
] as const

export const API_FAMILIES = [
  {
    id: 'latest',
    title: 'Latest bills',
    route: '/latest/:billtype',
    summary: 'Browse the freshest bill activity for each House and Senate bill family.',
  },
  {
    id: 'search',
    title: 'Bill search',
    route: '/search/:table/:filter',
    summary: 'Search bills by phrase and sort either by rank or recency.',
  },
  {
    id: 'bills-bynumber',
    title: 'Bill number search',
    route: '/bills/bynumber/:number',
    summary: 'Instant fuzzy matching for bills by cross-referencing only the numeric ID.',
  },
  {
    id: 'bills',
    title: 'Bill detail',
    route: '/bills/:billtype/:congress/:billnumber',
    summary: 'Full bill record with action history, cosponsors, and linked floor votes.',
  },
  {
    id: 'votes',
    title: 'Latest votes',
    route: '/votes/:chamber',
    summary: 'Review the latest House and Senate vote activity from the recent 90-day window.',
  },
  {
    id: 'votes-detail',
    title: 'Roll-call votes',
    route: '/votes/detail/:voteid',
    summary: 'Detailed roll-call results connecting the exact yea/nay positions to individual members.',
  },
  {
    id: 'members',
    title: 'Member profiles',
    route: '/members/:bioguide_id',
    summary: 'Legislator profiles with sponsored legislation and recent voting behavior.',
  },
  {
    id: 'committees',
    title: 'Committees',
    route: '/committees and /committees/:code',
    summary: 'Browse congressional committees and view the specific bills referred to their workflows.',
  },
] as const

export const EXPLORE_GROUPS = [
  {
    key: 'bill-landscape',
    title: 'Bill landscape',
    description: 'Browse what is moving through Congress, which issues dominate, and where activity clusters.',
    queryIds: [
      'recent-bills',
      'top-subject-areas',
      'active-committees',
      'policy-area-by-congress',
      'bills-with-floor-votes',
    ],
  },
  {
    key: 'coalitions-and-sponsors',
    title: 'Coalitions and sponsorship',
    description: 'See who sponsors bills, where support builds, and which measures attract bipartisan buy-in.',
    queryIds: [
      'largest-cosponsor-coalitions',
      'broad-sponsorship-history',
      'most-prolific-sponsors',
      'bipartisan-bills',
    ],
  },
  {
    key: 'votes-and-members',
    title: 'Votes and member behavior',
    description: 'Surface landslides, squeakers, abstentions, and members who break with party majorities.',
    queryIds: [
      'largest-vote-margins',
      'closest-votes',
      'most-not-voting-members',
      'party-line-crossovers',
      'vote-search-example',
    ],
  },
  {
    key: 'data-quality-and-search',
    title: 'Data quality and discovery',
    description: 'Inspect coverage gaps, procedural depth, and the built-in search helpers.',
    queryIds: [
      'deepest-action-history',
      'missing-descriptive-fields',
      'bill-search-example',
    ],
  },
] as const

export const EXPLORE_QUERY_DESCRIPTIONS: Record<string, string> = {
  'recent-bills': 'Freshly updated bills with sponsor, chamber, and policy context.',
  'largest-cosponsor-coalitions': 'Bills that have drawn the broadest cosponsor support.',
  'top-subject-areas': 'The issue areas with the most bills in the dataset.',
  'active-committees': 'Committees seeing the highest referral volume.',
  'deepest-action-history': 'Bills with the longest procedural trail.',
  'missing-descriptive-fields': 'Potential data quality gaps across titles, summaries, sponsors, or policy areas.',
  'largest-vote-margins': 'Votes decided by the widest yea/nay gaps.',
  'closest-votes': 'Tight votes where the chamber was sharply divided.',
  'most-not-voting-members': 'Members who most often appear as not voting.',
  'broad-sponsorship-history': 'Bills combining wide cosponsor support with many procedural actions.',
  'bill-search-example': 'Search bills by text, type, and congress using the API helper function.',
  'vote-search-example': 'Search votes by text, congress, and chamber.',
  'most-prolific-sponsors': 'The sponsors responsible for the highest bill volume.',
  'bipartisan-bills': 'Bills attracting meaningful Democratic and Republican cosponsorship.',
  'policy-area-by-congress': 'How policy area activity changes from congress to congress.',
  'bills-with-floor-votes': 'Bills connected to recorded floor votes and outcomes.',
  'party-line-crossovers': 'Members who most often vote against their party majority.',
}
