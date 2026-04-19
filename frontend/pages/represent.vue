<script setup lang="ts">
import type { MembersByState } from '~/types/congress'

const { getMembersByState } = useCongressApi()
const { partyLabel } = useFormatters()

const zipInput = ref('')
const loading = ref(false)
const error = ref('')
const detectedState = ref('')
const result = ref<MembersByState | null>(null)

const STATE_NAMES: Record<string, string> = {
  AL: 'Alabama', AK: 'Alaska', AZ: 'Arizona', AR: 'Arkansas', CA: 'California',
  CO: 'Colorado', CT: 'Connecticut', DE: 'Delaware', FL: 'Florida', GA: 'Georgia',
  HI: 'Hawaii', ID: 'Idaho', IL: 'Illinois', IN: 'Indiana', IA: 'Iowa',
  KS: 'Kansas', KY: 'Kentucky', LA: 'Louisiana', ME: 'Maine', MD: 'Maryland',
  MA: 'Massachusetts', MI: 'Michigan', MN: 'Minnesota', MS: 'Mississippi', MO: 'Missouri',
  MT: 'Montana', NE: 'Nebraska', NV: 'Nevada', NH: 'New Hampshire', NJ: 'New Jersey',
  NM: 'New Mexico', NY: 'New York', NC: 'North Carolina', ND: 'North Dakota', OH: 'Ohio',
  OK: 'Oklahoma', OR: 'Oregon', PA: 'Pennsylvania', RI: 'Rhode Island', SC: 'South Carolina',
  SD: 'South Dakota', TN: 'Tennessee', TX: 'Texas', UT: 'Utah', VT: 'Vermont',
  VA: 'Virginia', WA: 'Washington', WV: 'West Virginia', WI: 'Wisconsin', WY: 'Wyoming',
  DC: 'District of Columbia', PR: 'Puerto Rico', GU: 'Guam', VI: 'U.S. Virgin Islands',
  AS: 'American Samoa', MP: 'Northern Mariana Islands',
}

function stateName(code: string) {
  return STATE_NAMES[code] ?? code
}

function partyColor(party?: string | null) {
  const p = (party ?? '').toUpperCase()
  if (p === 'D') return 'var(--accent-senate)'
  if (p === 'R') return 'var(--accent-house)'
  return 'var(--text-muted)'
}

async function lookup() {
  const zip = zipInput.value.trim()
  if (!/^\d{5}$/.test(zip)) {
    error.value = 'Please enter a valid 5-digit ZIP code.'
    return
  }

  loading.value = true
  error.value = ''
  result.value = null
  detectedState.value = ''

  try {
    // Resolve ZIP → state abbreviation via free public API (no key required)
    const geo = await $fetch<any>(`https://api.zippopotam.us/us/${zip}`)
    const stateCode: string = geo?.places?.[0]?.['state abbreviation']
    if (!stateCode) {
      error.value = 'Could not find a US state for that ZIP code.'
      return
    }
    detectedState.value = stateCode

    result.value = await getMembersByState(stateCode)
  }
  catch {
    error.value = 'Something went wrong. Please try again.'
  }
  finally {
    loading.value = false
  }
}
</script>

