<script setup lang="ts">
import { BILL_FILTER_OPTIONS, BILL_TYPE_OPTIONS, VOTE_CHAMBER_OPTIONS } from '~/types/congress'
import type { BillRecord, CommitteeRecord } from '~/types/congress'

const route = useRoute()
const router = useRouter()
const { latestBills, semanticSearch, getCommittees } = useCongressApi()
const { formatDate, summarizeText, formatNumber } = useFormatters()
const { data: loadedCommittees } = await useAsyncData(
  'bill-committee-options',
  () => getCommittees(),
)

const PAGE_SIZE = 100

const loading = ref(false)
const loadProgress = ref(0)
const loadBytes = ref<number | null>(null)
const errorMessage = ref('')
const bills = ref<BillRecord[]>([])
const draftQuery = ref('')
const sortDesc = ref(true)
const currentPage = ref(1)
const isUpdatingBillRoute = ref(false)

const selectedCongress = ref('')
const selectedChamber = ref<'house' | 'senate'>(
  (getBillTypeChamber(typeof route.params.category === 'string' ? route.params.category : 'hr') || 'house') as 'house' | 'senate',
)
const selectedStatus = ref('')
const selectedSponsorParty = ref('')
const selectedCommittee = ref('')
const filterPolicyArea = ref('')
const filterMonth = ref('')
const filterMinCosponsors = ref<number | ''>('')
const committeeOptions = computed<CommitteeRecord[]>(() => loadedCommittees.value || [])

function formatSemanticScore(score: number | null | undefined) {
  if (score == null || Number.isNaN(score)) {
    return ''
  }

  return score.toFixed(2)
}

// Cosine similarity percentile thresholds chosen empirically:
// top 20% of results (percentile <= 0.2) are treated as strong relevance,
// top 50% (percentile <= 0.5) as moderate, and the rest as weak/loose.
function semanticRankLabel(index: number, total: number) {
  if (total <= 0) {
    return ''
  }

  const percentile = (index + 1) / total
  if (percentile <= 0.2) return 'strong semantic signal'
  if (percentile <= 0.5) return 'moderate semantic signal'
  return 'loose semantic signal'
}

function getQueryStringParam(value: unknown) {
  return typeof value === 'string' ? value : ''
}

function getQueryNumberParam(value: unknown) {
  const raw = getQueryStringParam(value)
  if (!raw) {
    return ''
  }

  const parsed = Number.parseInt(raw, 10)
  return Number.isNaN(parsed) ? '' : parsed
}

function getBillTypeChamber(code: string) {
  return BILL_TYPE_OPTIONS.find(option => option.code === code)?.chamber || 'house'
}

function firstBillTypeForChamber(chamber: 'house' | 'senate') {
  return chamber === 'senate' ? 's' : 'hr'
}

function normalizeStatus(value: unknown) {
  return getQueryStringParam(value).toLowerCase()
}

function buildBillQuery(query?: string, sort?: string) {
  const nextQuery: Record<string, string | number> = {}

  // Search text and sort mode
  if (query) {
    nextQuery.query = query
  }

  if (sort) {
    nextQuery.sort = sort
  }

  // Congress range and chamber (chamber is suppressed during free-text search
  // because semantic results span all chambers)
  if (selectedCongress.value) {
    nextQuery.congress = selectedCongress.value
  }
  if (!query) {
    nextQuery.chamber = selectedChamber.value
  }

  // Bill type / status filters
  if (filterPolicyArea.value) {
    nextQuery.policyArea = filterPolicyArea.value
  }

  if (selectedStatus.value) {
    nextQuery.status = selectedStatus.value
  }

  // Cosponsor filter
  if (selectedSponsorParty.value) {
    nextQuery.party = selectedSponsorParty.value
  }

  // Committee filter
  if (selectedCommittee.value) {
    nextQuery.committee = selectedCommittee.value
  }

  // Sort order and date-range refinements
  if (filterMonth.value) {
    nextQuery.month = filterMonth.value
  }

  if (filterMinCosponsors.value !== '') {
    nextQuery.minCosponsors = filterMinCosponsors.value
  }

  return nextQuery
}

