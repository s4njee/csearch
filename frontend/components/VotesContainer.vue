<template>
  <NavBar class="text-center" />

  <div class="votesContainer flex justify-center">
    <div class="w-full max-w-6xl mx-auto px-4">
      <div class="flex flex-col gap-4 items-center mb-8 mt-4">
        <div class="flex flex-wrap justify-center gap-0">
          <NuxtLink
            v-for="option in chamberOptions"
            :key="option.value"
            :to="voteRoute(option.value, searchQuery)"
            class="filterPill"
            :class="{ activePill: option.value === chamber }"
          >
            {{ option.label }}
          </NuxtLink>
        </div>

        <form class="w-full max-w-2xl" @submit.prevent="submitSearch">
          <div class="flex flex-col sm:flex-row gap-0">
            <input
              v-model="draftQuery"
              type="search"
              class="searchInput"
              placeholder="Search vote questions, results, or vote types"
            />
            <button type="submit" class="searchButton">
              Search
            </button>
          </div>
        </form>

        <p class="text-neutral-500 text-xs max-w-3xl uppercase tracking-wider">
          Browse the latest {{ chamberLabel.toLowerCase() }} votes from the last 90 days,
          or search the broader vote corpus with the congress_api full-text vote query.
        </p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-px mb-2">
        <div class="summaryCard">
          <p class="summaryLabel">Showing</p>
          <p class="summaryValue">{{ votes.length }}</p>
          <p class="summaryMeta">{{ searchQuery ? 'search results' : 'recent votes' }}</p>
        </div>
        <div class="summaryCard">
          <p class="summaryLabel">Pass / agreed</p>
          <p class="summaryValue">{{ passedCount }}</p>
          <p class="summaryMeta">{{ chamberLabel }} items with favorable outcomes</p>
        </div>
        <div class="summaryCard">
          <p class="summaryLabel">Closest margin</p>
          <p class="summaryValue">{{ closestMarginLabel }}</p>
          <p class="summaryMeta">Based on yea / nay counts in the current list</p>
        </div>
      </div>

      <div class="mb-4">
        <h1 class="text-white text-center text-2xl font-light mb-2 tracking-tight">
          {{ heading }}
        </h1>
        <p v-if="searchQuery" class="text-neutral-500 text-center text-xs uppercase tracking-wider">
          Results for "{{ searchQuery }}" in the {{ chamberLabel.toLowerCase() }}.
        </p>
      </div>

      <div v-if="loading" class="statusState">Loading votes...</div>
      <div v-else-if="errorMessage" class="statusState errorState">{{ errorMessage }}</div>
      <div v-else-if="votes.length === 0" class="statusState">No votes found.</div>

      <transition-group
        v-else
        tag="ul"
        name="voteList"
        class="grid grid-cols-1 xl:grid-cols-2 gap-px list-none p-0"
      >
        <li
          v-for="vote in votes"
          :key="vote.voteid"
          class="voteCard"
        >
          <div class="flex justify-between gap-3 items-start mb-3">
            <div>
              <p class="text-neutral-600 text-xs uppercase tracking-widest">
                {{ formatChamber(vote.chamber) }} · Congress {{ vote.congress || '—' }}
              </p>
              <h2 class="text-base font-normal text-white leading-tight">
                {{ vote.question || 'Untitled vote' }}
              </h2>
            </div>
            <span class="resultBadge" :class="resultBadgeClass(vote.result)">
              {{ vote.result || 'Unknown result' }}
            </span>
          </div>

          <div class="grid grid-cols-2 gap-2 text-xs mb-3 text-neutral-400">
            <div>
              <p class="detailLabel">Vote #</p>
              <p>{{ vote.votenumber || '—' }}</p>
            </div>
            <div>
              <p class="detailLabel">Session</p>
              <p>{{ vote.votesession || '—' }}</p>
            </div>
            <div>
              <p class="detailLabel">Date</p>
              <p>{{ formatDate(vote.votedate) }}</p>
            </div>
            <div>
              <p class="detailLabel">Type</p>
              <p>{{ vote.votetype || '—' }}</p>
            </div>
          </div>

          <div class="grid grid-cols-2 sm:grid-cols-4 gap-px mb-3">
            <div class="tallyBox yes">
              <span class="tallyLabel">Yea</span>
              <span class="tallyValue">{{ toCount(vote.yea_count ?? vote.yea) }}</span>
            </div>
            <div class="tallyBox no">
              <span class="tallyLabel">Nay</span>
              <span class="tallyValue">{{ toCount(vote.nay_count ?? vote.nay) }}</span>
            </div>
            <div class="tallyBox present">
              <span class="tallyLabel">Present</span>
              <span class="tallyValue">{{ toCount(vote.present) }}</span>
            </div>
            <div class="tallyBox absent">
              <span class="tallyLabel">Not voting</span>
              <span class="tallyValue">{{ toCount(vote.notvoting) }}</span>
            </div>
          </div>

          <div class="flex justify-between items-center gap-3 text-xs text-neutral-600">
            <span>ID: {{ vote.voteid }}</span>
            <a
              v-if="vote.source_url"
              :href="vote.source_url"
              target="_blank"
              rel="noopener noreferrer"
              class="sourceLink"
            >
              Source ↗
            </a>
          </div>
        </li>
      </transition-group>
    </div>
  </div>
