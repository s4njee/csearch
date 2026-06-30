<script setup lang="ts">
import { VOTE_CHAMBER_OPTIONS } from '~/types/congress'
import type { VoteRecord } from '~/types/congress'

const route = useRoute()
const router = useRouter()
const { latestVotes, searchVotes } = useCongressApi()

const loading = ref(true)
const errorMessage = ref('')
const votes = ref<VoteRecord[]>([])
const draftQuery = ref('')
let loadSequence = 0

const filterOutcome = ref('')
const filterMargin = ref<number | ''>('')
const filterVoteType = ref('')
const filterMonth = ref('')

function getQueryStringParam(value: string | string[] | undefined | null) {
  return typeof value === 'string' ? value : ''
}

function getQueryNumberParam(value: string | string[] | undefined | null) {
  const raw = getQueryStringParam(value)
  if (!raw) {
    return ''
  }

  const parsed = Number.parseInt(raw, 10)
  return Number.isNaN(parsed) ? '' : parsed
}

function buildVoteQuery(query?: string, nextChamber = chamber.value) {
  const nextQuery: Record<string, string | number> = {
    chamber: nextChamber,
  }

  if (query) {
    nextQuery.q = query
  }

  if (filterOutcome.value) {
    nextQuery.outcome = filterOutcome.value
  }

  if (filterVoteType.value) {
    nextQuery.voteType = filterVoteType.value
  }

  if (filterMonth.value) {
    nextQuery.month = filterMonth.value
  }

  if (filterMargin.value !== '') {
    nextQuery.maxMargin = filterMargin.value
  }

  return nextQuery
}

function syncVoteFacetsFromRoute() {
  filterOutcome.value = getQueryStringParam(route.query.outcome)
  filterVoteType.value = getQueryStringParam(route.query.voteType)
  filterMonth.value = getQueryStringParam(route.query.month)
  filterMargin.value = getQueryNumberParam(route.query.maxMargin)
}

function voteQueryMatchesRoute() {
  return getQueryStringParam(route.query.chamber).toLowerCase() === chamber.value
    && getQueryStringParam(route.query.q) === searchQuery.value
    && getQueryStringParam(route.query.outcome) === filterOutcome.value
    && getQueryStringParam(route.query.voteType) === filterVoteType.value
    && getQueryStringParam(route.query.month) === filterMonth.value
    && getQueryNumberParam(route.query.maxMargin) === filterMargin.value
}

const filteredVotes = computed(() => {
  return votes.value.filter(v => {
    if (filterOutcome.value === 'passed' && !isPassedResult(v.result)) return false
    if (filterOutcome.value === 'failed' && isPassedResult(v.result)) return false
    if (filterVoteType.value && v.votetype !== filterVoteType.value) return false
    if (filterMonth.value && (!v.votedate || !v.votedate.startsWith(filterMonth.value))) return false
    
    if (filterMargin.value !== '') {
      const yea = toCount(v.yea_count ?? v.yea)
      const nay = toCount(v.nay_count ?? v.nay)
      if (yea === 0 && nay === 0) return false
      const margin = Math.abs(yea - nay)
      if (margin > filterMargin.value) return false
    }
    return true
  })
})

const activeFacetCount = computed(() => [
  filterOutcome.value !== '',
  filterVoteType.value !== '',
  filterMonth.value !== '',
  filterMargin.value !== '',
].filter(Boolean).length)

const availableVoteTypes = computed(() => {
  const types = new Set(votes.value.map(v => v.votetype).filter(Boolean))
  return Array.from(types).sort() as string[]
})

const availableMonths = computed(() => {
  const months = new Set<string>()
  votes.value.forEach(v => {
    if (v.votedate) {
      const match = v.votedate.match(/^(\d{4}-\d{2})/)
      if (match && match[1]) months.add(match[1])
    }
  })
  return Array.from(months).sort().reverse()
})

const chamber = computed<'house' | 'senate'>(() => {
  const raw = typeof route.query.chamber === 'string' ? route.query.chamber.toLowerCase() : 'house'
  return raw === 'senate' ? 'senate' : 'house'
})

const chamberLabel = computed(() => chamber.value === 'house' ? 'House' : 'Senate')
const searchQuery = computed(() => typeof route.query.q === 'string' ? route.query.q.trim() : '')
const heading = computed(() => searchQuery.value ? `${chamberLabel.value} vote search` : `Latest ${chamberLabel.value} votes`)

const passedCount = computed(() => filteredVotes.value.filter(vote => isPassedResult(vote.result)).length)
const closestMargin = computed(() => {
  const margins = filteredVotes.value
    .map((vote) => {
      const yea = toCount(vote.yea_count ?? vote.yea)
      const nay = toCount(vote.nay_count ?? vote.nay)
      if (yea === 0 && nay === 0) {
        return null
      }
      return Math.abs(yea - nay)
    })
    .filter((value): value is number => value !== null)

  return margins.length ? String(Math.min(...margins)) : '—'
})