function billQueryMatchesRoute() {
  return getQueryStringParam(route.query.policyArea) === filterPolicyArea.value
    && getQueryStringParam(route.query.party) === selectedSponsorParty.value
    && getQueryStringParam(route.query.congress) === selectedCongress.value
    && getQueryStringParam(route.query.chamber) === selectedChamber.value
    && getQueryStringParam(route.query.status).toLowerCase() === selectedStatus.value
    && getQueryStringParam(route.query.committee) === selectedCommittee.value
    && getQueryStringParam(route.query.month) === filterMonth.value
    && getQueryNumberParam(route.query.minCosponsors) === filterMinCosponsors.value
    && getQueryStringParam(route.query.query) === searchQuery.value
    && getQueryStringParam(route.query.sort) === selectedSort.value
}

function syncBillFacetsFromRoute() {
  selectedCongress.value = getQueryStringParam(route.query.congress)
  selectedChamber.value = (getQueryStringParam(route.query.chamber) as 'house' | 'senate')
    || (getBillTypeChamber(selectedCategory.value) as 'house' | 'senate')
    || 'house'
  filterPolicyArea.value = getQueryStringParam(route.query.policyArea)
  selectedStatus.value = normalizeStatus(route.query.status)
  selectedSponsorParty.value = getQueryStringParam(route.query.party)
  selectedCommittee.value = getQueryStringParam(route.query.committee)
  filterMonth.value = getQueryStringParam(route.query.month)
  filterMinCosponsors.value = getQueryNumberParam(route.query.minCosponsors)
}

const availablePolicyAreas = computed(() => {
  const areas = new Set(bills.value.map(b => b.policy_area).filter(Boolean))
  return Array.from(areas).sort() as string[]
})

const availableParties = computed(() => {
  const parties = new Set(bills.value.map(b => b.sponsor_party).filter(Boolean))
  return Array.from(parties).sort() as string[]
})

const availableMonths = computed(() => {
  const months = new Set<string>()
  bills.value.forEach(b => {
    if (b.introducedat) {
      const match = b.introducedat.match(/^(\d{4}-\d{2})/)
      if (match && match[1]) months.add(match[1])
    }
  })
  return Array.from(months).sort().reverse()
})

const availableCongresses = computed(() => {
  const congresses = new Set<string>()
  bills.value.forEach(b => {
    if (b.congress) {
      congresses.add(String(b.congress))
    }
  })
  return Array.from(congresses).sort((a, b) => Number(b) - Number(a))
})

const availableStatuses = computed(() => {
  const statuses = new Set<string>()
  bills.value.forEach(b => {
    if (b.bill_status) {
      statuses.add(b.bill_status)
    }
  })
  return Array.from(statuses).sort()
})

const availableBillTypeGroups = computed(() => {
  return [
    {
      label: selectedChamber.value === 'house' ? 'House bills' : 'Senate bills',
      options: BILL_TYPE_OPTIONS.filter(option => option.chamber === selectedChamber.value),
    },
  ]
})

const availableCommittees = computed(() => {
  const chamberFiltered = committeeOptions.value.filter((committee) => {
    if (!selectedChamber.value) {
      return true
    }
    return String(committee.chamber || '').toLowerCase() === selectedChamber.value
  })

  return chamberFiltered
    .slice()
    .sort((a, b) => String(a.committee_name || a.committee_code).localeCompare(String(b.committee_name || b.committee_code)))
})

const filteredBills = computed(() => {
  return bills.value.filter(b => {
    if (selectedCongress.value && String(b.congress) !== selectedCongress.value) return false
    if (!searchQuery.value && selectedChamber.value && getBillTypeChamber(b.billtype) !== selectedChamber.value) return false
    if (selectedStatus.value && String(b.bill_status || '').toLowerCase() !== selectedStatus.value) return false
    if (filterPolicyArea.value && b.policy_area !== filterPolicyArea.value) return false
    if (selectedSponsorParty.value && b.sponsor_party !== selectedSponsorParty.value) return false
    if (selectedCommittee.value && !(b.committee_codes || []).includes(selectedCommittee.value)) return false
    if (filterMonth.value && (!b.introducedat || !b.introducedat.startsWith(filterMonth.value))) return false
    if (filterMinCosponsors.value !== '' && (b.cosponsor_count || 0) < filterMinCosponsors.value) return false
    return true
  })
})

