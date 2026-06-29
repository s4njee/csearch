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
  refresh,
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

const { formatDate, formatChamber, partyLabel, voteResultColor } = useFormatters()

const {
  summary: aiSummary,
  loading: aiLoading,
  error: aiError,
  fetchSummary: fetchAiSummary,
} = useAiSummary()

const aiVisible = ref(false)

function handleAiExplain() {
  if (aiSummary.value) {
    aiVisible.value = !aiVisible.value
    return
  }
  aiVisible.value = true
  fetchAiSummary(billtype, congress, billnumber)
}

function hasBioguideId(value?: string | null) {
  return typeof value === 'string' && /^[A-Z0-9]+$/i.test(value)
}

const billCode = computed(() => `${(categoryMeta.value?.shortLabel ?? billtype).toUpperCase()} ${billnumber}`)

usePageSeo({
  title: () => (bill.value
    ? (bill.value.shorttitle || bill.value.officialtitle || billCode.value)
    : billCode.value),
  description: () => (bill.value?.summary_text
    ? bill.value.summary_text.slice(0, 200)
    : `Sponsors, action history, cosponsors, and floor votes for ${billCode.value}, Congress ${congress}.`),
})
</script>

<template>
  <UContainer class="space-y-8">
    <SkeletonCard v-if="loading" :rows="6" />

    <div v-else-if="errorMessage" class="space-y-3">
      <UAlert color="error" variant="subtle" icon="i-lucide-circle-alert" :description="errorMessage" />
      <UButton color="neutral" variant="outline" icon="i-lucide-refresh-cw" @click="refresh()">Try again</UButton>
    </div>

    <template v-else-if="bill">
      <!-- HEADER -->
      <UCard>
        <div class="space-y-5">
          <div>
            <p class="text-xs uppercase tracking-[0.15em] text-muted">
              <NuxtLink :to="`/bills/${billtype}`" class="text-primary transition-colors hover:text-primary/80">
                ← {{ categoryMeta?.longLabel ?? billtype.toUpperCase() }}
              </NuxtLink>
              · Congress {{ congress }}
            </p>
            <h1 class="mt-2 text-2xl font-semibold tracking-tight text-highlighted sm:text-3xl">
              {{ bill.shorttitle || bill.officialtitle || `${(categoryMeta?.shortLabel ?? billtype).toUpperCase()} ${billnumber}` }}
            </h1>
            <p v-if="bill.officialtitle && bill.shorttitle" class="mt-2 text-muted">
              {{ bill.officialtitle }}
            </p>
          </div>

          <dl class="grid grid-cols-2 gap-x-6 gap-y-4 sm:grid-cols-3 lg:grid-cols-4">
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Bill</dt>
              <dd class="mt-0.5">{{ categoryMeta?.shortLabel ?? billtype }} {{ billnumber }}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Congress</dt>
              <dd class="mt-0.5">{{ congress }}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Introduced</dt>
              <dd class="mt-0.5">{{ formatDate(bill.introducedat) }}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Status date</dt>
              <dd class="mt-0.5">{{ formatDate(bill.statusat) }}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Last action</dt>
              <dd class="mt-0.5">{{ formatDate(bill.latest_action_date) }}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Origin chamber</dt>
              <dd class="mt-0.5">{{ bill.origin_chamber || '—' }}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Policy area</dt>
              <dd class="mt-0.5">{{ bill.policy_area || '—' }}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Sponsor</dt>
              <dd class="mt-0.5">
                <NuxtLink v-if="bill.sponsor_bioguide_id" :to="`/members/${bill.sponsor_bioguide_id}`" class="transition-colors hover:text-primary">
                  {{ bill.sponsor_name }}
                </NuxtLink>
                <template v-else>{{ bill.sponsor_name || '—' }}</template>
              </dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Party</dt>
              <dd class="mt-0.5">{{ partyLabel(bill.sponsor_party) || '—' }}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">State</dt>
              <dd class="mt-0.5">{{ bill.sponsor_state || '—' }}</dd>
            </div>
            <div v-if="bill.committees && bill.committees.length" class="col-span-2">
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Committees</dt>
              <dd class="mt-0.5 flex flex-col gap-1">
                <NuxtLink v-for="committee in bill.committees" :key="committee.committee_code" :to="`/committees/${committee.committee_code}`" class="transition-colors hover:text-primary">
                  {{ committee.committee_name || committee.committee_code }}
                </NuxtLink>
              </dd>
            </div>
          </dl>
        </div>
      </UCard>

      <!-- SUMMARY -->
      <UCard v-if="bill.summary_text">
        <template #header>
          <div class="flex items-center justify-between gap-4">
            <h2 class="text-lg font-medium text-highlighted">Summary</h2>
            <p v-if="bill.summary_date" class="text-sm text-muted">As of {{ formatDate(bill.summary_date) }}</p>
          </div>
        </template>
        <p class="whitespace-pre-wrap leading-relaxed">{{ bill.summary_text }}</p>
      </UCard>

      <!-- AI EXPLANATION -->
      <UCard>
        <template #header>
          <div class="flex items-center justify-between gap-4">
            <h2 class="text-lg font-medium text-highlighted">Plain-English explanation</h2>
            <UButton
              icon="i-lucide-sparkles"
              size="xs"
              color="primary"
              variant="soft"
              :loading="aiLoading"
              @click="handleAiExplain"
            >
              {{ aiSummary ? (aiVisible ? 'Hide' : 'Show') : 'AI Explain' }}
            </UButton>
          </div>
        </template>

        <UAlert
          v-if="aiError"
          color="error"
          variant="subtle"
          icon="i-lucide-circle-alert"
          :description="aiError"
        />

        <p v-else-if="aiVisible && aiSummary" class="whitespace-pre-wrap leading-relaxed text-muted">{{ aiSummary }}</p>

        <p v-else-if="!aiLoading" class="text-muted">
          Generate a plain-English explanation of this bill — what it does, who sponsors it, and what's happened to it so far.
        </p>
      </UCard>

      <!-- ACTION HISTORY -->
      <UCard>
        <template #header>
          <div class="flex items-center justify-between gap-4">
            <h2 class="text-lg font-medium text-highlighted">Action history</h2>
            <p class="text-sm text-muted">{{ bill.actions.length }} recorded {{ bill.actions.length === 1 ? 'action' : 'actions' }}</p>
          </div>
        </template>

        <p v-if="!bill.actions.length" class="text-muted">No actions on record.</p>

        <ol v-else class="flex flex-col">
          <li
            v-for="(action, index) in bill.actions"
            :key="index"
            class="grid grid-cols-[8rem_1fr] gap-4 border-b border-default py-3 text-sm last:border-b-0"
          >
            <span class="whitespace-nowrap text-muted">{{ formatDate(action.acted_at) }}</span>
            <div class="flex flex-col gap-1">
              <span>{{ action.action_text || '—' }}</span>
              <span v-if="action.action_type" class="text-xs uppercase tracking-[0.06em] text-dimmed">{{ action.action_type }}</span>
            </div>
          </li>
        </ol>
      </UCard>

      <!-- COSPONSORS -->
      <UCard>
        <template #header>
          <div class="flex items-center justify-between gap-4">
            <h2 class="text-lg font-medium text-highlighted">Cosponsors</h2>
            <p class="text-sm text-muted">{{ bill.cosponsors.length }} {{ bill.cosponsors.length === 1 ? 'cosponsor' : 'cosponsors' }}</p>
          </div>
        </template>

        <p v-if="!bill.cosponsors.length" class="text-muted">No cosponsors on record.</p>

        <div v-else class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
          <div
            v-for="cosponsor in bill.cosponsors"
            :key="cosponsor.bioguide_id || `${cosponsor.full_name || 'cosponsor'}-${cosponsor.sponsorship_date || 'unknown'}`"
            class="border border-default p-3 text-sm"
          >
            <NuxtLink
              v-if="hasBioguideId(cosponsor.bioguide_id)"
              :to="`/members/${cosponsor.bioguide_id}`"
              class="block font-medium transition-colors hover:text-primary"
            >
              {{ cosponsor.full_name || cosponsor.bioguide_id }}
            </NuxtLink>
            <span v-else class="block font-medium">{{ cosponsor.full_name || 'Unknown cosponsor' }}</span>
            <div class="mt-1 flex items-center gap-2 text-xs text-muted">
              <span>{{ cosponsor.party || '?' }}</span>
              <span>{{ cosponsor.state || '?' }}</span>
              <UBadge v-if="cosponsor.is_original_cosponsor" color="primary" variant="outline" size="sm">Original</UBadge>
            </div>
            <div class="mt-1 text-xs text-dimmed">{{ formatDate(cosponsor.sponsorship_date) }}</div>
          </div>
        </div>
      </UCard>

      <!-- FLOOR VOTES -->
      <UCard>
        <template #header>
          <div class="flex items-center justify-between gap-4">
            <h2 class="text-lg font-medium text-highlighted">Floor votes</h2>
            <p class="text-sm text-muted">{{ bill.votes.length }} recorded {{ bill.votes.length === 1 ? 'vote' : 'votes' }}</p>
          </div>
        </template>

        <p v-if="!bill.votes.length" class="text-muted">No floor votes linked to this bill.</p>

        <div v-else class="grid grid-cols-1 gap-4 lg:grid-cols-2">
          <div v-for="vote in bill.votes" :key="vote.voteid" class="border border-default p-4">
            <div class="flex items-start justify-between gap-3">
              <div>
                <p class="text-xs uppercase tracking-[0.1em] text-muted">{{ formatChamber(vote.chamber) }} · Congress {{ vote.congress }}</p>
                <NuxtLink :to="`/votes/${vote.voteid}`" class="mt-1 block font-medium text-highlighted transition-colors hover:text-primary">
                  {{ vote.question || 'Vote' }}
                </NuxtLink>
              </div>
              <UBadge :color="voteResultColor(vote.result)" variant="subtle">{{ vote.result || 'Unknown' }}</UBadge>
            </div>
            <dl class="mt-3 grid grid-cols-2 gap-x-6 gap-y-2 text-sm">
              <div>
                <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Date</dt>
                <dd class="mt-0.5">{{ formatDate(vote.votedate) }}</dd>
              </div>
              <div>
                <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Type</dt>
                <dd class="mt-0.5">{{ vote.votetype || '—' }}</dd>
              </div>
            </dl>
          </div>
        </div>
      </UCard>
    </template>
  </UContainer>
</template>
