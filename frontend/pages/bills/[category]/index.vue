<script setup lang="ts">
import { BILL_FILTER_OPTIONS, BILL_TYPE_OPTIONS } from '~/types/congress'
import type { BillRecord } from '~/types/congress'

const route = useRoute()
const router = useRouter()
const { latestBills, searchBills } = useCongressApi()

const PAGE_SIZE = 100

const loading = ref(false)
const errorMessage = ref('')
const bills = ref<BillRecord[]>([])
const draftQuery = ref('')
const sortDesc = ref(true)
const currentPage = ref(1)

const filterPolicyArea = ref('')
const filterParty = ref('')
const filterMonth = ref('')
const filterMinCosponsors = ref<number | ''>('')

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

const filteredBills = computed(() => {
  return bills.value.filter(b => {
    if (filterPolicyArea.value && b.policy_area !== filterPolicyArea.value) return false
    if (filterParty.value && b.sponsor_party !== filterParty.value) return false
    if (filterMonth.value && (!b.introducedat || !b.introducedat.startsWith(filterMonth.value))) return false
    if (filterMinCosponsors.value !== '' && (b.cosponsor_count || 0) < filterMinCosponsors.value) return false
    return true
  })
})

const sortedBills = computed(() =>
  sortDesc.value ? filteredBills.value : [...filteredBills.value].reverse(),
)


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

const headline = computed(() => {
  return searchQuery.value
    ? `${categoryMeta.value.longLabel} search`
    : `Latest ${categoryMeta.value.longLabel.toLowerCase()}`
})

const totalCosponsors = computed(() => {
  return filteredBills.value.reduce((sum, bill) => sum + (bill.cosponsor_count || 0), 0)
})

const withSummaries = computed(() => filteredBills.value.filter(bill => bill.summary_text).length)
const withPolicyArea = computed(() => filteredBills.value.filter(bill => bill.policy_area).length)

function getBillRoute(code: string, query?: string, sort?: string) {
  return {
    path: `/bills/${code}`,
    query: query ? { query, sort } : {},
  }
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

function billGovTrackUrl(bill: BillRecord) {
  return `https://www.govtrack.us/congress/bills/${bill.congress}/${bill.billtype}${bill.billnumber}`
}

async function loadBills() {
  loading.value = true
  errorMessage.value = ''

  try {
    bills.value = searchQuery.value
      ? await searchBills(selectedCategory.value, selectedSort.value, searchQuery.value)
      : await latestBills(selectedCategory.value)
  }
  catch (error: any) {
    bills.value = []
    errorMessage.value = error?.data?.error || error?.message || 'Unable to load bills right now.'
  }
  finally {
    loading.value = false
  }
}

async function submitSearch() {
  const query = draftQuery.value.trim()
  await router.push(getBillRoute(selectedCategory.value, query || undefined, selectedSort.value))
}

watch(
  () => [selectedCategory.value, selectedSort.value, searchQuery.value],
  () => {
    draftQuery.value = searchQuery.value
    currentPage.value = 1
    filterPolicyArea.value = ''
    filterParty.value = ''
    filterMonth.value = ''
    filterMinCosponsors.value = ''
    loadBills()
  },
  { immediate: true },
)

watch([sortDesc, filterPolicyArea, filterParty, filterMonth, filterMinCosponsors], () => { currentPage.value = 1 })
</script>

<template>
  <main class="page page--wide">
    <section class="surface">
      <div class="toolbar">
        <div>
          <p class="eyebrow">Bill routes</p>
          <h1>{{ headline }}</h1>
          <p class="lede">
            This screen uses both bill endpoints from `congress_api`: `/latest/:billtype` for fresh activity and
            `/search/:table/:filter` for ranked or date-sorted text search.
          </p>
        </div>

        <div class="pill-row">
          <NuxtLink
            v-for="option in BILL_TYPE_OPTIONS"
            :key="option.code"
            :to="getBillRoute(option.code, searchQuery || undefined, selectedSort)"
            class="pill"
            :class="{ 'pill--active': option.code === selectedCategory }"
          >
            {{ option.shortLabel }}
          </NuxtLink>
        </div>
      </div>

      <form class="control-grid" @submit.prevent="submitSearch">
        <label class="field field--full">
          <span>Search within {{ categoryMeta.longLabel.toLowerCase() }}</span>
          <input
            v-model="draftQuery"
            class="field-input"
            type="search"
            placeholder="Search titles, summaries, or legislative phrases"
          >
        </label>

        <label class="field">
          <span>Sort mode</span>
          <select
            :value="selectedSort"
            class="field-input"
            @change="router.push(getBillRoute(selectedCategory, searchQuery || undefined, ($event.target as HTMLSelectElement).value))"
          >
            <option v-for="option in BILL_FILTER_OPTIONS" :key="option.value" :value="option.value">
              {{ option.label }}
            </option>
          </select>
        </label>

        <label class="field">
          <span>Policy area</span>
          <select v-model="filterPolicyArea" class="field-input">
            <option value="">All topics...</option>
            <option v-for="area in availablePolicyAreas" :key="area" :value="area">{{ area }}</option>
          </select>
        </label>

        <label class="field">
          <span>Sponsor party</span>
          <select v-model="filterParty" class="field-input">
            <option value="">All parties...</option>
            <option v-for="party in availableParties" :key="party" :value="party">{{ party }}</option>
          </select>
        </label>

        <label class="field">
          <span>Introduced month</span>
          <select v-model="filterMonth" class="field-input">
            <option value="">Any month...</option>
            <option v-for="month in availableMonths" :key="month" :value="month">{{ formatMonthLabel(month) }}</option>
          </select>
        </label>

        <label class="field">
          <span>Min cosponsors</span>
          <input v-model.number="filterMinCosponsors" class="field-input" type="number" placeholder="e.g. 5" min="0">
        </label>

        <button class="button button--primary" type="submit" style="align-self: end">
          {{ draftQuery.trim() ? 'Run bill search' : 'Load latest bills' }}
        </button>
      </form>
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
      Loading bills...
    </section>

    <section v-else-if="!bills.length" class="surface">
      No bills matched this route and parameter set.
    </section>

    <section v-else class="result-grid">
      <article v-for="bill in pagedBills" :key="bill.billid" class="result-card">
        <div class="result-card__header">
          <div>
            <p class="result-card__meta">
              {{ categoryMeta.shortLabel }} {{ bill.billnumber || '—' }} · Congress {{ bill.congress || '—' }}
            </p>
            <h2>{{ bill.shorttitle || bill.officialtitle || 'Untitled bill' }}</h2>
          </div>

          <div class="result-card__links">
            <NuxtLink
              :to="`/bills/${bill.billtype}/${bill.congress}/${bill.billnumber}`"
              class="result-link result-link--primary"
            >
              Details →
            </NuxtLink>
            <a :href="billGovTrackUrl(bill)" target="_blank" rel="noopener noreferrer" class="result-link">
              GovTrack ↗
            </a>
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
