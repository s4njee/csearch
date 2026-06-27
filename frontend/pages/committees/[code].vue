<script setup lang="ts">
import type { CommitteeDetail } from '~/types/congress'

const route = useRoute()
const { getCommittee } = useCongressApi()

const committeeCode = route.params.code as string

const {
  data: committee,
  pending: loading,
  error: fetchError,
  refresh,
} = await useAsyncData<CommitteeDetail>(
  `committee-${committeeCode}`,
  () => getCommittee(committeeCode),
  { lazy: true }
)

const errorMessage = computed(() =>
  fetchError.value
    ? (fetchError.value as any)?.data?.error || fetchError.value.message || 'Unable to load committee detail.'
    : '',
)

const { formatDate, summarizeText, formatNumber } = useFormatters()

usePageSeo({
  title: () => committee.value?.committee_name || 'Committee',
  description: () => (committee.value
    ? `Recent bills referred to the ${committee.value.committee_name || committee.value.committee_code}.`
    : 'Congressional committee detail.'),
})
</script>

<template>
  <UContainer class="space-y-8">
    <SkeletonCard v-if="loading" :rows="2" />

    <div v-else-if="errorMessage" class="space-y-3">
      <UAlert color="error" variant="subtle" icon="i-lucide-circle-alert" :description="errorMessage" />
      <UButton color="neutral" variant="outline" icon="i-lucide-refresh-cw" @click="refresh()">Try again</UButton>
    </div>

    <template v-else-if="committee">
      <UCard>
        <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <p class="text-xs uppercase tracking-[0.15em] text-muted">Committee · {{ committee.committee_code }}</p>
            <h1 class="mt-2 text-2xl font-semibold tracking-tight text-highlighted sm:text-3xl">{{ committee.committee_name || 'Unnamed Committee' }}</h1>
            <p class="mt-1 capitalize text-muted">{{ committee.chamber || 'Joint' }} committee</p>
          </div>
          <UButton to="/committees" color="neutral" variant="outline" trailing-icon="i-lucide-arrow-right">
            All committees
          </UButton>
        </div>
      </UCard>

      <UCard>
        <template #header>
          <div>
            <h2 class="text-lg font-medium text-highlighted">Recent bills referred</h2>
            <p class="mt-0.5 text-sm text-muted">Latest legislation referred to {{ committee.committee_name || committee.committee_code }}</p>
          </div>
        </template>

        <p v-if="!committee.bills?.length" class="text-muted">No recently referred bills found.</p>

        <div v-else class="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <div v-for="bill in committee.bills" :key="bill.billid" class="border border-default p-5">
            <p class="text-xs uppercase tracking-[0.15em] text-primary">
              {{ bill.billtype.toUpperCase() }} {{ bill.billnumber }} · Congress {{ bill.congress }}
            </p>
            <NuxtLink :to="`/bills/${bill.billtype}/${bill.congress}/${bill.billnumber}`" class="mt-2 block text-lg font-medium text-highlighted transition-colors hover:text-primary">
              {{ bill.shorttitle || bill.officialtitle || 'Untitled bill' }}
            </NuxtLink>
            <p class="mt-3 text-sm text-muted">{{ summarizeText(bill.summary_text || bill.officialtitle || bill.shorttitle) }}</p>

            <dl class="mt-4 grid grid-cols-2 gap-x-6 gap-y-3 text-sm">
              <div>
                <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Introduced</dt>
                <dd class="mt-0.5">{{ formatDate(bill.introducedat) }}</dd>
              </div>
              <div>
                <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Status</dt>
                <dd class="mt-0.5">{{ formatDate(bill.statusat) }}</dd>
              </div>
              <div>
                <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Policy area</dt>
                <dd class="mt-0.5">{{ bill.policy_area || '—' }}</dd>
              </div>
              <div>
                <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Cosponsors</dt>
                <dd class="mt-0.5">{{ formatNumber(bill.cosponsor_count || 0) }}</dd>
              </div>
            </dl>
          </div>
        </div>
      </UCard>
    </template>
  </UContainer>
</template>
