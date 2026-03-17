<script setup lang="ts">
import { VOTE_CHAMBER_OPTIONS } from '~/types/congress'
import type { VoteRecord } from '~/types/congress'

const route = useRoute()
const router = useRouter()
const { latestVotes, searchVotes } = useCongressApi()

const loading = ref(false)
const errorMessage = ref('')
const votes = ref<VoteRecord[]>([])
const draftQuery = ref('')

const chamber = computed<'house' | 'senate'>(() => {
  const raw = typeof route.query.chamber === 'string' ? route.query.chamber.toLowerCase() : 'senate'
  return raw === 'house' ? 'house' : 'senate'
})

const chamberLabel = computed(() => chamber.value === 'house' ? 'House' : 'Senate')
const searchQuery = computed(() => typeof route.query.q === 'string' ? route.query.q.trim() : '')
const heading = computed(() => searchQuery.value ? `${chamberLabel.value} vote search` : `Latest ${chamberLabel.value} votes`)

const passedCount = computed(() => votes.value.filter(vote => isPassedResult(vote.result)).length)
const closestMargin = computed(() => {
  const margins = votes.value
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
    query: nextQuery ? { chamber: nextChamber, q: nextQuery } : { chamber: nextChamber },
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

function resultClass(result: string | null | undefined) {
  const normalized = String(result || '').toLowerCase()
  if (isPassedResult(normalized)) {
    return 'vote-badge vote-badge--positive'
  }
  if (normalized.includes('failed') || normalized.includes('rejected') || normalized.includes('not agreed')) {
    return 'vote-badge vote-badge--negative'
  }
  return 'vote-badge'
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

async function loadVotes() {
  loading.value = true
  errorMessage.value = ''

  try {
    if (searchQuery.value) {
      const payload = await searchVotes({
        q: searchQuery.value,
        chamber: chamber.value,
        limit: 24,
      })
      votes.value = payload.results as VoteRecord[]
    }
    else {
      votes.value = await latestVotes(chamber.value)
    }
  }
  catch (error: any) {
    votes.value = []
    errorMessage.value = error?.data?.message || error?.message || 'Unable to load votes right now.'
  }
  finally {
    loading.value = false
  }
}

async function submitSearch() {
  const query = draftQuery.value.trim()
  await router.push(voteRoute(chamber.value, query || undefined))
}

watch(
  () => [chamber.value, searchQuery.value],
  () => {
    draftQuery.value = searchQuery.value
    loadVotes()
  },
  { immediate: true },
)
</script>

<template>
  <main class="page page--wide">
    <section class="surface">
      <div class="toolbar">
        <div>
          <p class="eyebrow">Vote routes</p>
          <h1>{{ heading }}</h1>
          <p class="lede">
            This view combines the recent `/votes/:chamber` feed with the parameterized
            `vote-search-example` helper served through `/explore/:queryId`.
          </p>
        </div>

        <div class="pill-row">
          <NuxtLink
            v-for="option in VOTE_CHAMBER_OPTIONS"
            :key="option.value"
            :to="voteRoute(option.value, searchQuery || undefined)"
            class="pill"
            :class="{ 'pill--active': option.value === chamber }"
          >
            {{ option.label }}
          </NuxtLink>
        </div>
      </div>

      <form class="control-grid" @submit.prevent="submitSearch">
        <label class="field field--full">
          <span>Search vote questions and procedures</span>
          <input
            v-model="draftQuery"
            class="field-input"
            type="search"
            placeholder="cloture, confirmation, debt ceiling, impeachment..."
          >
        </label>

        <button class="button button--primary" type="submit">
          {{ draftQuery.trim() ? 'Run vote search' : 'Load latest votes' }}
        </button>
      </form>
    </section>

    <section class="summary-strip">
      <article class="summary-tile">
        <span>Rows</span>
        <strong>{{ votes.length }}</strong>
      </article>
      <article class="summary-tile">
        <span>Passed / agreed</span>
        <strong>{{ passedCount }}</strong>
      </article>
      <article class="summary-tile">
        <span>Closest margin</span>
        <strong>{{ closestMargin }}</strong>
      </article>
      <article class="summary-tile">
        <span>Mode</span>
        <strong>{{ searchQuery ? 'Search' : 'Latest' }}</strong>
      </article>
    </section>

    <section v-if="errorMessage" class="surface surface--error">
      {{ errorMessage }}
    </section>

    <section v-else-if="loading" class="surface">
      Loading votes...
    </section>

    <section v-else-if="!votes.length" class="surface">
      No votes matched this route and parameter set.
    </section>

    <section v-else class="result-grid">
      <article v-for="vote in votes" :key="vote.voteid" class="result-card">
        <div class="result-card__header">
          <div>
            <p class="result-card__meta">{{ chamberLabel }} · Congress {{ vote.congress || '—' }}</p>
            <h2>{{ vote.question || 'Untitled vote' }}</h2>
          </div>

          <span :class="resultClass(vote.result)">
            {{ vote.result || 'Unknown' }}
          </span>
        </div>

        <dl class="detail-grid">
          <div>
            <dt>Vote #</dt>
            <dd>{{ vote.votenumber || '—' }}</dd>
          </div>
          <div>
            <dt>Session</dt>
            <dd>{{ vote.votesession || '—' }}</dd>
          </div>
          <div>
            <dt>Date</dt>
            <dd>{{ formatDate(vote.votedate) }}</dd>
          </div>
          <div>
            <dt>Type</dt>
            <dd>{{ vote.votetype || '—' }}</dd>
          </div>
          <div>
            <dt>Yea</dt>
            <dd>{{ toCount(vote.yea_count ?? vote.yea) }}</dd>
          </div>
          <div>
            <dt>Nay</dt>
            <dd>{{ toCount(vote.nay_count ?? vote.nay) }}</dd>
          </div>
          <div>
            <dt>Present</dt>
            <dd>{{ toCount(vote.present) }}</dd>
          </div>
          <div>
            <dt>Not voting</dt>
            <dd>{{ toCount(vote.notvoting) }}</dd>
          </div>
        </dl>
      </article>
    </section>
  </main>
</template>