<template>
  <main class="page page--wide">
    <section class="hero-grid">
      <article class="hero-panel hero-panel--primary">
        <p class="eyebrow">Find Your Representatives</p>
        <h1 class="hero-title">Who represents you?</h1>
        <p class="hero-copy">
          Enter your ZIP code to find the senators and House members who represent you in Congress,
          with links to their full legislative profiles.
        </p>
      </article>

      <article class="hero-panel">
        <div class="section-title">
          <h2>ZIP code lookup</h2>
        </div>

        <form class="control-grid" @submit.prevent="lookup">
          <div class="field field--full">
            <span>ZIP code</span>
            <input
              v-model="zipInput"
              class="field-input"
              type="text"
              inputmode="numeric"
              maxlength="5"
              placeholder="e.g. 90210"
              autocomplete="postal-code"
            >
          </div>

          <button class="button button--primary" type="submit" :disabled="loading">
            {{ loading ? 'Looking up…' : 'Find my representatives' }}
          </button>
        </form>

        <p v-if="error" class="lookup-error">{{ error }}</p>
      </article>
    </section>

    <template v-if="result">
      <div class="state-banner surface">
        <span class="eyebrow">Results for ZIP {{ zipInput }}</span>
        <h2>{{ stateName(result.state) }} · {{ result.state }}</h2>
      </div>

      <section class="overview-grid">
        <article class="surface">
          <div class="section-title">
            <h2>Senators</h2>
            <span class="result-count">{{ result.senators.length }} members</span>
          </div>

          <div v-if="!result.senators.length" class="empty-note">
            No senator data found for {{ result.state }}.
          </div>

          <div v-else class="member-list">
            <NuxtLink
              v-for="senator in result.senators"
              :key="senator.bioguide_id"
              :to="`/members/${senator.bioguide_id}`"
              class="member-card"
            >
              <div class="member-card__main">
                <span class="member-card__name">{{ senator.name }}</span>
                <span class="member-card__party" :style="{ color: partyColor(senator.party) }">
                  {{ partyLabel(senator.party) }}
                </span>
              </div>
              <span class="member-card__arrow">→</span>
            </NuxtLink>
          </div>
        </article>

        <article class="surface">
          <div class="section-title">
            <h2>House Representatives</h2>
            <span class="result-count">{{ result.representatives.length }} members</span>
          </div>

          <div v-if="!result.representatives.length" class="empty-note">
            No representative data found for {{ result.state }}.
          </div>

          <div v-else class="member-list">
            <NuxtLink
              v-for="rep in result.representatives"
              :key="rep.bioguide_id"
              :to="`/members/${rep.bioguide_id}`"
              class="member-card"
            >
              <div class="member-card__main">
                <span class="member-card__name">{{ rep.name }}</span>
                <span class="member-card__party" :style="{ color: partyColor(rep.party) }">
                  {{ partyLabel(rep.party) }}
                </span>
              </div>
              <span class="member-card__arrow">→</span>
            </NuxtLink>
          </div>

          <p v-if="result.representatives.length > 1" class="district-note">
            ZIP codes can span multiple congressional districts. All representatives from
            {{ stateName(result.state) }} in the most recent Congress are shown above.
          </p>
        </article>
      </section>
    </template>
  </main>
</template>

<style scoped>
.hero-title {
  font-size: 1.6rem;
  margin: 0.5rem 0;
  font-weight: 700;
}

.hero-copy {
  color: var(--text-muted);
  line-height: 1.6;
  margin: 0.75rem 0 0;
}

.state-banner {
  margin-top: 1px;
  padding: 1rem 1.25rem;
}

.state-banner h2 {
  margin: 0.25rem 0 0;
  font-size: 1.1rem;
}

.result-count {
  font-size: 0.75rem;
  color: var(--text-muted);
}

.member-list {
  display: flex;
  flex-direction: column;
  gap: 1px;
  margin-top: 0.75rem;
}

.member-card {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.75rem 1rem;
  border: 1px solid var(--border-soft);
  background: var(--bg-panel-strong);
  transition: border-color 0.15s ease;
  cursor: pointer;
}

.member-card:hover {
  border-color: var(--border-warm);
  color: var(--text-main);
}

.member-card__main {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.member-card__name {
  font-weight: 600;
  font-size: 0.88rem;
}

.member-card__party {
  font-size: 0.75rem;
}

.member-card__arrow {
  color: var(--text-muted);
  font-size: 0.9rem;
}

.lookup-error {
  margin-top: 0.75rem;
  color: var(--accent-house);
  font-size: 0.82rem;
}

.district-note {
  margin-top: 1rem;
  font-size: 0.75rem;
  color: var(--text-muted);
  border-top: 1px solid var(--border-soft);
  padding-top: 0.75rem;
}

.empty-note {
  color: var(--text-muted);
  font-size: 0.82rem;
  padding: 0.5rem 0;
}

@media (max-width: 760px) {
  .hero-grid,
  .overview-grid {
    grid-template-columns: 1fr;
  }
}
</style>
