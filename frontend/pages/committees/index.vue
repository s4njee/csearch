<script setup lang="ts">
import type { CommitteeRecord } from '~/types/congress'

const { getCommittees } = useCongressApi()
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
</script>

<template>
  <main class="page page--wide">
    <section class="hero-panel hero-panel--primary" style="margin-bottom: 1.5rem">
      <h1 class="hero-title">Browse Committees</h1>
      <p class="hero-copy" style="margin-top: 0.5rem">
        Explore legislative action grouped by standard House, Senate, and Joint congressional committees.
      </p>

      <div class="control-grid" style="margin-top: 1.5rem">
        <label class="field">
          <span>Chamber</span>
          <select v-model="filterChamber" class="field-input">
            <option value="">Any chamber</option>
            <option v-for="ch in availableChambers" :key="ch" :value="ch">{{ ch?.toLowerCase() === 'senate' ? 'Senate' : ch?.toLowerCase() === 'house' ? 'House' : ch || 'Unknown' }}</option>
          </select>
        </label>
      </div>
    </section>

    <section v-if="loading" class="surface">
      Loading committees...
    </section>

    <section v-else-if="errorMessage" class="surface surface--error">
      {{ errorMessage }}
    </section>

    <template v-else-if="committees">
      <!-- House Committees -->
      <section v-if="houseCommittees.length" class="surface" style="margin-bottom: 1rem;">
        <div class="section-title">
          <h2>House Committees</h2>
          <p>{{ houseCommittees.length }} active</p>
        </div>
        <div class="result-grid">
          <NuxtLink
            v-for="c in houseCommittees"
            :key="c.committee_code"
            :to="`/committees/${c.committee_code}`"
            class="track-card"
          >
            <div>
              <div class="track-card__code">{{ c.committee_code }}</div>
              <div>{{ c.committee_name || 'Unnamed Committee' }}</div>
              <p style="margin-top: 0.25rem; font-size: 0.75rem;">{{ c.bill_count || 0 }} bills referenced</p>
            </div>
            <span class="track-card__arrow">→</span>
          </NuxtLink>
        </div>
      </section>

      <!-- Senate Committees -->
      <section v-if="senateCommittees.length" class="surface" style="margin-bottom: 1rem;">
        <div class="section-title">
          <h2>Senate Committees</h2>
          <p>{{ senateCommittees.length }} active</p>
        </div>
        <div class="result-grid">
          <NuxtLink
            v-for="c in senateCommittees"
            :key="c.committee_code"
            :to="`/committees/${c.committee_code}`"
            class="track-card"
          >
            <div>
              <div class="track-card__code">{{ c.committee_code }}</div>
              <div>{{ c.committee_name || 'Unnamed Committee' }}</div>
              <p style="margin-top: 0.25rem; font-size: 0.75rem;">{{ c.bill_count || 0 }} bills referenced</p>
            </div>
            <span class="track-card__arrow">→</span>
          </NuxtLink>
        </div>
      </section>

      <!-- Joint/Other Committees -->
      <section v-if="jointCommittees.length" class="surface" style="margin-bottom: 1rem;">
        <div class="section-title">
          <h2>Joint Committees</h2>
          <p>{{ jointCommittees.length }} active</p>
        </div>
        <div class="result-grid">
          <NuxtLink
            v-for="c in jointCommittees"
            :key="c.committee_code"
            :to="`/committees/${c.committee_code}`"
            class="track-card"
          >
            <div>
              <div class="track-card__code">{{ c.committee_code }}</div>
              <div>{{ c.committee_name || 'Unnamed Committee' }}</div>
              <p style="margin-top: 0.25rem; font-size: 0.75rem;">{{ c.bill_count || 0 }} bills referenced</p>
            </div>
            <span class="track-card__arrow">→</span>
          </NuxtLink>
        </div>
      </section>
    </template>
  </main>
</template>
