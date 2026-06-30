<script setup lang="ts">
import type { CommitteeRecord } from '~/types/congress'

const { getCommittees } = useCongressApi()
const { formatNumber } = useFormatters()
const { data: committees, pending: loading, error: fetchError } = await useAsyncData<CommitteeRecord[]>(
  'committees-list',
  () => getCommittees()
)

const filterChamber = ref('')

const availableChambers = computed(() => {
  if (!committees.value) return []
  const set = new Set(committees.value.map(c => c.chamber).filter(Boolean) as string[])
  return Array.from(set).sort()
})

const filteredCommittees = computed(() => {
  let results = committees.value || []
  if (filterChamber.value) {
    results = results.filter(c => c.chamber === filterChamber.value)
  }
  return results
})

const errorMessage = computed(() =>
  fetchError.value ? (fetchError.value as any)?.data?.error || 'Unable to load committees.' : '',
)

const houseCommittees = computed(() => filteredCommittees.value.filter(c => c.chamber?.toLowerCase() === 'house'))
const senateCommittees = computed(() => filteredCommittees.value.filter(c => c.chamber?.toLowerCase() === 'senate'))
const jointCommittees = computed(() => filteredCommittees.value.filter(c => {
  const ch = c.chamber?.toLowerCase()
  return ch !== 'house' && ch !== 'senate'
}))

// ── Presentational helpers for Nuxt UI components ──
const ANY = '__any__'

const chamberModel = computed<string>({
  get: () => (filterChamber.value === '' ? ANY : filterChamber.value),
  set: (value) => { filterChamber.value = value === ANY ? '' : value },
})

function chamberLabel(ch?: string | null) {
  const c = ch?.toLowerCase()
  return c === 'senate' ? 'Senate' : c === 'house' ? 'House' : ch || 'Unknown'
}

const chamberItems = computed(() => [
  { label: 'Any chamber', value: ANY },
  ...availableChambers.value.map(ch => ({ label: chamberLabel(ch), value: ch })),
])

const committeeGroups = computed(() => [
  { title: 'House Committees', items: houseCommittees.value },
  { title: 'Senate Committees', items: senateCommittees.value },
  { title: 'Joint Committees', items: jointCommittees.value },
].filter(group => group.items.length > 0))

usePageSeo({
  title: 'Committees',
  description: 'Browse U.S. House, Senate, and Joint congressional committees and the bills referred to them.',
})
</script>

<template>
  <UContainer class="space-y-8">
    <UCard>
      <div class="space-y-5">
        <div>
          <p class="text-xs font-medium uppercase tracking-[0.2em] text-primary">Committees</p>
          <h1 class="mt-2 text-2xl font-semibold tracking-tight text-highlighted sm:text-3xl">Browse committees</h1>
          <p class="mt-1 max-w-2xl text-muted">
            Explore legislative action grouped by standard House, Senate, and Joint congressional committees.
          </p>
        </div>

        <UFormField label="Chamber" class="max-w-xs">
          <USelect v-model="chamberModel" :items="chamberItems" class="w-full" />
        </UFormField>
      </div>
    </UCard>

    <div v-if="loading" class="grid grid-cols-1 gap-6 lg:grid-cols-2">
      <SkeletonCard v-for="n in 4" :key="n" :rows="2" />
    </div>

    <UAlert v-else-if="errorMessage" color="error" variant="subtle" icon="i-lucide-circle-alert" :description="errorMessage" />

    <template v-else-if="committees">
      <UCard v-for="group in committeeGroups" :key="group.title">
        <template #header>
          <div class="flex items-center justify-between gap-4">
            <h2 class="text-lg font-medium text-highlighted">{{ group.title }}</h2>
            <p class="text-sm text-muted">{{ group.items.length }} active</p>
          </div>
        </template>

        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <NuxtLink
            v-for="c in group.items"
            :key="c.committee_code"
            :to="`/committees/${c.committee_code}`"
            class="group flex items-center justify-between gap-3 border border-default p-4 transition-colors hover:border-primary"
          >
            <div>
              <div class="text-sm font-semibold text-primary">{{ c.committee_code }}</div>
              <div class="mt-0.5 text-highlighted">{{ c.committee_name || 'Unnamed Committee' }}</div>
              <p class="mt-1 text-xs text-muted">{{ formatNumber(c.bill_count || 0) }} bills referenced</p>
            </div>
            <span class="text-dimmed transition-colors group-hover:text-primary">→</span>
          </NuxtLink>
        </div>
      </UCard>
    </template>
  </UContainer>
</template>
