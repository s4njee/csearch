<script setup lang="ts">
import type { VoteDetail } from '~/types/congress'

const route = useRoute()
const { getVote } = useCongressApi()

const voteid = route.params.voteid as string

const {
  data: vote,
  pending: loading,
  error: fetchError,
  refresh,
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

// 'UNDEFINED' and 'NULL' are literal string values returned by the API when
// party data is missing in the source data — they are not JavaScript undefined/null.
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

const { formatDate, formatChamber, voteResultColor } = useFormatters()

// ── Presentational helpers for Nuxt UI components ──
const ANY = '__any__'

function anyModel(target: Ref<string>) {
  return computed<string>({
    get: () => (target.value === '' ? ANY : target.value),
    set: (value) => { target.value = value === ANY ? '' : value },
  })
}

const positionModel = anyModel(filterPosition)
const partyModel = anyModel(partyFilter)

const positionItems = computed(() => [
  { label: 'All positions', value: ANY },
  ...availablePositions.value.map(pos => ({ label: pos, value: pos })),
])
const partyItems = computed(() => [
  { label: 'All parties', value: ANY },
  ...availableParties.value.map(p => ({ label: p, value: p })),
])

function positionColor(position: string): 'success' | 'error' | 'neutral' {
  const p = position.toLowerCase()
  if (p === 'yea' || p === 'aye') return 'success'
  if (p === 'nay' || p === 'no') return 'error'
  return 'neutral'
}

usePageSeo({
  title: () => vote.value?.question || 'Vote',
  description: () => (vote.value
    ? `${formatChamber(vote.value.chamber)} roll-call vote · ${vote.value.result || 'Result unavailable'} · Congress ${vote.value.congress}.`
    : 'Roll-call vote detail.'),
})
</script>

<template>
  <UContainer class="space-y-8">
    <SkeletonCard v-if="loading" :rows="4" />

    <div v-else-if="errorMessage" class="space-y-3">
      <UAlert color="error" variant="subtle" icon="i-lucide-circle-alert" :description="errorMessage" />
      <UButton color="neutral" variant="outline" icon="i-lucide-refresh-cw" @click="refresh()">Try again</UButton>
    </div>

    <template v-else-if="vote">
      <UCard>
        <div class="space-y-5">
          <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
            <div>
              <p class="text-xs uppercase tracking-[0.15em] text-muted">
                <NuxtLink to="/votes" class="text-primary transition-colors hover:text-primary/80">← Votes</NuxtLink>
                · {{ formatChamber(vote.chamber) }} · Congress {{ vote.congress }}
              </p>
              <h1 class="mt-2 text-2xl font-semibold tracking-tight text-highlighted sm:text-3xl">{{ vote.question || 'Untitled vote' }}</h1>
              <p v-if="vote.bill_number && vote.bill_type" class="mt-2 text-muted">
                Related bill:
                <NuxtLink :to="`/bills/${vote.bill_type.toLowerCase()}/${vote.congress}/${vote.bill_number}`" class="text-primary underline underline-offset-2 transition-colors hover:text-primary/80">
                  {{ vote.bill_type.toUpperCase() }} {{ vote.bill_number }}
                </NuxtLink>
              </p>
            </div>

            <div class="flex flex-wrap items-center gap-3 sm:shrink-0">
              <UBadge :color="voteResultColor(vote.result)" variant="subtle" size="lg" class="whitespace-nowrap">{{ vote.result || 'Unknown' }}</UBadge>
              <UButton v-if="vote.source_url" :to="vote.source_url" target="_blank" color="neutral" variant="outline" trailing-icon="i-lucide-external-link">
                Source
              </UButton>
            </div>
          </div>

          <dl class="grid grid-cols-2 gap-x-6 gap-y-4 sm:grid-cols-4">
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Vote #</dt>
              <dd class="mt-0.5">{{ vote.votenumber || '—' }}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Date</dt>
              <dd class="mt-0.5">{{ formatDate(vote.votedate) }}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Session</dt>
              <dd class="mt-0.5">{{ vote.votesession || '—' }}</dd>
            </div>
            <div>
              <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Type</dt>
              <dd class="mt-0.5">{{ vote.votetype || '—' }}</dd>
            </div>
          </dl>
        </div>
      </UCard>

      <div v-if="Object.keys(positionCounts).length" class="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <UCard v-for="(count, pos) in positionCounts" :key="pos" :ui="{ body: 'p-4 sm:p-4' }">
          <div class="text-[0.7rem] capitalize tracking-[0.1em] text-muted">{{ pos }}</div>
          <div class="mt-1 text-2xl font-light text-highlighted">{{ count }}</div>
        </UCard>
      </div>

      <UCard v-if="vote.members?.length">
        <template #header>
          <div class="flex items-center justify-between gap-4">
            <h2 class="text-lg font-medium text-highlighted">Breakdown</h2>
            <p class="text-sm text-muted">By position and party</p>
          </div>
        </template>
        <VoteBreakdownChart :members="vote.members" />
      </UCard>

      <UCard>
        <template #header>
          <div class="flex items-center justify-between gap-4">
            <h2 class="text-lg font-medium text-highlighted">Member votes</h2>
            <p class="text-sm text-muted">{{ vote.members?.length || 0 }} members cast a position</p>
          </div>
        </template>

        <div class="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-2">
          <UFormField label="Filter position">
            <USelect v-model="positionModel" :items="positionItems" class="w-full" />
          </UFormField>
          <UFormField label="Filter party">
            <USelect v-model="partyModel" :items="partyItems" class="w-full" />
          </UFormField>
        </div>

        <p v-if="!filteredMembers.length" class="text-muted">No members match the current filters.</p>

        <div v-else class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
          <div v-for="member in filteredMembers" :key="member.bioguide_id" class="border border-default p-3 text-sm">
            <NuxtLink :to="`/members/${member.bioguide_id}`" class="block font-medium transition-colors hover:text-primary">
              {{ member.display_name || member.bioguide_id }}
            </NuxtLink>
            <div class="mt-1 flex items-center gap-2 text-xs text-muted">
              <span>{{ member.party || '?' }}</span>
              <span>{{ member.state || '?' }}</span>
            </div>
            <UBadge class="mt-2" :color="positionColor(member.position)" variant="outline" size="sm">
              Voted {{ member.position }}
            </UBadge>
          </div>
        </div>
      </UCard>
    </template>
  </UContainer>
</template>
