<script setup lang="ts">
import { BILL_TYPE_OPTIONS } from '~/types/congress'
import type { BillDetail } from '~/types/congress'

const route = useRoute()
const { getBill } = useCongressApi()

const billtype = route.params.category as string
const congress = route.params.congress as string
const billnumber = route.params.number as string

const categoryMeta = computed(() => BILL_TYPE_OPTIONS.find(opt => opt.code === billtype))
const govTrackUrl = computed(() =>
  `https://www.govtrack.us/congress/bills/${congress}/${billtype}${billnumber}`,
)

const {
  data: bill,
  pending: loading,
  error: fetchError,
} = await useAsyncData<BillDetail>(
  `bill-${billtype}-${congress}-${billnumber}`,
  () => getBill(billtype, congress, billnumber),
)

const errorMessage = computed(() =>
  fetchError.value
    ? (fetchError.value as any)?.data?.error || fetchError.value.message || 'Unable to load bill.'
    : '',
)

function formatDate(value?: string | null) {
  if (!value)
    return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime()))
    return value
  return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' }).format(date)
}

function partyLabel(party?: string | null) {
  if (!party)
    return null
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
</script>

<template>
  <main class="page page--wide">
    <section v-if="loading" class="surface">
      Loading bill...
    </section>

    <section v-else-if="errorMessage" class="surface surface--error">
      {{ errorMessage }}
    </section>

    <template v-else-if="bill">
      <!-- HEADER -->
      <section class="surface">
        <div class="toolbar">
          <div>
            <p class="eyebrow">
              <NuxtLink :to="`/bills/${billtype}`">
                ← {{ categoryMeta?.longLabel ?? billtype.toUpperCase() }}
              </NuxtLink>
              · Congress {{ congress }}
            </p>
            <h1>{{ bill.shorttitle || bill.officialtitle || `${(categoryMeta?.shortLabel ?? billtype).toUpperCase()} ${billnumber}` }}</h1>
            <p v-if="bill.officialtitle && bill.shorttitle" class="lede">
              {{ bill.officialtitle }}
            </p>
          </div>

          <a :href="govTrackUrl" target="_blank" rel="noopener noreferrer" class="button">
            GovTrack ↗
          </a>
        </div>

        <dl class="detail-grid detail-grid--wide">
          <div>
            <dt>Bill</dt>
            <dd>{{ categoryMeta?.shortLabel ?? billtype }} {{ billnumber }}</dd>
          </div>
          <div>
            <dt>Congress</dt>
            <dd>{{ congress }}</dd>
          </div>
          <div>
            <dt>Introduced</dt>
            <dd>{{ formatDate(bill.introducedat) }}</dd>
          </div>
          <div>
            <dt>Status date</dt>
            <dd>{{ formatDate(bill.statusat) }}</dd>
          </div>
          <div>
            <dt>Last action</dt>
            <dd>{{ formatDate(bill.latest_action_date) }}</dd>
          </div>
          <div>
            <dt>Origin chamber</dt>
            <dd>{{ bill.origin_chamber || '—' }}</dd>
          </div>
          <div>
            <dt>Policy area</dt>
            <dd>{{ bill.policy_area || '—' }}</dd>
          </div>
          <div>
            <dt>Sponsor</dt>
            <dd>{{ bill.sponsor_name || '—' }}</dd>
          </div>
          <div>
            <dt>Party</dt>
            <dd>{{ partyLabel(bill.sponsor_party) || '—' }}</dd>
          </div>
          <div>
            <dt>State</dt>
            <dd>{{ bill.sponsor_state || '—' }}</dd>
          </div>
        </dl>
      </section>

      <!-- SUMMARY -->
      <section v-if="bill.summary_text" class="surface">
        <div class="section-title">
          <h2>Summary</h2>
          <p v-if="bill.summary_date">As of {{ formatDate(bill.summary_date) }}</p>
        </div>
        <p class="bill-summary">
          {{ bill.summary_text }}
        </p>
      </section>

      <!-- ACTION HISTORY -->
      <section class="surface">
        <div class="section-title">
          <h2>Action history</h2>
          <p>{{ bill.actions.length }} recorded {{ bill.actions.length === 1 ? 'action' : 'actions' }}</p>
        </div>

        <div v-if="!bill.actions.length" class="empty-note">
          No actions on record.
        </div>

        <ol v-else class="action-list">
          <li v-for="(action, index) in bill.actions" :key="index" class="action-item">
            <span class="action-item__date">{{ formatDate(action.acted_at) }}</span>
            <div class="action-item__body">
              <span class="action-item__text">{{ action.action_text || '—' }}</span>
              <span v-if="action.action_type" class="action-item__type">{{ action.action_type }}</span>
            </div>
          </li>
        </ol>
      </section>

      <!-- COSPONSORS -->
      <section class="surface">
        <div class="section-title">
          <h2>Cosponsors</h2>
          <p>{{ bill.cosponsors.length }} {{ bill.cosponsors.length === 1 ? 'cosponsor' : 'cosponsors' }}</p>
        </div>

        <div v-if="!bill.cosponsors.length" class="empty-note">
          No cosponsors on record.
        </div>

        <div v-else class="cosponsor-grid">
          <article
            v-for="cosponsor in bill.cosponsors"
            :key="cosponsor.bioguide_id"
            class="cosponsor-card"
          >
            <div class="cosponsor-card__name">
              {{ cosponsor.full_name || cosponsor.bioguide_id }}
            </div>
            <div class="cosponsor-card__meta">
              <span>{{ cosponsor.party || '?' }}</span>
              <span>{{ cosponsor.state || '?' }}</span>
              <span v-if="cosponsor.is_original_cosponsor" class="badge">Original</span>
            </div>
            <div class="cosponsor-card__date">
              {{ formatDate(cosponsor.sponsorship_date) }}
            </div>
          </article>
        </div>
      </section>

      <!-- FLOOR VOTES -->
      <section class="surface">
        <div class="section-title">
          <h2>Floor votes</h2>
          <p>{{ bill.votes.length }} recorded {{ bill.votes.length === 1 ? 'vote' : 'votes' }}</p>
        </div>

        <div v-if="!bill.votes.length" class="empty-note">
          No floor votes linked to this bill.
        </div>

        <div v-else class="result-grid">
          <article v-for="vote in bill.votes" :key="vote.voteid" class="result-card">
            <div class="result-card__header">
              <div>
                <p class="result-card__meta">
                  {{ vote.chamber }} · Congress {{ vote.congress }}
                </p>
                <h3>{{ vote.question || 'Vote' }}</h3>
              </div>
              <span :class="voteResultClass(vote.result)">{{ vote.result || 'Unknown' }}</span>
            </div>
            <dl class="detail-grid">
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
.bill-summary {
  line-height: 1.7;
  white-space: pre-wrap;
}

.action-list {
  list-style: none;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.action-item {
  display: grid;
  grid-template-columns: 9rem 1fr;
  gap: 0.75rem;
  font-size: 0.85rem;
  padding-bottom: 0.75rem;
  border-bottom: 1px solid var(--border-soft, #e5e7eb);
}

.action-item:last-child {
  border-bottom: none;
}

.action-item__date {
  color: var(--text-muted, #6b7280);
  white-space: nowrap;
  padding-top: 0.1rem;
}

.action-item__body {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.action-item__type {
  font-size: 0.72rem;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--accent-dim, #9ca3af);
}

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

.cosponsor-card__date {
  margin-top: 0.25rem;
  color: var(--text-muted, #6b7280);
  font-size: 0.75rem;
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