// Chamber is intentionally excluded: it always has a value (house/senate), so
// counting it would make the facet count read "1 active" before any real filter.
const activeFacetCount = computed(() => [
  selectedCongress.value !== '',
  selectedStatus.value !== '',
  filterPolicyArea.value !== '',
  selectedSponsorParty.value !== '',
  selectedCommittee.value !== '',
  filterMonth.value !== '',
  filterMinCosponsors.value !== '',
].filter(Boolean).length)

function dateValue(value: string | null | undefined) {
  if (!value) {
    return 0
  }

  const time = new Date(value).getTime()
  return Number.isNaN(time) ? 0 : time
}

function billSortDate(bill: BillRecord) {
  return Math.max(
    dateValue(bill.latest_action_date),
    dateValue(bill.statusat),
    dateValue(bill.introducedat),
  )
}

const sortedBills = computed(() => {
  if (selectedSort.value === 'date') {
    return [...filteredBills.value].sort((a, b) => {
      const diff = billSortDate(b) - billSortDate(a)
      return sortDesc.value ? diff : -diff
    })
  }

  return sortDesc.value ? filteredBills.value : [...filteredBills.value].reverse()
})


const totalPages = computed(() => Math.ceil(sortedBills.value.length / PAGE_SIZE))

const pagedBills = computed(() => {
  const start = (currentPage.value - 1) * PAGE_SIZE
  return sortedBills.value.slice(start, start + PAGE_SIZE)
})

const selectedCategory = computed(() => {
  const value = typeof route.params.category === 'string' ? route.params.category : 'hr'
  return BILL_TYPE_OPTIONS.find(option => option.code === value)?.code || 'hr'
})

const selectedSort = computed(() => {
  // Semantic search defaults to relevance (its ranking is the point); browsing
  // the latest bills defaults to date.
  const fallback = searchQuery.value ? 'relevance' : 'date'
  const value = typeof route.query.sort === 'string' ? route.query.sort : fallback
  return BILL_FILTER_OPTIONS.find(option => option.value === value)?.value || fallback
})

const searchQuery = computed(() => typeof route.query.query === 'string' ? route.query.query.trim() : '')
const categoryMeta = computed(() => BILL_TYPE_OPTIONS.find(option => option.code === selectedCategory.value) || BILL_TYPE_OPTIONS[0]!)
const categoryShortLabel = computed(() => {
  return categoryMeta.value.shortLabel
})
const categoryLabel = computed(() => {
  return categoryMeta.value.longLabel
})

const headline = computed(() => {
  return searchQuery.value
    ? 'Bill search'
    : `Latest ${categoryLabel.value.toLowerCase()}`
})

function getBillRoute(code: string, query?: string, sort?: string) {
  return {
    path: `/bills/${code}`,
    query: buildBillQuery(query, sort),
  }
}

async function navigateBillType(code: string) {
  isUpdatingBillRoute.value = true
  selectedChamber.value = getBillTypeChamber(code) as 'house' | 'senate'

  try {
    await router.replace({
      path: `/bills/${code}`,
      query: buildBillQuery(searchQuery.value || undefined, selectedSort.value),
    })
  }
  finally {
    isUpdatingBillRoute.value = false
  }
}

async function navigateBillChamber(chamber: 'house' | 'senate') {
  await navigateBillType(firstBillTypeForChamber(chamber))
}

