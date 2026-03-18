<script setup lang="ts">
import { API_FAMILIES, BILL_TYPE_OPTIONS, VOTE_CHAMBER_OPTIONS } from '~/types/congress'

const router = useRouter()
const { fetchBillsByNumber } = useCongressApi()

const selectedBillType = ref('hr')
const selectedSort = ref('relevance')
const billQuery = ref('')
const selectedVoteChamber = ref<'house' | 'senate'>('senate')
const voteQuery = ref('')
const numberResults = ref<any[] | null>(null)
const numberLoading = ref(false)

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

const highlightStats = computed(() => [
  { label: 'Bill categories', value: String(BILL_TYPE_OPTIONS.length) },
  { label: 'Vote chambers', value: String(VOTE_CHAMBER_OPTIONS.length) },
  { label: 'API route families', value: String(API_FAMILIES.length) },
])

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
</script>

<template>
  <main class="page page--wide">
    <section class="hero-grid">
      <article class="hero-panel hero-panel--primary">
        <p class="eyebrow">ACE Research</p>
        <h1 class="hero-title">A modern lens on congressional data.</h1>
        <p class="hero-copy">
          Explore the latest legislation, track roll-call votes, dive deep into committee workflows, and discover detailed insights into the actions of the U.S. Congress.
        </p>

        <div class="stat-grid">
          <article v-for="stat in highlightStats" :key="stat.label" class="stat-card">
            <div class="stat-card__value">{{ stat.value }}</div>
            <div class="stat-card__label">{{ stat.label }}</div>
          </article>
        </div>
      </article>

      <article class="hero-panel">
        <div class="section-title">
          <h2>Jump into bill search</h2>
          <p>Backed by `/latest/:billtype` and `/search/:table/:filter`.</p>
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

          <label class="field field--full">
            <span>Search terms</span>
            <input
              v-model="billQuery"
              class="field-input"
              type="search"
              placeholder="climate, farm bill, veterans, budget..."
            >
          </label>

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
          <h2>API families in the UI</h2>
          <p>Each section maps cleanly to a `congress_api` route family.</p>
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
          <p>Use the recent chamber feed or the parameterized vote search helper.</p>
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

          <label class="field field--full">
            <span>Search terms</span>
            <input
              v-model="voteQuery"
              class="field-input"
              type="search"
              placeholder="cloture, nomination, impeachment, continuing resolution..."
            >
          </label>

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
