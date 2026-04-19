<script setup lang="ts">
import { API_FAMILIES, BILL_TYPE_OPTIONS, VOTE_CHAMBER_OPTIONS } from '~/types/congress'

const router = useRouter()
const { fetchBillsByNumber, searchVotesFuzzy } = useCongressApi()

const { data: meta } = await useFetch<{ updated_at: string }>('/meta.json', { server: false })
const updatedAt = computed(() => meta.value?.updated_at ?? null)

const selectedBillType = ref('hr')
const selectedSort = ref('relevance')
const billQuery = ref('')
const selectedVoteChamber = ref<'house' | 'senate'>('senate')
const voteQuery = ref('')
const numberResults = ref<any[] | null>(null)
const numberLoading = ref(false)

// Fuzzy finder
const BILL_CODES = BILL_TYPE_OPTIONS.map(o => o.code)
// Matches: "hr1", "hr 1", "s.382", "hjres 5" etc.
const BILL_REF_RE = new RegExp(`^(${BILL_CODES.join('|')})\\.?\\s*(\\d*)$`, 'i')

const suggestions = ref<any[]>([])
const showSuggestions = ref(false)
const suggestLoading = ref(false)
let suggestTimer: ReturnType<typeof setTimeout> | null = null

watch(billQuery, (val) => {
  if (suggestTimer) clearTimeout(suggestTimer)
  const trimmed = val.trim()

  if (trimmed.length < 2) {
    showSuggestions.value = false
    suggestions.value = []
    return
  }

  const refMatch = BILL_REF_RE.exec(trimmed)

  suggestTimer = setTimeout(async () => {
    suggestLoading.value = true
    showSuggestions.value = true
    try {
      if (refMatch) {
        const typeCode = refMatch[1].toLowerCase()
        const number = refMatch[2]

        if (!number) {
          // Just a bill type code — show category option
          const opt = BILL_TYPE_OPTIONS.find(o => o.code === typeCode)
          suggestions.value = opt ? [{ _kind: 'category', opt }] : []
        }
        else {
          // Bill type + number — fetch by number, filter and sort
          const results = await fetchBillsByNumber(number)
          suggestions.value = (results as any[])
            .filter(b => b.billtype === typeCode)
            .sort((a, b) => Number(b.congress) - Number(a.congress))
        }
      }
      else {
        // Free text search runs on submit to avoid blocking on slow global lookups.
        suggestions.value = []
        showSuggestions.value = false
      }
      showSuggestions.value = suggestions.value.length > 0
    }
    catch {
      suggestions.value = []
      showSuggestions.value = false
    }
    finally {
      suggestLoading.value = false
    }
  }, 300)
})

function hideSuggestions() {
  setTimeout(() => { showSuggestions.value = false }, 150)
}

function selectCategory(code: string) {
  showSuggestions.value = false
  billQuery.value = ''
  router.push(`/bills/${code}`)
}

function selectBill(bill: any) {
  showSuggestions.value = false
  billQuery.value = ''
  router.push(`/bills/${bill.billtype}/${bill.congress}/${bill.billnumber}`)
}

// Vote fuzzy finder
const voteSuggestions = ref<any[]>([])
const showVoteSuggestions = ref(false)
const voteSuggestLoading = ref(false)
let votesSuggestTimer: ReturnType<typeof setTimeout> | null = null

watch(voteQuery, (val) => {
  if (votesSuggestTimer) clearTimeout(votesSuggestTimer)
  const trimmed = val.trim()

  if (trimmed.length < 2) {
    showVoteSuggestions.value = false
    voteSuggestions.value = []
    return
  }

  votesSuggestTimer = setTimeout(async () => {
    voteSuggestLoading.value = true
    showVoteSuggestions.value = true
    try {
      voteSuggestions.value = await searchVotesFuzzy(trimmed, selectedVoteChamber.value) as any[]
      showVoteSuggestions.value = voteSuggestions.value.length > 0
    }
    catch {
      voteSuggestions.value = []
      showVoteSuggestions.value = false
    }
    finally {
      voteSuggestLoading.value = false
    }
  }, 300)
})

function hideVoteSuggestions() {
  setTimeout(() => { showVoteSuggestions.value = false }, 150)
}