</template>

<script setup>
import { computed, ref, watch } from 'vue';
import NavBar from '~/components/NavBar.vue';

const route = useRoute();
const router = useRouter();
// Prefer the runtime-injected browser config so this static frontend image can
// point at different API environments without a per-environment rebuild.
const API_SERVER = useApiBase();

const loading = ref(false);
const votes = ref([]);
const errorMessage = ref('');
const draftQuery = ref('');

const chamberOptions = [
  { label: 'Senate', value: 'senate' },
  { label: 'House', value: 'house' },
];

const chamber = computed(() => {
  const raw = typeof route.query.chamber === 'string' ? route.query.chamber.toLowerCase() : 'senate';
  return raw === 'house' ? 'house' : 'senate';
});

const searchQuery = computed(() => {
  return typeof route.query.q === 'string' ? route.query.q.trim() : '';
});

const chamberLabel = computed(() => chamber.value === 'house' ? 'House' : 'Senate');
const heading = computed(() => searchQuery.value ? `${chamberLabel.value} vote search` : `Latest ${chamberLabel.value} votes`);

const passedCount = computed(() => votes.value.filter((vote) => isPassedResult(vote.result)).length);

const closestMarginLabel = computed(() => {
  const margins = votes.value
    .map((vote) => {
      const yea = toCount(vote.yea_count ?? vote.yea);
      const nay = toCount(vote.nay_count ?? vote.nay);
      if (yea === 0 && nay === 0) {
        return null;
      }
      return Math.abs(yea - nay);
    })
    .filter((margin) => margin !== null);

  if (margins.length === 0) {
    return '—';
  }

  return String(Math.min(...margins));
});

function toCount(value) {
  const parsed = Number.parseInt(value ?? '0', 10);
  return Number.isNaN(parsed) ? 0 : parsed;
}

function isPassedResult(result = '') {
  const normalized = result.toLowerCase();
  return normalized.includes('passed')
    || normalized.includes('agreed')
    || normalized.includes('confirmed')
    || normalized.includes('approved')
    || normalized.includes('adopted')
    || normalized.includes('accepted')
    || normalized.includes('ratified');
}

function resultBadgeClass(result = '') {
  const normalized = result.toLowerCase();
  if (isPassedResult(normalized)) {
    return 'badgePositive';
  }
  if (normalized.includes('failed') || normalized.includes('rejected') || normalized.includes('not agreed')) {
    return 'badgeNegative';
  }
  return 'badgeNeutral';
}

function formatChamber(value = '') {
  const normalized = value.toLowerCase();
  return normalized === 'house' ? 'House' : normalized === 'senate' ? 'Senate' : value || 'Unknown chamber';
}

function formatDate(value) {
  if (!value) {
    return '—';
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  }).format(date);
}

function voteRoute(nextChamber, nextQuery) {
  const query = { chamber: nextChamber };
  if (nextQuery) {
    query.q = nextQuery;
  }
  return { path: '/votes', query };
}

