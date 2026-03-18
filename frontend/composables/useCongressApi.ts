import type {
  BillDetail,
  BillRecord,
  CommitteeDetail,
  CommitteeRecord,
  ExploreListResponse,
  ExploreQueryResponse,
  MemberDetail,
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

export function useCongressApi() {
  const config = useRuntimeConfig()
  const apiBase = config.public.API_SERVER

  async function apiFetch<T>(path: string): Promise<T> {
    return await $fetch<T>(`${apiBase}${path}`)
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
    getVote: (voteId: string) => apiFetch<VoteDetail>(`/votes/detail/${voteId}`),
    getCommittees: () => apiFetch<CommitteeRecord[]>('/committees'),
    getCommittee: (code: string) => apiFetch<CommitteeDetail>(`/committees/${code}`),
  }
}
