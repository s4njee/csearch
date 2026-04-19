<script setup lang="ts">
import { BILL_TYPE_OPTIONS } from '~/types/congress'
import type { BillDetail } from '~/types/congress'

const route = useRoute()
const { getBill } = useCongressApi()

const billtype = route.params.category as string
const congress = route.params.congress as string
const billnumber = route.params.number as string

const categoryMeta = computed(() => BILL_TYPE_OPTIONS.find(opt => opt.code === billtype))

const {
  data: bill,
  pending: loading,
  error: fetchError,
} = await useAsyncData<BillDetail>(
  `bill-${billtype}-${congress}-${billnumber}`,
  () => getBill(billtype, congress, billnumber),
  { lazy: true }
)

const errorMessage = computed(() =>
  fetchError.value
    ? (fetchError.value as any)?.data?.error || fetchError.value.message || 'Unable to load bill.'
    : '',
)

const { formatDate, formatChamber, partyLabel, voteResultClass } = useFormatters()

function hasBioguideId(value?: string | null) {
  return typeof value === 'string' && /^[A-Z0-9]+$/i.test(value)
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
            <dd>
              <NuxtLink v-if="bill.sponsor_bioguide_id" :to="`/members/${bill.sponsor_bioguide_id}`" class="link-plain">
                {{ bill.sponsor_name }}
              </NuxtLink>
              <template v-else>
                {{ bill.sponsor_name || '—' }}
              </template>
            </dd>
          </div>
          <div>
            <dt>Party</dt>
            <dd>{{ partyLabel(bill.sponsor_party) || '—' }}</dd>
          </div>
          <div>
            <dt>State</dt>
            <dd>{{ bill.sponsor_state || '—' }}</dd>
          </div>
          <div v-if="bill.committees && bill.committees.length">
            <dt>Committees</dt>
            <dd style="display: flex; flex-direction: column; gap: 0.25rem;">
              <NuxtLink v-for="committee in bill.committees" :key="committee.committee_code" :to="`/committees/${committee.committee_code}`" class="link-plain">
                {{ committee.committee_name || committee.committee_code }}
              </NuxtLink>
            </dd>
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
            :key="cosponsor.bioguide_id || `${cosponsor.full_name || 'cosponsor'}-${cosponsor.sponsorship_date || 'unknown'}`"
            class="cosponsor-card"
          >
            <NuxtLink
              v-if="hasBioguideId(cosponsor.bioguide_id)"
              :to="`/members/${cosponsor.bioguide_id}`"
              class="cosponsor-card__name link-plain"
              style="display: block;"
            >
              {{ cosponsor.full_name || cosponsor.bioguide_id }}
            </NuxtLink>
            <span v-else class="cosponsor-card__name" style="display: block;">
              {{ cosponsor.full_name || 'Unknown cosponsor' }}
            </span>
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
                  {{ formatChamber(vote.chamber) }} · Congress {{ vote.congress }}
                </p>
                <h3>
                  <NuxtLink :to="`/votes/${vote.voteid}`" class="link-plain">
                    {{ vote.question || 'Vote' }}
                  </NuxtLink>
                </h3>
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
