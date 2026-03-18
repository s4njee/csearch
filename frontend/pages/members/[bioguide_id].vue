<script setup lang="ts">
import type { MemberDetail } from '~/types/congress'

const route = useRoute()
const { getMember } = useCongressApi()

const bioguideId = route.params.bioguide_id as string

const {
  data: member,
  pending: loading,
  error: fetchError,
} = await useAsyncData<MemberDetail>(
  `member-${bioguideId}`,
  () => getMember(bioguideId),
  { lazy: true }
)

const errorMessage = computed(() =>
  fetchError.value
    ? (fetchError.value as any)?.data?.error || fetchError.value.message || 'Unable to load member profile.'
    : '',
)

function partyLabel(party?: string | null) {
  if (!party)
    return 'Unknown'
  const map: Record<string, string> = { D: 'Democrat', R: 'Republican', I: 'Independent' }
  return map[party.toUpperCase()] || party
}

function voteResultClass(result?: string | null) {
  const n = String(result || '').toLowerCase()
  if (['passed', 'agreed', 'confirmed', 'approved', 'adopted', 'ratified'].some(w => n.includes(w)))
    return 'vote-badge vote-badge--positive'
  if (['failed', 'rejected', 'not agreed'].some(w => n.includes(w)))
    return 'vote-badge vote-badge--negative'
  return 'vote-badge'
}

function formatDate(value?: string | null) {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value
  return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' }).format(date)
}

function formatChamber(value?: string | null) {
  const normalized = String(value || '').toLowerCase()
  if (normalized === 'senate' || normalized === 's') {
    return 'Senate'
  }
  if (normalized === 'house' || normalized === 'h') {
    return 'House'
  }
  return value || 'Unknown chamber'
}

function summarizeText(value?: string | null, limit = 160) {
  if (!value) return ''
  return value.length > limit ? `${value.slice(0, limit).trim()}...` : value
}
</script>

<template>
  <main class="page page--wide">
    <section v-if="loading" class="surface">
      Loading profile...
    </section>

    <section v-else-if="errorMessage" class="surface surface--error">
      {{ errorMessage }}
    </section>

    <template v-else-if="member">
      <section class="surface">
        <div class="toolbar">
          <div>
            <p class="eyebrow">Member Profile · {{ member.bioguide_id }}</p>
            <h1>{{ member.name }}</h1>
            <p class="lede">{{ partyLabel(member.party) }} · {{ member.state || 'Unknown State' }}</p>
          </div>
          <a :href="`https://bioguide.congress.gov/search/bio/${member.bioguide_id}`" target="_blank" rel="noopener noreferrer" class="button">
            Bioguide ↗
          </a>
        </div>
      </section>

      <section class="summary-strip">
        <article class="summary-tile">
          <span>Sponsored Bills</span>
          <strong>{{ member.counts.sponsored || 0 }}</strong>
        </article>
        <article class="summary-tile">
          <span>Cosponsored Bills</span>
          <strong>{{ member.counts.cosponsored || 0 }}</strong>
        </article>
      </section>

      <section class="surface">
        <div class="section-title">
          <h2>Recent Sponsored Legislation</h2>
          <p>Latest bills sponsored by {{ member.name }}</p>
        </div>

        <div v-if="!member.sponsoredBills?.length" class="empty-note">
          No recently sponsored bills found.
        </div>
        
        <div v-else class="result-grid">
          <article v-for="bill in member.sponsoredBills" :key="bill.billid" class="result-card">
            <div class="result-card__header">
              <div>
                <p class="result-card__meta">
                  {{ bill.billtype.toUpperCase() }} {{ bill.billnumber }} · Congress {{ bill.congress }}
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
                <dt>Policy Area</dt>
                <dd>{{ bill.policy_area || '—' }}</dd>
              </div>
              <div>
                <dt>Cosponsors</dt>
                <dd>{{ bill.cosponsor_count || 0 }}</dd>
              </div>
            </dl>
          </article>
        </div>
      </section>

      <section class="surface">
        <div class="section-title">
          <h2>Recent Floor Votes</h2>
          <p>How {{ member.name }} voted on recent chamber actions</p>
        </div>

        <div v-if="!member.recentVotes?.length" class="empty-note">
          No recent floor votes found for this member.
        </div>

        <div v-else class="result-grid">
          <article v-for="vote in member.recentVotes" :key="vote.voteid" class="result-card">
            <div class="result-card__header">
              <div>
                <p class="result-card__meta">{{ formatChamber(vote.chamber) }} · Congress {{ vote.congress }}</p>
                <NuxtLink :to="`/votes/${vote.voteid}`" class="link-plain">
                  <h3>{{ vote.question || 'Untitled vote' }}</h3>
                </NuxtLink>
              </div>
              <div style="display: flex; gap: 0.5rem; flex-direction: column; align-items: flex-end;">
                <span :class="voteResultClass(vote.result)">{{ vote.result || 'Unknown' }}</span>
                <span class="badge" :style="(vote as any).position?.toLowerCase() === 'yea' || (vote as any).position?.toLowerCase() === 'aye' ? 'color: var(--accent-success); border-color: var(--accent-success)' : (vote as any).position?.toLowerCase() === 'nay' || (vote as any).position?.toLowerCase() === 'no' ? 'color: rgb(248, 113, 113); border-color: rgb(248, 113, 113)' : ''">
                  Voted {{ (vote as any).position || 'Unknown' }}
                </span>
              </div>
            </div>

            <dl class="detail-grid">
              <div>
                <dt>Vote #</dt>
                <dd>{{ vote.votenumber || '—' }}</dd>
              </div>
              <div>
                <dt>Date</dt>
                <dd>{{ formatDate(vote.votedate) }}</dd>
              </div>
              <div>
                <dt>Type</dt>
                <dd>{{ vote.votetype || '—' }}</dd>
              </div>
            </dl>
          </article>
        </div>
      </section>
    </template>
  </main>
</template>

<style scoped>
.result-card__summary {
  margin-top: 1rem;
  margin-bottom: 1.25rem;
  line-height: 1.5;
}
</style>