function voteRoute(nextChamber: 'house' | 'senate', nextQuery?: string) {
  return {
    path: '/votes',
    query: buildVoteQuery(nextQuery, nextChamber),
  }
}

function toCount(value: string | number | null | undefined) {
  const parsed = Number.parseInt(String(value ?? '0'), 10)
  return Number.isNaN(parsed) ? 0 : parsed
}

function isPassedResult(result: string | null | undefined) {
  const normalized = String(result || '').toLowerCase()
  return normalized.includes('passed')
    || normalized.includes('agreed')
    || normalized.includes('confirmed')
    || normalized.includes('approved')
    || normalized.includes('adopted')
    || normalized.includes('accepted')
    || normalized.includes('ratified')
}


function formatMonthLabel(yyyyMm: string) {
  const [yyyy, mm] = yyyyMm.split('-')
  const date = new Date(Number(yyyy), Number(mm) - 1, 1)
  return new Intl.DateTimeFormat('en-US', { month: 'long', year: 'numeric' }).format(date)
}

const { formatDate } = useFormatters()

async function loadVotes() {
  const sequence = ++loadSequence
  loading.value = true
  errorMessage.value = ''

  try {
    let nextVotes: VoteRecord[]
    if (searchQuery.value) {
      const payload = await searchVotes({
        q: searchQuery.value,
        chamber: chamber.value,
        limit: 24,
      })
      nextVotes = payload.results as unknown as VoteRecord[]
    }
    else {
      nextVotes = await latestVotes(chamber.value)
    }

    if (sequence === loadSequence) {
      votes.value = nextVotes
    }
  }
  catch (error: any) {
    if (sequence === loadSequence) {
      votes.value = []
      errorMessage.value = error?.data?.message || error?.message || 'Unable to load votes right now.'
    }
  }
  finally {
    if (sequence === loadSequence) {
      loading.value = false
    }
  }
}

async function submitSearch() {
  const query = draftQuery.value.trim()
  await router.push(voteRoute(chamber.value, query || undefined))
}

draftQuery.value = searchQuery.value
syncVoteFacetsFromRoute()

watch(
  () => [
    chamber.value,
    searchQuery.value,
  ],
  () => {
    draftQuery.value = searchQuery.value
    loadVotes()
  },
  { immediate: true },
)

watch(
  () => [
    route.query.outcome,
    route.query.voteType,
    route.query.month,
    route.query.maxMargin,
  ],
  syncVoteFacetsFromRoute,
)

watch([filterOutcome, filterVoteType, filterMonth, filterMargin], async () => {
  if (voteQueryMatchesRoute()) {
    return
  }

  await router.replace(voteRoute(chamber.value, searchQuery.value || undefined))
})

// ── Presentational helpers for Nuxt UI components ──
// Nuxt UI's Select forbids an empty-string item value; an "Any" sentinel stands
// in for the no-filter state ('') the page logic uses.
const ANY = '__any__'

function anyModel(target: Ref<string>) {
  return computed<string>({
    get: () => (target.value === '' ? ANY : target.value),
    set: (value) => { target.value = value === ANY ? '' : value },
  })
}

const outcomeModel = anyModel(filterOutcome)
const voteTypeModel = anyModel(filterVoteType)
const monthModel = anyModel(filterMonth)

const outcomeItems = [
  { label: 'Any result', value: ANY },
  { label: 'Passed / Agreed', value: 'passed' },
  { label: 'Failed / Rejected', value: 'failed' },
]
const voteTypeItems = computed(() => [
  { label: 'Any type', value: ANY },
  ...availableVoteTypes.value.map(vt => ({ label: vt, value: vt })),
])
const monthItems = computed(() => [
  { label: 'Any month', value: ANY },
  ...availableMonths.value.map(month => ({ label: formatMonthLabel(month), value: month })),
])

const { voteResultColor, formatNumber } = useFormatters()

function clearVoteFilters() {
  filterOutcome.value = ''
  filterVoteType.value = ''
  filterMonth.value = ''
  filterMargin.value = ''
}

usePageSeo({
  title: () => heading.value,
  description: () => (searchQuery.value
    ? `Roll-call vote search results for "${searchQuery.value}" in the ${chamberLabel.value}.`
    : `Latest ${chamberLabel.value} roll-call votes in the U.S. Congress.`),
})
</script>

