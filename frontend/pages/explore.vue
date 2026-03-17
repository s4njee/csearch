<script setup lang="ts">
import {
  API_FAMILIES,
  EXPLORE_GROUPS,
  EXPLORE_QUERY_DESCRIPTIONS,
} from '~/types/congress'
import type {
  ExploreListResponse,
  ExploreParameter,
  ExploreQuery,
  ExploreQueryResponse,
} from '~/types/congress'

const { listExploreQueries, runExploreQuery } = useCongressApi()

const queryHints: Record<string, string> = {
  'bill-search-example': 'Use phrases first, then narrow by bill type or congress to compare results across tracks.',
  'vote-search-example': 'Search procedural terms like cloture or confirmation to jump directly into vote clusters.',
  'missing-descriptive-fields': 'Useful after ingest or parser changes to spot rows that may need enrichment.',
  'party-line-crossovers': 'Great for finding members whose voting patterns diverge from party majorities.',
}

const selectedQueryId = ref('')
const parameterValues = reactive<Record<string, string>>({})
const loadingResults = ref(false)
const resultError = ref('')
const resultPayload = ref<ExploreQueryResponse | null>(null)

const queryListData = ref<ExploreListResponse | null>(null)
const queryListError = ref<Error | null>(null)
const loadingQueries = ref(true)

async function refreshQueries() {
  loadingQueries.value = true
  queryListError.value = null

  try {
    queryListData.value = await listExploreQueries()
  }
  catch (error: any) {
    queryListError.value = error instanceof Error ? error : new Error(error?.message || 'Failed to load query list.')
  }
  finally {
    loadingQueries.value = false
  }
}

await refreshQueries()

const queries = computed(() => queryListData.value?.queries ?? [])

const queryById = computed<Record<string, ExploreQuery>>(() => {
  return Object.fromEntries(queries.value.map(query => [query.id, query]))
})

const groupedQueries = computed(() => {
  const seen = new Set<string>()

  const grouped = EXPLORE_GROUPS.map((group) => {
    const items = group.queryIds
      .map(id => queryById.value[id])
      .filter((query): query is ExploreQuery => Boolean(query))

    items.forEach(query => seen.add(query.id))

    return {
      ...group,
      items,
    }
  }).filter(group => group.items.length > 0)

  const remaining = queries.value.filter(query => !seen.has(query.id))
  if (remaining.length) {
    grouped.push({
      key: 'other',
      title: 'Other queries',
      description: 'Additional exploratory views available from the API.',
      items: remaining,
    })
  }

  return grouped
})

const selectedQuery = computed(() => selectedQueryId.value ? queryById.value[selectedQueryId.value] || null : null)
const resultRows = computed(() => resultPayload.value?.results ?? [])
const resultColumns = computed(() => {
  const columns = new Set<string>()
  resultRows.value.forEach(row => Object.keys(row).forEach(column => columns.add(column)))
  return Array.from(columns)
})

function initializeParameters(query: ExploreQuery | null) {
  Object.keys(parameterValues).forEach((key) => {
    delete parameterValues[key]
  })

  query?.parameters.forEach((parameter: ExploreParameter) => {
    parameterValues[parameter.name] = parameter.default === null ? '' : String(parameter.default)
  })
}

async function loadQueryResult() {
  if (!selectedQuery.value) {
    return
  }

  loadingResults.value = true
  resultError.value = ''

  try {
    const params = Object.fromEntries(
      selectedQuery.value.parameters
        .map(parameter => [parameter.name, parameterValues[parameter.name]])
        .filter(([, value]) => value !== undefined && value !== null && value !== ''),
    )

    resultPayload.value = await runExploreQuery(selectedQuery.value.id, params)
  }
  catch (error: any) {
    resultPayload.value = null
    resultError.value = error?.data?.message || error?.message || 'Failed to load results.'
  }
  finally {
    loadingResults.value = false
  }
}

function formatValue(value: unknown) {
  if (value === null || value === undefined || value === '') {
    return '—'
  }

  return typeof value === 'object' ? JSON.stringify(value) : String(value)
}

watch(queries, (value) => {
  if (!value.length) {
    return
  }

  if (!selectedQueryId.value || !queryById.value[selectedQueryId.value]) {
    selectedQueryId.value = value[0].id
  }
}, { immediate: true })

watch(selectedQuery, async (query) => {
  initializeParameters(query)
  resultPayload.value = null
  resultError.value = ''

  if (query) {
    await loadQueryResult()
  }
}, { immediate: true })
</script>