async function loadVotes() {
  loading.value = true;
  errorMessage.value = '';

  try {
    const endpoint = searchQuery.value
      ? `${API_SERVER}/explore/vote-search-example?q=${encodeURIComponent(searchQuery.value)}&chamber=${encodeURIComponent(chamber.value)}&limit=24`
      : `${API_SERVER}/votes/${encodeURIComponent(chamber.value)}`;

    const response = await fetch(endpoint);
    if (!response.ok) {
      throw new Error(`Request failed with status ${response.status}`);
    }

    const payload = await response.json();
    votes.value = Array.isArray(payload) ? payload : (payload.results || []);
  } catch (error) {
    votes.value = [];
    errorMessage.value = error instanceof Error ? error.message : 'Unable to load votes right now.';
  } finally {
    loading.value = false;
  }
}

async function submitSearch() {
  const nextQuery = draftQuery.value.trim();
  await router.push(voteRoute(chamber.value, nextQuery || undefined));
}

watch(
  () => [chamber.value, searchQuery.value],
  () => {
    draftQuery.value = searchQuery.value;
    loadVotes();
  },
  { immediate: true }
);
</script>

<style scoped>
.filterPill {
  border: 1px solid var(--border-soft);
  padding: 0.45rem 0.8rem;
  color: var(--text-muted);
  text-decoration: none;
  background: transparent;
  font-size: 0.72rem;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  margin-left: -1px;
}

.filterPill:first-child {
  margin-left: 0;
}

.activePill {
  background: var(--accent-primary);
  border-color: var(--accent-primary);
  color: #000;
  font-weight: 700;
}

.searchInput {
  width: 100%;
  padding: 0.7rem 0.75rem;
  border: 1px solid var(--border-soft);
  background: var(--bg-panel-strong);
  color: var(--text-main);
  font-size: 0.82rem;
}

.searchInput:focus {
  outline: none;
  border-color: var(--accent-primary);
}

.searchButton {
  padding: 0.7rem 1rem;
  background: var(--accent-primary);
  color: #000;
  font-weight: 700;
  border: 1px solid var(--accent-primary);
  font-size: 0.72rem;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  cursor: pointer;
}

.summaryCard,
.voteCard {
  background: var(--bg-panel);
  border: 1px solid var(--border-soft);
  padding: 0.9rem;
  text-align: left;
}

.summaryLabel,
.detailLabel,
.tallyLabel {
  color: var(--text-muted);
  font-size: 0.68rem;
  text-transform: uppercase;
  letter-spacing: 0.12em;
}

.summaryValue {
  color: var(--text-main);
  font-size: 1.5rem;
  font-weight: 300;
}

.summaryMeta {
  color: var(--text-muted);
  font-size: 0.72rem;
}

.statusState {
  text-align: center;
  color: var(--text-muted);
  padding: 2rem 0;
  font-size: 0.82rem;
  text-transform: uppercase;
  letter-spacing: 0.1em;
}

.errorState {
  color: rgb(248, 113, 113);
}

.resultBadge {
  padding: 0.3rem 0.6rem;
  font-size: 0.68rem;
  font-weight: 600;
  white-space: nowrap;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.badgePositive {
  border: 1px solid rgba(74, 222, 128, 0.5);
  color: rgb(74, 222, 128);
  background: transparent;
}

.badgeNegative {
  border: 1px solid rgba(248, 113, 113, 0.5);
  color: rgb(248, 113, 113);
  background: transparent;
}

.badgeNeutral {
  border: 1px solid var(--border-soft);
  color: var(--text-muted);
  background: transparent;
}

.tallyBox {
  padding: 0.6rem;
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
  border: 1px solid var(--border-soft);
}

.tallyValue {
  color: var(--text-main);
  font-size: 1.1rem;
  font-weight: 300;
}

.yes { border-left: 2px solid rgb(74, 222, 128); }
.no { border-left: 2px solid rgb(248, 113, 113); }
.present { border-left: 2px solid rgb(96, 165, 250); }
.absent { border-left: 2px solid rgb(115, 115, 115); }

.sourceLink {
  color: var(--text-muted);
  text-decoration: underline;
  text-underline-offset: 2px;
}

.sourceLink:hover {
  color: var(--accent-primary);
}

.voteList-enter-from {
  opacity: 0;
}

.voteList-enter-active {
  transition: opacity 0.2s ease-out;
}

.voteList-enter-to {
  opacity: 1;
}
</style>