function selectVote(vote: any) {
  showVoteSuggestions.value = false
  voteQuery.value = ''
  router.push(`/votes/${vote.voteid}`)
}

const billGroups = computed(() => {
  return [
    {
      title: 'Senate tracks',
      items: BILL_TYPE_OPTIONS.filter(option => option.chamber === 'senate'),
    },
    {
      title: 'House tracks',
      items: BILL_TYPE_OPTIONS.filter(option => option.chamber === 'house'),
    },
  ]
})

function openBillType(code: string) {
  router.push(`/bills/${code}`)
}

async function submitBillSearch() {
  const query = billQuery.value.trim()
  if (/^\d+$/.test(query)) {
    numberLoading.value = true
    numberResults.value = null
    try {
      numberResults.value = await fetchBillsByNumber(query)
    }
    finally {
      numberLoading.value = false
    }
    return
  }
  numberResults.value = null
  router.push({
    path: `/bills/${selectedBillType.value}`,
    query: query ? { query, sort: selectedSort.value } : {},
  })
}

function submitVoteSearch() {
  const query = voteQuery.value.trim()
  router.push({
    path: '/votes',
    query: query ? { chamber: selectedVoteChamber.value, q: query } : { chamber: selectedVoteChamber.value },
  })
}

const { formatChamber } = useFormatters()
</script>

