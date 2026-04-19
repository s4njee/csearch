import type {
  BillDetail,
  BillRecord,
  CommitteeDetail,
  CommitteeRecord,
  ExploreListResponse,
  ExploreQueryResponse,
  MemberDetail,
  MembersByState,
  VoteDetail,
  VoteRecord,
} from '~/types/congress'

function withQuery(path: string, query: Record<string, string | number | undefined | null>) {
  const search = new URLSearchParams()

  Object.entries(query).forEach(([key, value]) => {
    if (value === undefined || value === null || value === '') {
      return
    }

    search.set(key, String(value))
  })

  const suffix = search.toString()
  return suffix ? `${path}?${suffix}` : path
}

const SEMANTIC_SEARCH_LIMIT = 50
const SEMANTIC_SEARCH_TIMEOUT_MS = 10000
const SEMANTIC_SEARCH_RETRIES = 1

export function useCongressApi() {
  const apiBase = useApiBase()

  async function apiFetch<T>(path: string): Promise<T> {
    return await $fetch<T>(`${apiBase}${path}`)
  }

  function isTimeoutError(error: any) {
    return error?.name === 'TimeoutError'
      || error?.name === 'AbortError'
      || error?.cause?.name === 'TimeoutError'
      || error?.message?.toLowerCase?.().includes('timeout')
  }

  // The 10-second timeout avoids blocking the UI when the embedding endpoint is slow.
  // One retry covers transient network errors without adding noticeable latency on success.
  async function fetchSemanticRows(query: string) {
    let lastError: unknown

    for (let attempt = 0; attempt <= SEMANTIC_SEARCH_RETRIES; attempt += 1) {
      try {
        return await $fetch<Array<Record<string, any>>>(`${apiBase}/search/semantic`, {
          method: 'POST',
          body: { query, limit: SEMANTIC_SEARCH_LIMIT },
          timeout: SEMANTIC_SEARCH_TIMEOUT_MS,
        })
      }
      catch (error: any) {
        lastError = error
        if (!isTimeoutError(error) || attempt === SEMANTIC_SEARCH_RETRIES) {
          throw error
        }
      }
    }

    throw lastError
  }

  // Maps the flat API response from the semantic endpoint (which returns snake_case fields)
  // into the standard BillRecord shape expected by the bills list.
  function normalizeSemanticBill(row: Record<string, any>): BillRecord {
    const billTypeMatch = String(row.bill_id || '').match(/^([a-z]+)(\d+)-(\d+)$/i)
    const billtype = String(row.billtype ?? row.bill_type ?? billTypeMatch?.[1] ?? '')
    const billnumber = String(row.billnumber ?? row.bill_number ?? billTypeMatch?.[2] ?? '')
    const congress = String(row.congress ?? billTypeMatch?.[3] ?? '')

    return {
      billid: String(row.billid ?? row.bill_id ?? `${billtype}${billnumber}-${congress}`),
      billtype,
      billnumber,
      congress,
      shorttitle: row.shorttitle ?? null,
      officialtitle: row.officialtitle ?? row.title ?? null,
      introducedat: row.introducedat ?? null,
      statusat: String(row.statusat ?? ''),
      summary_text: row.summary_text ?? row.body ?? null,
      sponsor_name: row.sponsor_name ?? null,
      sponsor_party: row.sponsor_party ?? null,
      sponsor_state: row.sponsor_state ?? null,
      sponsor_bioguide_id: row.sponsor_bioguide_id ?? null,
      origin_chamber: row.origin_chamber ?? null,
      policy_area: row.policy_area ?? null,
      update_date: row.update_date ?? null,
      latest_action_date: row.latest_action_date ?? null,
      cosponsor_count: row.cosponsor_count ?? null,
      bill_status: row.bill_status ?? row.status ?? null,
      similarity: row.similarity ?? null,
    }
  }

  return {
    apiBase,
    listExploreQueries: () => apiFetch<ExploreListResponse>('/explore'),
    runExploreQuery: (queryId: string, query: Record<string, string | number | undefined | null> = {}) =>
      apiFetch<ExploreQueryResponse>(withQuery(`/explore/${queryId}`, query)),
    latestBills: (billType: string) => apiFetch<BillRecord[]>(`/latest/${billType}`),
    searchBills: (billType: string, filter: string, query: string) =>
      apiFetch<BillRecord[]>(withQuery(`/search/${billType}/${filter}`, { query })),
    searchAllBills: (query: string) =>
      apiFetch<BillRecord[]>(withQuery('/search/all/relevance', { query })),
    semanticSearch: async (query: string): Promise<BillRecord[]> => {
      try {
        const rows = await fetchSemanticRows(query)
        return rows.map(normalizeSemanticBill)
      }
      catch (error: any) {
        if (isTimeoutError(error)) {
          throw error
        }

        return await apiFetch<BillRecord[]>(withQuery('/search/all/relevance', { query }))
      }
    },
    getBill: (billType: string, congress: string, billNumber: string) =>
      apiFetch<BillDetail>(`/bills/${billType}/${congress}/${billNumber}`),
    fetchBillsByNumber: (number: string) =>
      apiFetch<BillRecord[]>(`/bills/bynumber/${number}`),
    latestVotes: (chamber: string) => apiFetch<VoteRecord[]>(`/votes/${chamber}`),
    searchVotes: (query: Record<string, string | number | undefined | null>) =>
      apiFetch<ExploreQueryResponse>(withQuery('/explore/vote-search-example', query)),
    searchVotesFuzzy: (query: string, chamber?: string) =>
      apiFetch<VoteRecord[]>(withQuery('/votes/search', { query, chamber })),
    getMember: (bioguideId: string) => apiFetch<MemberDetail>(`/members/${bioguideId}`),
    getMembersByState: (state: string) => apiFetch<MembersByState>(`/members/by-state/${state}`),
    getVote: (voteId: string) => apiFetch<VoteDetail>(`/votes/detail/${voteId}`),
    getCommittees: () => apiFetch<CommitteeRecord[]>('/committees'),
    getCommittee: (code: string) => apiFetch<CommitteeDetail>(`/committees/${code}`),
  }
}