<template>
  <main class="page page--wide">
    <section class="surface">
      <div class="toolbar">
        <div>
          <p class="eyebrow">Explore catalog</p>
          <h1>Run every bundled exploratory query from `congress_api`.</h1>
          <p class="lede">
            The Nuxt app now uses `/explore` as a live catalog and `/explore/:queryId` as a dynamic execution surface,
            so new query pack additions show up here without another frontend redesign.
          </p>
        </div>

        <div class="stat-grid stat-grid--compact">
          <article class="stat-card">
            <div class="stat-card__value">{{ queries.length }}</div>
            <div class="stat-card__label">Queries</div>
          </article>
          <article class="stat-card">
            <div class="stat-card__value">{{ API_FAMILIES.length }}</div>
            <div class="stat-card__label">API families</div>
          </article>
        </div>
      </div>
    </section>

    <section v-if="queryListError" class="surface surface--error">
      <p>Couldn’t load explore queries.</p>
      <p>{{ queryListError.message }}</p>
      <button class="button" type="button" @click="refreshQueries">Try again</button>
    </section>

    <section v-else-if="loadingQueries" class="surface">
      Loading available exploration views...
    </section>

    <section v-else class="explore-layout">
      <aside class="surface">
        <div class="section-title">
          <h2>Query catalog</h2>
          <p>Grouped around the current explore pack themes.</p>
        </div>

        <div class="catalog-group" v-for="group in groupedQueries" :key="group.key">
          <div class="catalog-group__header">
            <h3>{{ group.title }}</h3>
            <span>{{ group.items.length }}</span>
          </div>
          <p class="catalog-group__copy">{{ group.description }}</p>

          <button
            v-for="query in group.items"
            :key="query.id"
            type="button"
            class="catalog-button"
            :class="{ 'catalog-button--active': selectedQueryId === query.id }"
            @click="selectedQueryId = query.id"
          >
            <div class="catalog-button__meta">Query {{ query.number }}</div>
            <div class="catalog-button__title">{{ query.title }}</div>
            <div class="catalog-button__copy">
              {{ EXPLORE_QUERY_DESCRIPTIONS[query.id] || 'Explore a different slice of the Congress dataset.' }}
            </div>
          </button>
        </div>
      </aside>

      <section v-if="selectedQuery" class="explore-content">
        <article class="surface">
          <div class="toolbar">
            <div>
              <p class="eyebrow">Selected query {{ selectedQuery.number }}</p>
              <h2>{{ selectedQuery.title }}</h2>
              <p class="lede">{{ EXPLORE_QUERY_DESCRIPTIONS[selectedQuery.id] || 'Explore a curated query from the API bundle.' }}</p>
              <p v-if="queryHints[selectedQuery.id]" class="callout">
                {{ queryHints[selectedQuery.id] }}
              </p>
            </div>

            <button class="button button--primary" type="button" :disabled="loadingResults" @click="loadQueryResult">
              {{ loadingResults ? 'Running...' : 'Run query' }}
            </button>
          </div>
        </article>

        <div class="explore-detail-grid">
          <article class="surface">
            <div class="section-title">
              <h3>Parameters</h3>
              <p>{{ selectedQuery.parameters.length ? 'Adjust the request before execution.' : 'This query does not require parameters.' }}</p>
            </div>

            <div v-if="selectedQuery.parameters.length" class="control-stack">
              <label v-for="parameter in selectedQuery.parameters" :key="parameter.name" class="field">
                <span>{{ parameter.name }}</span>
                <input
                  v-model="parameterValues[parameter.name]"
                  :type="parameter.type === 'integer' ? 'number' : 'text'"
                  :min="parameter.min"
                  :max="parameter.max"
                  class="field-input"
                  :placeholder="parameter.default === null ? 'Optional' : String(parameter.default)"
                >
              </label>
            </div>
            <p v-else class="empty-note">No parameters needed for this query.</p>
          </article>

          <article class="surface">
            <div class="section-title">
              <h3>Execution</h3>
              <p>The backend returns the SQL and bindings actually used for the request.</p>
            </div>

            <div class="code-block">
              <strong>Bindings</strong>
              <pre>{{ JSON.stringify(resultPayload?.bindings ?? [], null, 2) }}</pre>
            </div>

            <div class="code-block">
              <strong>SQL</strong>
              <pre>{{ resultPayload?.sql ?? 'No SQL yet.' }}</pre>
            </div>
          </article>
        </div>

        <article class="surface">
          <div class="toolbar">
            <div>
              <h3>Results</h3>
              <p class="lede">Rows come directly from the selected explore query.</p>
            </div>
            <div class="badge">{{ resultRows.length }} rows</div>
          </div>

          <div v-if="resultError" class="error-copy">{{ resultError }}</div>
          <div v-else-if="loadingResults" class="empty-note">Running query and loading results...</div>
          <div v-else-if="!resultRows.length" class="empty-note">No rows came back for this parameter set.</div>
          <div v-else class="table-wrap">
            <table class="results-table">
              <thead>
                <tr>
                  <th v-for="column in resultColumns" :key="column">{{ column }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(row, rowIndex) in resultRows" :key="`${selectedQuery.id}-${rowIndex}`">
                  <td v-for="column in resultColumns" :key="`${rowIndex}-${column}`">
                    {{ formatValue(row[column]) }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </article>
      </section>
    </section>
  </main>
</template>