function formatStatusLabel(value: string) {
  return value
    .split(/[_:-]+/)
    .filter(Boolean)
    .map(part => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ')
}

function formatMonthLabel(yyyyMm: string) {
  const [yyyy, mm] = yyyyMm.split('-')
  const date = new Date(Number(yyyy), Number(mm) - 1, 1)
  return new Intl.DateTimeFormat('en-US', { month: 'long', year: 'numeric' }).format(date)
}


function estimatePayloadBytes(rows: BillRecord[]) {
  return new TextEncoder().encode(JSON.stringify(rows)).length
}

function formatByteCount(bytes: number | null) {
  if (bytes == null || Number.isNaN(bytes)) {
    return '—'
  }

  if (bytes < 1024) {
    return `${bytes} B`
  }

  if (bytes < 1024 * 1024) {
    return `${(bytes / 1024).toFixed(1)} KB`
  }

  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}

async function loadBills() {
  loading.value = true
  loadProgress.value = 8
  loadBytes.value = null
  errorMessage.value = ''

  const progressTimer = import.meta.client
    ? window.setInterval(() => {
        if (!loading.value) {
          return
        }

        loadProgress.value = Math.min(90, loadProgress.value + Math.max(1, Math.round((100 - loadProgress.value) / 12)))
      }, 300)
    : null

  try {
    if (!searchQuery.value) {
      const rows = await latestBills(selectedCategory.value)
      bills.value = rows
      loadBytes.value = estimatePayloadBytes(rows)
      return
    }

    const rows = await semanticSearch(searchQuery.value)
    bills.value = rows
    loadBytes.value = estimatePayloadBytes(rows)
  }
  catch (error: any) {
    bills.value = []
    errorMessage.value = error?.data?.error || error?.message || 'Unable to load bills right now.'
  }
  finally {
    loading.value = false
    loadProgress.value = 100
    if (progressTimer != null) {
      window.clearInterval(progressTimer)
    }
  }
}

async function submitSearch() {
  const query = draftQuery.value.trim()
  await router.push(getBillRoute(selectedCategory.value, query || undefined, selectedSort.value))
}

// Two separate watchers are needed because the data flow is bidirectional:
// - The route watcher (below) syncs URL → component state, triggering a data
//   reload whenever the browser URL changes (navigation, back/forward, deep links).
// - The filter watcher (further below) syncs component state → URL, pushing a
//   new URL whenever the user changes a filter, which in turn fires the route watcher.
// Collapsing them into one watcher would create update loops or miss one direction.
watch(
  () => [
    selectedCategory.value,
    selectedSort.value,
    searchQuery.value,
    route.query.congress,
    route.query.chamber,
    route.query.policyArea,
    route.query.party,
    route.query.status,
    route.query.committee,
    route.query.month,
    route.query.minCosponsors,
  ],
  () => {
    draftQuery.value = searchQuery.value
    syncBillFacetsFromRoute()
    currentPage.value = 1
    loadBills()
  },
  { immediate: true },
)

watch(
  [
    selectedCongress,
    selectedChamber,
    selectedStatus,
    selectedSponsorParty,
    selectedCommittee,
    filterPolicyArea,
    filterMonth,
    filterMinCosponsors,
    selectedSort,
  ],
  async () => {
    if (isUpdatingBillRoute.value) {
      return
    }

    currentPage.value = 1
    if (billQueryMatchesRoute()) {
      return
    }

    await router.replace({
      path: `/bills/${selectedCategory.value}`,
      query: buildBillQuery(searchQuery.value || undefined, selectedSort.value),
    })
  },
)

// ── Presentational helpers for Nuxt UI components ──
// Nuxt UI's Select forbids an empty-string item value, so an "Any" sentinel
// stands in for the no-filter state ('') used by the page logic.
const ANY = '__any__'

function anyModel(target: Ref<string>) {
  return computed<string>({
    get: () => (target.value === '' ? ANY : target.value),
    set: (value) => { target.value = value === ANY ? '' : value },
  })
}

const congressModel = anyModel(selectedCongress)
const policyAreaModel = anyModel(filterPolicyArea)
const statusModel = anyModel(selectedStatus)
const partyModel = anyModel(selectedSponsorParty)
const committeeModel = anyModel(selectedCommittee)
const monthModel = anyModel(filterMonth)

const congressItems = computed(() => [
  { label: 'Any congress', value: ANY },
  ...availableCongresses.value.map(c => ({ label: c, value: c })),
])
const billTypeItems = computed(() =>
  availableBillTypeGroups.value.flatMap(group =>
    group.options.map(option => ({ label: option.shortLabel, value: option.code })),
  ),
)
const policyAreaItems = computed(() => [
  { label: 'All topics', value: ANY },
  ...availablePolicyAreas.value.map(area => ({ label: area, value: area })),
])
const statusItems = computed(() => [
  { label: 'Any status', value: ANY },
  ...availableStatuses.value.map(status => ({ label: formatStatusLabel(status), value: status })),
])
const partyItems = computed(() => [
  { label: 'Any party', value: ANY },
  ...availableParties.value.map(party => ({ label: party, value: party })),
])
const committeeItems = computed(() => [
  { label: 'Any committee', value: ANY },
  ...availableCommittees.value.map(committee => ({
    label: committee.committee_name || committee.committee_code,
    value: committee.committee_code,
  })),
])
const monthItems = computed(() => [
  { label: 'Any month', value: ANY },
  ...availableMonths.value.map(month => ({ label: formatMonthLabel(month), value: month })),
])
const sortItems = BILL_FILTER_OPTIONS.map(option => ({ label: option.label, value: option.value }))

function onSortChange(value: string) {
  router.replace(getBillRoute(selectedCategory.value, searchQuery.value || undefined, value))
}

// Reset every optional facet (chamber/bill type/sort are navigation, left alone).
function clearFilters() {
  selectedCongress.value = ''
  filterPolicyArea.value = ''
  selectedStatus.value = ''
  selectedSponsorParty.value = ''
  selectedCommittee.value = ''
  filterMonth.value = ''
  filterMinCosponsors.value = ''
}

// Map the semantic relevance tone to a Nuxt UI badge color.
function semanticBadgeColor(index: number, total: number): 'success' | 'info' | 'error' | 'neutral' {
  if (total <= 0) return 'neutral'
  const percentile = (index + 1) / total
  if (percentile <= 0.2) return 'success'
  if (percentile <= 0.5) return 'info'
  return 'error'
}

usePageSeo({
  title: () => headline.value,
  description: () => (searchQuery.value
    ? `Semantic search results for "${searchQuery.value}" across U.S. Congress legislation.`
    : `Browse the latest ${categoryLabel.value.toLowerCase()} in the U.S. Congress.`),
})
</script>

<template>
  <UContainer class="space-y-8">
    <UCard>
      <div class="space-y-6">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <p class="text-xs font-medium uppercase tracking-[0.2em] text-primary">Bill routes</p>
            <h1 class="mt-2 text-2xl font-semibold tracking-tight text-highlighted sm:text-3xl">{{ headline }}</h1>
            <p class="mt-1 text-muted">{{ searchQuery ? 'Ranked by semantic similarity across all congresses.' : 'Browse or search legislation by type.' }}</p>
          </div>

          <UFieldGroup v-if="!searchQuery">
            <UButton
              v-for="option in VOTE_CHAMBER_OPTIONS"
              :key="option.value"
              :color="option.value === selectedChamber ? 'primary' : 'neutral'"
              :variant="option.value === selectedChamber ? 'subtle' : 'outline'"
              @click="navigateBillChamber(option.value)"
            >
              {{ option.label }}
            </UButton>
          </UFieldGroup>
        </div>

        <div class="space-y-3">
        <form class="flex flex-col gap-3 sm:flex-row sm:items-end" @submit.prevent="submitSearch">
          <UFormField :label="`Search within ${categoryMeta.longLabel.toLowerCase()}`" class="flex-1">
            <UInput
              v-model="draftQuery"
              type="search"
              icon="i-lucide-search"
              size="lg"
              placeholder="Search titles, summaries, or legislative phrases"
              class="w-full"
            />
          </UFormField>
          <UButton type="submit" color="primary" variant="subtle" size="lg" class="justify-center">
            {{ draftQuery.trim() ? 'Run bill search' : 'Load latest bills' }}
          </UButton>
        </form>

        <UCollapsible>
          <UButton
            color="neutral"
            variant="outline"
            block
            size="lg"
            trailing-icon="i-lucide-chevron-down"
            class="justify-between"
          >
            <span>Refine results</span>
            <span class="text-muted">{{ activeFacetCount ? `(${activeFacetCount} active)` : 'Optional filters' }}</span>
          </UButton>

          <template #content>
            <div class="grid grid-cols-1 gap-4 pt-4 sm:grid-cols-2 lg:grid-cols-4">
              <UFormField label="Congress">
                <USelect v-model="congressModel" :items="congressItems" class="w-full" />
              </UFormField>

              <UFormField label="Bill type">
                <USelect
                  :model-value="selectedCategory"
                  :items="billTypeItems"
                  class="w-full"
                  @update:model-value="navigateBillType($event as string)"
                />
              </UFormField>

              <UFormField label="Policy area">
                <USelect v-model="policyAreaModel" :items="policyAreaItems" class="w-full" />
              </UFormField>

              <UFormField label="Status">
                <USelect v-model="statusModel" :items="statusItems" class="w-full" />
              </UFormField>

              <UFormField label="Sponsor party">
                <USelect v-model="partyModel" :items="partyItems" class="w-full" />
              </UFormField>

              <UFormField label="Committee" class="sm:col-span-2">
                <USelectMenu
                  v-model="committeeModel"
                  :items="committeeItems"
                  value-key="value"
                  class="w-full"
                />
              </UFormField>

              <UFormField label="Sort mode">
                <USelect
                  :model-value="selectedSort"
                  :items="sortItems"
                  class="w-full"
                  @update:model-value="onSortChange($event as string)"
                />
              </UFormField>

              <UFormField label="Introduced month">
                <USelect v-model="monthModel" :items="monthItems" class="w-full" />
              </UFormField>

              <UFormField label="Min cosponsors">
                <UInput v-model.number="filterMinCosponsors" type="number" :min="0" placeholder="e.g. 5" class="w-full" />
              </UFormField>
            </div>

            <div v-if="activeFacetCount" class="flex justify-end pt-4">
              <UButton color="neutral" variant="ghost" size="xs" icon="i-lucide-x" @click="clearFilters">
                Clear filters
              </UButton>
            </div>
          </template>
        </UCollapsible>
        </div>
      </div>
    </UCard>

    <UAlert v-if="errorMessage" color="error" variant="subtle" icon="i-lucide-circle-alert" :description="errorMessage" />

    <UCard v-else-if="loading">
      <div class="space-y-3">
        <div class="flex items-center justify-between text-sm">
          <span>Loading bills</span>
          <span class="text-muted">{{ loadProgress }}%</span>
        </div>
        <UProgress v-model="loadProgress" :max="100" />
        <p class="text-sm text-muted">Downloaded {{ formatByteCount(loadBytes) }}</p>
      </div>
    </UCard>

    <UCard v-else-if="!bills.length">
      <p class="text-muted">No bills matched this route and parameter set.</p>
    </UCard>

    <div v-else class="space-y-4">
      <p class="text-sm text-muted">
        {{ formatNumber(filteredBills.length) }} {{ filteredBills.length === 1 ? 'result' : 'results' }}
      </p>
      <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
      <UCard v-for="(bill, index) in pagedBills" :key="bill.billid">
        <div class="space-y-4">
          <div>
            <div class="flex flex-wrap items-center gap-2 text-xs uppercase tracking-[0.15em] text-primary">
              <span>{{ bill.billtype.toUpperCase() }} {{ bill.billnumber || '—' }} · Congress {{ bill.congress || '—' }}</span>
              <UBadge
                v-if="bill.similarity != null"
                :color="semanticBadgeColor((currentPage - 1) * PAGE_SIZE + index, sortedBills.length)"
                variant="subtle"
                size="sm"
              >
                {{ formatSemanticScore(bill.similarity) }} · {{ semanticRankLabel((currentPage - 1) * PAGE_SIZE + index, sortedBills.length) }}
              </UBadge>
            </div>
            <NuxtLink
              :to="`/bills/${bill.billtype}/${bill.congress}/${bill.billnumber}`"
              class="mt-2 block text-lg font-medium text-highlighted transition-colors hover:text-primary"
            >
              {{ bill.shorttitle || bill.officialtitle || 'Untitled bill' }}
            </NuxtLink>
          </div>

          <p class="text-sm text-muted">
            {{ summarizeText(bill.summary_text || bill.officialtitle || bill.shorttitle, 260) }}
          </p>

          <dl class="grid grid-cols-2 gap-x-6 gap-y-3 text-sm">
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Introduced</dt>
              <dd class="mt-0.5">{{ formatDate(bill.introducedat) }}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Status</dt>
              <dd class="mt-0.5">{{ formatDate(bill.statusat) }}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Sponsor</dt>
              <dd class="mt-0.5">
                {{ bill.sponsor_name || '—' }}
                <span v-if="bill.sponsor_party" class="text-muted">({{ bill.sponsor_party }})</span>
              </dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">State</dt>
              <dd class="mt-0.5">{{ bill.sponsor_state || '—' }}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Cosponsors</dt>
              <dd class="mt-0.5">{{ formatNumber(bill.cosponsor_count || 0) }}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Last action</dt>
              <dd class="mt-0.5">{{ formatDate(bill.latest_action_date) }}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Policy area</dt>
              <dd class="mt-0.5">{{ bill.policy_area || '—' }}</dd>
            </div>
          </dl>
        </div>
      </UCard>
      </div>
    </div>

    <div v-if="totalPages > 1" class="flex justify-center">
      <UPagination
        v-model:page="currentPage"
        :total="sortedBills.length"
        :items-per-page="PAGE_SIZE"
      />
    </div>
  </UContainer>
</template>