<template>
  <main class="page page--wide">
    <section class="hero-grid">
      <article class="hero-panel hero-panel--primary hero-panel--stamped">
        <p class="eyebrow">ACE Research</p>
        <h1 class="hero-title">A modern lens on congressional data.</h1>
        <p class="hero-copy">
          Explore the latest legislation, track roll-call votes, dive deep into committee workflows, and discover detailed insights into the actions of the U.S. Congress.
        </p>
        <span v-if="updatedAt" class="hero-updated">Updated {{ updatedAt }}</span>
      </article>

      <article class="hero-panel">
        <div class="section-title">
          <h2>Bill search</h2>
          <p>Search by keyword or enter a bill number to find legislation directly.</p>
        </div>

        <form class="control-grid" @submit.prevent="submitBillSearch">
          <label class="field">
            <span>Bill type</span>
            <select v-model="selectedBillType" class="field-input">
              <option v-for="option in BILL_TYPE_OPTIONS" :key="option.code" :value="option.code">
                {{ option.longLabel }}
              </option>
            </select>
          </label>

          <label class="field">
            <span>Sort</span>
            <select v-model="selectedSort" class="field-input">
              <option value="relevance">Relevance</option>
              <option value="date">Date</option>
            </select>
          </label>

          <div class="field field--full" style="position: relative;">
            <span>Search terms</span>
            <input
              v-model="billQuery"
              class="field-input"
              type="search"
              placeholder="climate, farm bill, veterans... or try hr 1"
              autocomplete="off"
              @blur="hideSuggestions"
            >
            <div v-if="showSuggestions || suggestLoading" class="bill-suggest">
              <div v-if="suggestLoading" class="bill-suggest__loading">Searching…</div>
              <template v-else-if="!suggestions.length">
                <div class="bill-suggest__loading">No results</div>
              </template>
              <template v-else>
                <button
                  v-for="item in suggestions"
                  :key="item._kind === 'category' ? item.opt.code : item.billid"
                  type="button"
                  class="bill-suggest__item"
                  @mousedown.prevent="item._kind === 'category' ? selectCategory(item.opt.code) : selectBill(item)"
                >
                  <span class="bill-suggest__code">{{ item._kind === 'category' ? item.opt.shortLabel : `${item.billtype.toUpperCase()} ${item.billnumber}` }}</span>
                  <span class="bill-suggest__meta">{{ item._kind === 'category' ? item.opt.longLabel : `Congress ${item.congress}` }}</span>
                  <span v-if="item._kind !== 'category' && (item.shorttitle || item.officialtitle)" class="bill-suggest__title">{{ item.shorttitle || item.officialtitle }}</span>
                </button>
              </template>
            </div>
          </div>

          <button class="button button--primary" type="submit">
            {{ billQuery.trim() ? 'Search bills' : 'Browse latest bills' }}
          </button>
        </form>

        <div v-if="numberLoading" class="number-results-note">Searching...</div>

        <div v-else-if="numberResults !== null">
          <div v-if="!numberResults.length" class="number-results-note">No bills found with that number.</div>
          <ol v-else class="number-results-list">
            <li v-for="bill in numberResults" :key="bill.billid" class="number-result-item">
              <NuxtLink :to="`/bills/${bill.billtype}/${bill.congress}/${bill.billnumber}`" class="number-result-link">
                <span class="number-result-type">{{ bill.billtype.toUpperCase() }} {{ bill.billnumber }}</span>
                <span class="number-result-congress">Congress {{ bill.congress }}</span>
              </NuxtLink>
              <p class="number-result-title">{{ bill.shorttitle || bill.officialtitle || '—' }}</p>
            </li>
          </ol>
        </div>
      </article>
    </section>

    <section class="overview-grid">
      <article class="surface">
        <div class="section-title">
          <h2>Endpoints</h2>
          <p>Each section maps to a available API endpoint.</p>
        </div>

        <div class="family-grid">
          <article v-for="family in API_FAMILIES" :key="family.id" class="family-card">
            <p class="family-card__route">{{ family.route }}</p>
            <h3>{{ family.title }}</h3>
            <p>{{ family.summary }}</p>
          </article>
        </div>
      </article>

      <article class="surface">
        <div class="section-title">
          <h2>Vote search</h2>
          <p>Search or browse recent roll-call votes by chamber.</p>
        </div>

        <form class="control-grid" @submit.prevent="submitVoteSearch">
          <label class="field">
            <span>Chamber</span>
            <select v-model="selectedVoteChamber" class="field-input">
              <option v-for="option in VOTE_CHAMBER_OPTIONS" :key="option.value" :value="option.value">
                {{ option.label }}
              </option>
            </select>
          </label>

          <div class="field field--full" style="position: relative;">
            <span>Search terms</span>
            <input
              v-model="voteQuery"
              class="field-input"
              type="search"
              placeholder="cloture, nomination, impeachment..."
              autocomplete="off"
              @blur="hideVoteSuggestions"
            >
            <div v-if="showVoteSuggestions || voteSuggestLoading" class="bill-suggest">
              <div v-if="voteSuggestLoading" class="bill-suggest__loading">Searching…</div>
              <template v-else-if="!voteSuggestions.length">
                <div class="bill-suggest__loading">No results</div>
              </template>
              <template v-else>
                <button
                  v-for="vote in voteSuggestions"
                  :key="vote.voteid"
                  type="button"
                  class="bill-suggest__item"
                  @mousedown.prevent="selectVote(vote)"
                >
                  <span class="bill-suggest__code">{{ formatChamber(vote.chamber) }} · Congress {{ vote.congress }}</span>
                  <span class="bill-suggest__meta">{{ vote.votedate }}</span>
                  <span class="bill-suggest__title">{{ vote.question || vote.voteid }}</span>
                </button>
              </template>
            </div>
          </div>

          <button class="button button--primary" type="submit">
            {{ voteQuery.trim() ? 'Search votes' : 'Browse recent votes' }}
          </button>
        </form>
      </article>
    </section>

    <section class="surface">
      <div class="section-title">
        <h2>Bill tracks</h2>
        <p>All eight bill categories from the current backend are wired directly into the redesigned flow.</p>
      </div>

      <div class="bill-group-grid">
        <article v-for="group in billGroups" :key="group.title" class="group-card">
          <div class="group-card__header">
            <h3>{{ group.title }}</h3>
            <span>{{ group.items.length }} routes</span>
          </div>

          <div class="group-card__list">
            <button
              v-for="item in group.items"
              :key="item.code"
              type="button"
              class="track-card"
              @click="openBillType(item.code)"
            >
              <div>
                <div class="track-card__code">{{ item.shortLabel }}</div>
                <h4>{{ item.longLabel }}</h4>
                <p>{{ item.description }}</p>
              </div>
              <span class="track-card__arrow">→</span>
            </button>
          </div>
        </article>
      </div>
    </section>
  </main>
</template>

<style scoped>
.hero-panel--stamped {
  position: relative;
}

.hero-updated {
  position: absolute;
  bottom: 0.75rem;
  right: 0.75rem;
  font-size: 0.7rem;
  color: var(--text-muted);
  pointer-events: none;
}
</style>
