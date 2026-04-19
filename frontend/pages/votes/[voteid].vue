<script setup lang="ts">
import type { VoteDetail } from '~/types/congress'

const route = useRoute()
const { getVote } = useCongressApi()

const voteid = route.params.voteid as string

const {
  data: vote,
  pending: loading,
  error: fetchError,
} = await useAsyncData<VoteDetail>(
  `vote-${voteid}`,
  () => getVote(voteid),
  { lazy: true }
)

const errorMessage = computed(() =>
  fetchError.value
    ? (fetchError.value as any)?.data?.error || fetchError.value.message || 'Unable to load vote detail.'
    : '',
)

const partyFilter = ref('')
const filterPosition = ref('')

const filteredMembers = computed(() => {
  let results = vote.value?.members || []
  if (partyFilter.value) {
    results = results.filter(m => String(m.party).toUpperCase() === partyFilter.value)
  }
  if (filterPosition.value) {
    results = results.filter(m => m.position.toLowerCase() === filterPosition.value)
  }
  return results
})

const positionCounts = computed(() => {
  const counts: Record<string, number> = {}
  vote.value?.members?.forEach(m => {
    const pos = m.position.toLowerCase()
    counts[pos] = (counts[pos] || 0) + 1
  })
  return counts
})

const availableParties = computed(() => {
  if (!vote.value?.members) return []
  const parties = new Set(vote.value.members.map(m => String(m.party).toUpperCase()).filter(p => p && p !== 'UNDEFINED' && p !== 'NULL'))
  return Array.from(parties).sort()
})

const availablePositions = computed(() => {
  if (!vote.value?.members) return []
  const positions = new Set(vote.value.members.map(m => m.position.toLowerCase()).filter(Boolean))
  return Array.from(positions).sort()
})

const { formatDate, formatChamber, voteResultClass } = useFormatters()
</script>

<template>
  <main class="page page--wide">
    <section v-if="loading" class="surface">
      Loading vote...
    </section>

    <section v-else-if="errorMessage" class="surface surface--error">
      {{ errorMessage }}
    </section>

    <template v-else-if="vote">
      <section class="surface">
        <div class="toolbar">
          <div>
            <p class="eyebrow">
              <NuxtLink to="/votes">← Votes</NuxtLink>
              · {{ formatChamber(vote.chamber) }}
              · Congress {{ vote.congress }}
            </p>
            <h1>{{ vote.question || 'Untitled vote' }}</h1>
            <p v-if="vote.bill_number && vote.bill_type" class="lede" style="margin-top: 0.5rem">
              Related Bill: 
              <NuxtLink :to="`/bills/${vote.bill_type.toLowerCase()}/${vote.congress}/${vote.bill_number}`" class="result-link">
                {{ vote.bill_type.toUpperCase() }} {{ vote.bill_number }}
              </NuxtLink>
            </p>
          </div>

          <div style="display: flex; gap: 0.75rem; align-items: stretch">
            <span :class="voteResultClass(vote.result)" style="display: flex; align-items: center; justify-content: center; padding: 0.8rem 1rem;">
              {{ vote.result || 'Unknown' }}
            </span>
            <a v-if="vote.source_url" :href="vote.source_url" target="_blank" rel="noopener noreferrer" class="button" style="display: flex; align-items: center;">
              Source ↗
            </a>
          </div>
        </div>

        <dl class="detail-grid detail-grid--wide">
          <div>
            <dt>Vote #</dt>
            <dd>{{ vote.votenumber || '—' }}</dd>
          </div>
          <div>
            <dt>Date</dt>
            <dd>{{ formatDate(vote.votedate) }}</dd>
          </div>
          <div>
            <dt>Session</dt>
            <dd>{{ vote.votesession || '—' }}</dd>
          </div>
          <div>
            <dt>Type</dt>
            <dd>{{ vote.votetype || '—' }}</dd>
          </div>
        </dl>
      </section>

      <section class="summary-strip" v-if="Object.keys(positionCounts).length">
        <article class="summary-tile" v-for="(count, pos) in positionCounts" :key="pos">
          <span style="text-transform: capitalize;">{{ pos }}</span>
          <strong>{{ count }}</strong>
        </article>
      </section>

      <section v-if="vote.members?.length" class="surface" style="margin-top: 1rem;">
        <div class="section-title">
          <h2>Breakdown</h2>
          <p>By position and party</p>
        </div>
        <VoteBreakdownChart :members="vote.members" />
      </section>

      <section class="surface" style="margin-top: 1rem;">
        <div class="section-title">
          <h2>Member Votes</h2>
          <p>{{ vote.members?.length || 0 }} members cast a position</p>
        </div>

        <div class="control-grid" style="margin-top: 1rem; margin-bottom: 1.5rem;">
          <label class="field">
            <span>Filter Position</span>
            <select v-model="filterPosition" class="field-input">
              <option value="">All positions</option>
              <option v-for="pos in availablePositions" :key="pos" :value="pos" style="text-transform: capitalize;">{{ pos }}</option>
            </select>
          </label>
          <label class="field">
            <span>Filter Party</span>
            <select v-model="partyFilter" class="field-input">
              <option value="">All parties</option>
              <option v-for="p in availableParties" :key="p" :value="p">{{ p }}</option>
            </select>
          </label>
        </div>

        <div v-if="!filteredMembers.length" class="empty-note">
          No members match the current filters.
        </div>
        
        <div v-else class="cosponsor-grid">
          <article
            v-for="member in filteredMembers"
            :key="member.bioguide_id"
            class="cosponsor-card"
          >
            <NuxtLink :to="`/members/${member.bioguide_id}`" class="cosponsor-card__name link-plain" style="display: block;">
              {{ member.display_name || member.bioguide_id }}
            </NuxtLink>
            <div class="cosponsor-card__meta">
              <span>{{ member.party || '?' }}</span>
              <span>{{ member.state || '?' }}</span>
            </div>
            <div class="cosponsor-card__date" style="margin-top: 0.5rem">
              <span class="badge" :style="member.position.toLowerCase() === 'yea' || member.position.toLowerCase() === 'aye' ? 'color: var(--accent-success); border-color: var(--accent-success)' : member.position.toLowerCase() === 'nay' || member.position.toLowerCase() === 'no' ? 'color: rgb(248, 113, 113); border-color: rgb(248, 113, 113)' : ''">
                Voted {{ member.position }}
              </span>
            </div>
          </article>
        </div>
      </section>
    </template>
  </main>
</template>

<style scoped>
.cosponsor-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 0.75rem;
}

.cosponsor-card {
  padding: 0.75rem;
  border: 1px solid var(--border-soft, #e5e7eb);
  border-radius: 4px;
  font-size: 0.85rem;
}

.cosponsor-card__name {
  font-weight: 500;
  margin-bottom: 0.25rem;
}

.cosponsor-card__meta {
  display: flex;
  gap: 0.4rem;
  align-items: center;
  color: var(--text-muted, #6b7280);
  font-size: 0.78rem;
}

.badge {
  font-size: 0.65rem;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  padding: 0.1rem 0.35rem;
  border: 1px solid currentColor;
  border-radius: 2px;
}

.detail-grid--wide {
  grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
}
</style>
