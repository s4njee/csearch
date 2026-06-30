<script setup lang="ts">
import type { MemberDetail } from '~/types/congress'

const route = useRoute()
const { getMember } = useCongressApi()

const bioguideId = route.params.bioguide_id as string

const {
  data: member,
  pending: loading,
  error: fetchError,
  refresh,
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

const { formatDate, formatChamber, partyLabel, voteResultColor, summarizeText, formatNumber } = useFormatters()

function positionColor(position?: string | null): 'success' | 'error' | 'neutral' {
  const p = String(position || '').toLowerCase()
  if (p === 'yea' || p === 'aye') return 'success'
  if (p === 'nay' || p === 'no') return 'error'
  return 'neutral'
}

usePageSeo({
  title: () => member.value?.name || 'Member',
  description: () => (member.value
    ? `${member.value.name}${member.value.party ? ` (${partyLabel(member.value.party)})` : ''} — sponsored legislation and recent floor votes.`
    : 'Member profile.'),
})
</script>

<template>
  <UContainer class="space-y-8">
    <SkeletonCard v-if="loading" :rows="4" />

    <div v-else-if="errorMessage" class="space-y-3">
      <UAlert color="error" variant="subtle" icon="i-lucide-circle-alert" :description="errorMessage" />
      <UButton color="neutral" variant="outline" icon="i-lucide-refresh-cw" @click="refresh()">Try again</UButton>
    </div>

    <template v-else-if="member">
      <UCard>
        <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <p class="text-xs uppercase tracking-[0.15em] text-muted">Member profile · {{ member.bioguide_id }}</p>
            <h1 class="mt-2 text-2xl font-semibold tracking-tight text-highlighted sm:text-3xl">{{ member.name }}</h1>
            <p class="mt-1 text-muted">{{ partyLabel(member.party) }} · {{ member.state || 'Unknown State' }}</p>
          </div>
          <UButton :to="`https://bioguide.congress.gov/search/bio/${member.bioguide_id}`" target="_blank" color="neutral" variant="outline" trailing-icon="i-lucide-external-link">
            Bioguide
          </UButton>
        </div>
      </UCard>

      <div class="grid grid-cols-2 gap-4">
        <UCard :ui="{ body: 'p-4 sm:p-4' }">
          <div class="text-[0.7rem] uppercase tracking-[0.1em] text-muted">Sponsored bills</div>
          <div class="mt-1 text-2xl font-light text-highlighted">{{ formatNumber(member.counts.sponsored || 0) }}</div>
        </UCard>
        <UCard :ui="{ body: 'p-4 sm:p-4' }">
          <div class="text-[0.7rem] uppercase tracking-[0.1em] text-muted">Cosponsored bills</div>
          <div class="mt-1 text-2xl font-light text-highlighted">{{ formatNumber(member.counts.cosponsored || 0) }}</div>
        </UCard>
      </div>

      <UCard>
        <template #header>
          <div>
            <h2 class="text-lg font-medium text-highlighted">Recent sponsored legislation</h2>
            <p class="mt-0.5 text-sm text-muted">Latest bills sponsored by {{ member.name }}</p>
          </div>
        </template>

        <p v-if="!member.sponsoredBills?.length" class="text-muted">No recently sponsored bills found.</p>

        <div v-else class="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <div v-for="bill in member.sponsoredBills" :key="bill.billid" class="border border-default p-5">
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

      <UCard>
        <template #header>
          <div>
            <h2 class="text-lg font-medium text-highlighted">Recent floor votes</h2>
            <p class="mt-0.5 text-sm text-muted">How {{ member.name }} voted on recent chamber actions</p>
          </div>
        </template>

        <p v-if="!member.recentVotes?.length" class="text-muted">No recent floor votes found for this member.</p>

        <div v-else class="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <div v-for="vote in member.recentVotes" :key="vote.voteid" class="border border-default p-5">
            <div class="flex items-start justify-between gap-3">
              <div>
                <p class="text-xs uppercase tracking-[0.1em] text-muted">{{ formatChamber(vote.chamber) }} · Congress {{ vote.congress }}</p>
                <NuxtLink :to="`/votes/${vote.voteid}`" class="mt-1 block font-medium text-highlighted transition-colors hover:text-primary">
                  {{ vote.question || 'Untitled vote' }}
                </NuxtLink>
              </div>
              <div class="flex flex-col items-end gap-2">
                <UBadge :color="voteResultColor(vote.result)" variant="subtle">{{ vote.result || 'Unknown' }}</UBadge>
                <UBadge :color="positionColor(vote.position)" variant="outline" size="sm">
                  Voted {{ vote.position || 'Unknown' }}
                </UBadge>
              </div>
            </div>

            <dl class="mt-4 grid grid-cols-3 gap-x-6 gap-y-3 text-sm">
              <div>
                <dt class="text-xs uppercase tracking-[0.1em] text-dimmed">Vote #</dt>
                <dd class="mt-0.5">{{ vote.votenumber || '—' }}</dd>
              </div>
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
