<script setup lang="ts">
import type { RepresentativeRecord } from '~/types/congress'

const route = useRoute()
const api = useCongressApi()

const zip = computed(() => {
  const value = route.query.zip
  return typeof value === 'string' ? value : ''
})

const { data, pending, error } = await useAsyncData(
  `representatives-${zip.value}`,
  () => zip.value ? api.getRepresentatives(zip.value) : Promise.resolve(null),
  { watch: [zip] },
)

const senators = computed<RepresentativeRecord[]>(() => data.value?.senators ?? [])
const houseMembers = computed<RepresentativeRecord[]>(() => data.value?.housemembers ?? [])

const notFound = computed(() => !pending.value && zip.value && !data.value?.senators?.length && !data.value?.housemembers?.length)

function partyLabel(party: string | null | undefined) {
  if (!party) return ''
  if (party === 'D') return 'Democrat'
  if (party === 'R') return 'Republican'
  if (party === 'I') return 'Independent'
  return party
}

function partyClass(party: string | null | undefined) {
  if (party === 'D') return 'party--dem'
  if (party === 'R') return 'party--rep'
  return 'party--ind'
}
</script>

<template>
  <main class="page">
    <section class="surface">
      <div class="section-title">
        <h1>Who represents you?</h1>
        <p>{{ zip ? `Showing results for ZIP ${zip}` : 'Enter a ZIP code to find your congressional representatives.' }}</p>
      </div>

      <form class="lookup-form representatives-lookup" action="/representatives" method="get">
        <input
          class="field-input"
          type="text"
          name="zip"
          inputmode="numeric"
          autocomplete="postal-code"
          pattern="[0-9]{5}"
          maxlength="5"
          placeholder="90210"
          :value="zip"
          aria-label="ZIP code"
        >
        <button class="button button--primary" type="submit">
          Find reps
        </button>
      </form>

      <div v-if="pending" class="empty-note representatives-note">
        Looking up representatives…
      </div>

      <div v-else-if="error" class="empty-note representatives-note">
        {{ (error as any)?.data?.error ?? 'Something went wrong. Please try again.' }}
      </div>

      <div v-else-if="notFound" class="empty-note representatives-note">
        No representatives found for ZIP {{ zip }}. Try a different ZIP code.
      </div>

      <div v-else-if="zip && data" class="reps-results">
        <div class="reps-col">
          <h2 class="reps-col-title">Senators</h2>
          <p v-if="!senators.length" class="empty-note">No senators found.</p>
          <ul v-else class="reps-list">
            <li v-for="rep in senators" :key="rep.bioguide_id" class="rep-card">
              <NuxtLink :to="`/members/${rep.bioguide_id}`" class="rep-name">{{ rep.name }}</NuxtLink>
              <div class="rep-meta">
                <span :class="['rep-party', partyClass(rep.party)]">{{ partyLabel(rep.party) }}</span>
                <span class="rep-state">{{ rep.state }}</span>
              </div>
            </li>
          </ul>
        </div>

        <div class="reps-col">
          <h2 class="reps-col-title">House Members</h2>
          <p v-if="!houseMembers.length" class="empty-note">No house members found.</p>
          <ul v-else class="reps-list">
            <li v-for="rep in houseMembers" :key="rep.bioguide_id" class="rep-card">
              <NuxtLink :to="`/members/${rep.bioguide_id}`" class="rep-name">{{ rep.name }}</NuxtLink>
              <div class="rep-meta">
                <span :class="['rep-party', partyClass(rep.party)]">{{ partyLabel(rep.party) }}</span>
                <span class="rep-state">{{ rep.state }}</span>
              </div>
            </li>
          </ul>
        </div>
      </div>

      <p v-else class="empty-note representatives-note">
        District matches will appear here.
      </p>
    </section>
  </main>
</template>

<style scoped>
.representatives-lookup {
  margin-top: 1.25rem;
  max-width: 36rem;
}

.representatives-note {
  margin-top: 1.25rem;
}

.reps-results {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 2rem;
  margin-top: 2rem;
}

@media (max-width: 640px) {
  .reps-results {
    grid-template-columns: 1fr;
  }
}

.reps-col-title {
  font-size: 1rem;
  font-weight: 600;
  margin-bottom: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  opacity: 0.6;
}

.reps-list {
  list-style: none;
  padding: 0;
  margin: 0;
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.rep-card {
  padding: 0.875rem 1rem;
  border: 1px solid var(--border, #e2e8f0);
  border-radius: 0.5rem;
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.rep-name {
  font-weight: 600;
  text-decoration: none;
  color: inherit;
}

.rep-name:hover {
  text-decoration: underline;
}

.rep-meta {
  display: flex;
  gap: 0.5rem;
  font-size: 0.875rem;
  opacity: 0.75;
}

.rep-party {
  font-weight: 500;
}

.party--dem { color: #3b82f6; }
.party--rep { color: #ef4444; }
.party--ind { color: #8b5cf6; }
</style>