<template>
  <UContainer class="space-y-8">
    <UCard>
      <div class="space-y-6">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <p class="text-xs font-medium uppercase tracking-[0.2em] text-primary">Vote routes</p>
            <h1 class="mt-2 text-2xl font-semibold tracking-tight text-highlighted sm:text-3xl">{{ heading }}</h1>
            <p class="mt-1 max-w-2xl text-muted">
              Recent roll-call activity combined with full-text vote search.
            </p>
          </div>

          <UFieldGroup>
            <UButton
              v-for="option in VOTE_CHAMBER_OPTIONS"
              :key="option.value"
              :to="voteRoute(option.value, searchQuery || undefined)"
              :color="option.value === chamber ? 'primary' : 'neutral'"
              :variant="option.value === chamber ? 'subtle' : 'outline'"
            >
              {{ option.label }}
            </UButton>
          </UFieldGroup>
        </div>

        <form class="flex flex-col gap-3 sm:flex-row sm:items-end" @submit.prevent="submitSearch">
          <UFormField label="Search vote questions and procedures" class="flex-1">
            <UInput
              v-model="draftQuery"
              type="search"
              icon="i-lucide-search"
              placeholder="cloture, confirmation, debt ceiling, impeachment…"
              class="w-full"
            />
          </UFormField>
          <UButton type="submit" color="primary" variant="subtle" size="lg" class="justify-center">
            {{ draftQuery.trim() ? 'Run vote search' : 'Load latest votes' }}
          </UButton>
        </form>

        <UCollapsible>
          <UButton color="neutral" variant="outline" block trailing-icon="i-lucide-chevron-down" class="justify-between">
            <span>Refine results</span>
            <span class="text-muted">{{ activeFacetCount ? `(${activeFacetCount} active)` : 'Optional filters' }}</span>
          </UButton>

          <template #content>
            <div class="grid grid-cols-1 gap-4 pt-4 sm:grid-cols-2 lg:grid-cols-4">
              <UFormField label="Outcome">
                <USelect v-model="outcomeModel" :items="outcomeItems" class="w-full" />
              </UFormField>
              <UFormField label="Vote type">
                <USelect v-model="voteTypeModel" :items="voteTypeItems" class="w-full" />
              </UFormField>
              <UFormField label="Vote month">
                <USelect v-model="monthModel" :items="monthItems" class="w-full" />
              </UFormField>
              <UFormField label="Max margin (close votes)">
                <UInput v-model.number="filterMargin" type="number" :min="0" placeholder="e.g. 10" class="w-full" />
              </UFormField>
            </div>

            <div v-if="activeFacetCount" class="flex justify-end pt-4">
              <UButton color="neutral" variant="ghost" size="xs" icon="i-lucide-x" @click="clearVoteFilters">
                Clear filters
              </UButton>
            </div>
          </template>
        </UCollapsible>
      </div>
    </UCard>

    <UAlert v-if="errorMessage" color="error" variant="subtle" icon="i-lucide-circle-alert" :description="errorMessage" />

    <div v-else-if="loading" class="grid grid-cols-1 gap-6 lg:grid-cols-2">
      <SkeletonCard v-for="n in 6" :key="n" :rows="4" />
    </div>

    <UCard v-else-if="!filteredVotes.length">
      <p class="text-muted">No votes matched this route and parameter set.</p>
    </UCard>

    <div v-else class="space-y-4">
      <p class="text-sm text-muted">
        {{ formatNumber(filteredVotes.length) }} {{ filteredVotes.length === 1 ? 'result' : 'results' }}
      </p>
      <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
      <UCard v-for="vote in filteredVotes" :key="vote.voteid">
        <div class="space-y-4">
          <div class="flex items-start justify-between gap-3">
            <p class="text-xs uppercase tracking-[0.1em] text-muted">{{ chamberLabel }} · Congress {{ vote.congress || '—' }}</p>
            <UBadge
              :color="voteResultColor(vote.result)"
              variant="subtle"
              :title="vote.result || 'Unknown'"
              class="w-56 shrink-0 justify-center truncate text-center"
            >
              {{ vote.result || 'Unknown' }}
            </UBadge>
          </div>

          <NuxtLink :to="`/votes/${vote.voteid}`" class="block text-lg font-medium text-highlighted transition-colors hover:text-primary">
            {{ vote.question || 'Untitled vote' }}
          </NuxtLink>

          <dl class="grid grid-cols-2 gap-x-6 gap-y-3 text-sm sm:grid-cols-4">
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Vote #</dt>
              <dd class="mt-0.5">{{ vote.votenumber || '—' }}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Session</dt>
              <dd class="mt-0.5">{{ vote.votesession || '—' }}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Date</dt>
              <dd class="mt-0.5">{{ formatDate(vote.votedate) }}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Type</dt>
              <dd class="mt-0.5">{{ vote.votetype || '—' }}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Yea</dt>
              <dd class="mt-0.5">{{ formatNumber(toCount(vote.yea_count ?? vote.yea)) }}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Nay</dt>
              <dd class="mt-0.5">{{ formatNumber(toCount(vote.nay_count ?? vote.nay)) }}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Present</dt>
              <dd class="mt-0.5">{{ formatNumber(toCount(vote.present)) }}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Not voting</dt>
              <dd class="mt-0.5">{{ formatNumber(toCount(vote.notvoting)) }}</dd>
            </div>
          </dl>
        </div>
      </UCard>
      </div>
    </div>
  </UContainer>
</template>
