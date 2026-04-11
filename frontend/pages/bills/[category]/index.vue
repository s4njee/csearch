<script setup lang="ts">
import { BILL_FILTER_OPTIONS, BILL_TYPE_OPTIONS } from '~/types/congress'
import type { BillRecord, CommitteeRecord } from '~/types/congress'

const route = useRoute()
const router = useRouter()
const { latestBills, semanticSearch, getCommittees } = useCongressApi()
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

function semanticScoreLabel(score: number | null | undefined) {
  if (score == null || Number.isNaN(score)) {
    return ''
  }

  return 'loose semantic signal'
}

function semanticRankLabel(index: number, total: number) {
  if (total <= 0) {
    return ''
  }

  const percentile = (index + 1) / total
  if (percentile <= 0.2) return 'strong semantic signal'
  if (percentile <= 0.5) return 'moderate semantic signal'
  return 'loose semantic signal'
}

function semanticRankTone(index: number, total: number) {
  if (total <= 0) {
    return ''
  }

  const percentile = (index + 1) / total
  if (percentile <= 0.2) return 'similarity-badge--strong'
  if (percentile <= 0.5) return 'similarity-badge--moderate'
  return 'similarity-badge--loose'
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

  if (query) {
    nextQuery.query = query
  }

  if (sort) {
    nextQuery.sort = sort
  }

  if (selectedCongress.value) {
    nextQuery.congress = selectedCongress.value
  }
  if (!query) {
    nextQuery.chamber = selectedChamber.value
  }

  if (filterPolicyArea.value) {
    nextQuery.policyArea = filterPolicyArea.value
  }

  if (selectedStatus.value) {
    nextQuery.status = selectedStatus.value
  }

  if (selectedSponsorParty.value) {
    nextQuery.party = selectedSponsorParty.value
  }

  if (selectedCommittee.value) {
    nextQuery.committee = selectedCommittee.value
  }

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

const activeFacetCount = computed(() => [
  selectedCongress.value !== '',
  selectedChamber.value !== '',
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
  const value = typeof route.query.sort === 'string' ? route.query.sort : 'relevance'
  return BILL_FILTER_OPTIONS.find(option => option.value === value)?.value || 'relevance'
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

const totalCosponsors = computed(() => {
  return filteredBills.value.reduce((sum, bill) => sum + (bill.cosponsor_count || 0), 0)
})

const withSummaries = computed(() => filteredBills.value.filter(bill => bill.summary_text).length)
const withPolicyArea = computed(() => filteredBills.value.filter(bill => bill.policy_area).length)

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

function formatDate(value?: string | null) {
  if (!value) {
    return '—'
  }

  const date = new Date(value)
  if (Number.isNaN(date.getTime())) {
    return value
  }

  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  }).format(date)
}

function summarizeText(value?: string | null, limit = 260) {
  if (!value) {
    return 'Summary not available.'
  }

  return value.length > limit ? `${value.slice(0, limit).trim()}...` : value
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
</script>

<template>
  <main class="page page--wide">
    <section class="surface">
      <div class="toolbar">
        <div>
          <p class="eyebrow">Bill routes</p>
          <h1>{{ headline }}</h1>
          <p class="lede">{{ searchQuery ? 'Ranked by semantic similarity across all congresses.' : 'Browse or search legislation by type.' }}</p>
        </div>
      </div>

      <div class="control-grid control-grid--selectors">
        <label class="field field--compact">
          <span>Congress</span>
          <select v-model="selectedCongress" class="field-input">
            <option value="">Any congress</option>
            <option v-for="congress in availableCongresses" :key="congress" :value="congress">
              {{ congress }}
            </option>
          </select>
        </label>

        <label class="field field--compact">
          <span>Chamber</span>
          <select
            :value="searchQuery ? '' : selectedChamber"
            class="field-input"
            :disabled="Boolean(searchQuery)"
            @change="navigateBillChamber(($event.target as HTMLSelectElement).value as 'house' | 'senate')"
          >
            <option value="">Any</option>
            <option value="house">House</option>
            <option value="senate">Senate</option>
          </select>
        </label>

        <label class="field field--compact">
          <span>Bill type</span>
          <select
            :value="selectedCategory"
            class="field-input"
            @change="navigateBillType(($event.target as HTMLSelectElement).value)"
          >
            <optgroup
              v-for="group in availableBillTypeGroups"
              :key="group.label"
              :label="group.label"
            >
              <option v-for="option in group.options" :key="option.code" :value="option.code">
                {{ option.shortLabel }}
              </option>
            </optgroup>
          </select>
        </label>

        <label class="field field--compact">
          <span>Policy area</span>
          <select v-model="filterPolicyArea" class="field-input">
            <option value="">All topics</option>
            <option v-for="area in availablePolicyAreas" :key="area" :value="area">{{ area }}</option>
          </select>
        </label>

        <label class="field field--compact">
          <span>Status</span>
          <select v-model="selectedStatus" class="field-input">
            <option value="">Any status</option>
            <option v-for="status in availableStatuses" :key="status" :value="status">
              {{ formatStatusLabel(status) }}
            </option>
          </select>
        </label>

        <label class="field field--compact">
          <span>Sponsor party</span>
          <select v-model="selectedSponsorParty" class="field-input">
            <option value="">Any party</option>
            <option v-for="party in availableParties" :key="party" :value="party">{{ party }}</option>
          </select>
        </label>

        <label class="field field--compact">
          <span>Committee</span>
          <select v-model="selectedCommittee" class="field-input">
            <option value="">Any committee</option>
            <option v-for="committee in availableCommittees" :key="committee.committee_code" :value="committee.committee_code">
              {{ committee.committee_name || committee.committee_code }}
            </option>
          </select>
        </label>
      </div>

      <form class="control-grid control-grid--search" @submit.prevent="submitSearch">
        <label class="field field--full">
          <span>Search within {{ categoryMeta.longLabel.toLowerCase() }}</span>
          <input
            v-model="draftQuery"
            class="field-input"
            type="search"
            placeholder="Search titles, summaries, or legislative phrases"
          >
        </label>
        <button class="button button--primary" type="submit">
          {{ draftQuery.trim() ? 'Run bill search' : 'Load latest bills' }}
        </button>
      </form>

      <details class="facet-panel">
        <summary class="facet-panel__summary">
          <span>Refine results</span>
          <span class="facet-panel__meta">
            <span v-if="activeFacetCount">({{ activeFacetCount }} active)</span>
            <span v-else>Optional filters</span>
          </span>
        </summary>

        <div class="facet-panel__body">
        <label class="field">
          <span>Sort mode</span>
            <select
              :value="selectedSort"
              class="field-input"
              @change="router.replace(getBillRoute(selectedCategory, searchQuery || undefined, ($event.target as HTMLSelectElement).value))"
            >
              <option v-for="option in BILL_FILTER_OPTIONS" :key="option.value" :value="option.value">
                {{ option.label }}
              </option>
            </select>
          </label>

          <label class="field">
            <span>Introduced month</span>
            <select v-model="filterMonth" class="field-input">
              <option value="">Any month</option>
              <option v-for="month in availableMonths" :key="month" :value="month">{{ formatMonthLabel(month) }}</option>
            </select>
          </label>

          <label class="field">
            <span>Min cosponsors</span>
            <input v-model.number="filterMinCosponsors" class="field-input" type="number" placeholder="e.g. 5" min="0">
          </label>
        </div>
      </details>

    </section>

    <section class="summary-strip">
      <article class="summary-tile">
        <span>Rows</span>
        <strong>{{ filteredBills.length }}</strong>
      </article>
      <article class="summary-tile">
        <span>Showing</span>
        <strong>{{ (currentPage - 1) * PAGE_SIZE + 1 }}–{{ Math.min(currentPage * PAGE_SIZE, sortedBills.length) }}</strong>
      </article>
      <article class="summary-tile summary-tile--action" @click="sortDesc = !sortDesc">
        <span>Order</span>
        <strong>{{ sortDesc ? '↓ Newest first' : '↑ Oldest first' }}</strong>
      </article>
      <article class="summary-tile">
        <span>With summaries</span>
        <strong>{{ withSummaries }}</strong>
      </article>
      <article class="summary-tile">
        <span>Total cosponsors</span>
        <strong>{{ totalCosponsors }}</strong>
      </article>
      <article class="summary-tile">
        <span>With policy area</span>
        <strong>{{ withPolicyArea }}</strong>
      </article>
    </section>

    <section v-if="errorMessage" class="surface surface--error">
      {{ errorMessage }}
    </section>

    <section v-else-if="loading" class="surface">
      <div class="load-status">
        <div class="load-status__row">
          <span>Loading bills</span>
          <span>{{ loadProgress }}%</span>
        </div>
        <div class="load-status__bar" role="progressbar" aria-valuemin="0" aria-valuemax="100" :aria-valuenow="loadProgress">
          <div class="load-status__bar-fill" :style="{ width: `${loadProgress}%` }" />
        </div>
        <p class="load-status__meta">
          Downloaded {{ formatByteCount(loadBytes) }}
        </p>
      </div>
    </section>

    <section v-else-if="!bills.length" class="surface">
      No bills matched this route and parameter set.
    </section>

    <section v-else class="result-grid">
      <article v-for="(bill, index) in pagedBills" :key="bill.billid" class="result-card">
        <div class="result-card__header">
          <div>
            <p class="result-card__meta">
              {{ bill.billtype.toUpperCase() }} {{ bill.billnumber || '—' }} · Congress {{ bill.congress || '—' }}
              <span
                v-if="bill.similarity != null"
                class="similarity-badge"
                :class="semanticRankTone((currentPage - 1) * PAGE_SIZE + index, sortedBills.length)"
              >
                semantic score {{ formatSemanticScore(bill.similarity) }}
                <span class="similarity-badge__hint">
                  · {{ semanticRankLabel((currentPage - 1) * PAGE_SIZE + index, sortedBills.length) }}
                </span>
              </span>
            </p>
            <NuxtLink :to="`/bills/${bill.billtype}/${bill.congress}/${bill.billnumber}`" class="link-plain">
              <h2>{{ bill.shorttitle || bill.officialtitle || 'Untitled bill' }}</h2>
            </NuxtLink>
          </div>
        </div>

        <p class="result-card__summary">
          {{ summarizeText(bill.summary_text || bill.officialtitle || bill.shorttitle) }}
        </p>

        <dl class="detail-grid">
          <div>
            <dt>Introduced</dt>
            <dd>{{ formatDate(bill.introducedat) }}</dd>
          </div>
          <div>
            <dt>Status</dt>
            <dd>{{ formatDate(bill.statusat) }}</dd>
          </div>
          <div>
            <dt>Sponsor</dt>
            <dd>
              {{ bill.sponsor_name || '—' }}
              <span v-if="bill.sponsor_party">({{ bill.sponsor_party }})</span>
            </dd>
          </div>
          <div>
            <dt>State</dt>
            <dd>{{ bill.sponsor_state || '—' }}</dd>
          </div>
          <div>
            <dt>Cosponsors</dt>
            <dd>{{ bill.cosponsor_count || 0 }}</dd>
          </div>
          <div>
            <dt>Last action</dt>
            <dd>{{ formatDate(bill.latest_action_date) }}</dd>
          </div>
          <div>
            <dt>Policy area</dt>
            <dd>{{ bill.policy_area || '—' }}</dd>
          </div>
        </dl>
      </article>
    </section>

    <nav v-if="totalPages > 1" class="pagination">
      <button class="pagination__btn" :disabled="currentPage === 1" @click="currentPage--">
        ← Prev
      </button>
      <span class="pagination__info">Page {{ currentPage }} of {{ totalPages }}</span>
      <button class="pagination__btn" :disabled="currentPage === totalPages" @click="currentPage++">
        Next →
      </button>
    </nav>
  </main>
</template>
