<script setup lang="ts">
import type { CommitteeDetail } from '~/types/congress'

const route = useRoute()
const { getCommittee } = useCongressApi()

const committeeCode = route.params.code as string

const {
  data: committee,
  pending: loading,
  error: fetchError,
} = await useAsyncData<CommitteeDetail>(
  `committee-${committeeCode}`,
  () => getCommittee(committeeCode),
)

const errorMessage = computed(() =>
  fetchError.value
    ? (fetchError.value as any)?.data?.error || fetchError.value.message || 'Unable to load committee detail.'
    : '',
)

function formatDate(value?: string | null) {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value
  return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' }).format(date)
}

function summarizeText(value?: string | null, limit = 160) {
  if (!value) return ''
  return value.length > limit ? `${value.slice(0, limit).trim()}...` : value
}
</script>

<template>
  <main class="page page--wide">
    <section v-if="loading" class="surface">
      Loading committee...
    </section>

    <section v-else-if="errorMessage" class="surface surface--error">
      {{ errorMessage }}
    </section>

    <template v-else-if="committee">
      <section class="surface">
        <div class="toolbar">
          <div>
            <p class="eyebrow">Committee · {{ committee.committee_code }}</p>
            <h1>{{ committee.committee_name || 'Unnamed Committee' }}</h1>
            <p class="lede" style="text-transform: capitalize;">{{ committee.chamber || 'Joint' }} Committee</p>
          </div>
          <NuxtLink to="/committees" class="button">
            All Committees →
          </NuxtLink>
        </div>
      </section>

      <section class="surface">
        <div class="section-title">
          <h2>Recent Bills Referred</h2>
          <p>Latest legislation referred to {{ committee.committee_name || committee.committee_code }}</p>
        </div>

        <div v-if="!committee.bills?.length" class="empty-note">
          No recently referred bills found.
        </div>
        
        <div v-else class="result-grid">
          <article v-for="bill in committee.bills" :key="bill.billid" class="result-card">
            <div class="result-card__header">
              <div>
                <p class="result-card__meta">
                  {{ bill.billtype.toUpperCase() }} {{ bill.billnumber }} · Congress {{ bill.congress }}
                </p>
                <h2>{{ bill.shorttitle || bill.officialtitle || 'Untitled bill' }}</h2>
              </div>
              <div class="result-card__links">
                <NuxtLink :to="`/bills/${bill.billtype}/${bill.congress}/${bill.billnumber}`" class="result-link result-link--primary">
                  Details →
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
