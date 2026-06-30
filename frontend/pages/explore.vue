<script setup lang="ts">
import {
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

const CHART_QUERIES = [
  { id: 'active-committees-recent', label: 'Active committees — past 2 months' },
  { id: 'closest-votes-recent', label: 'Closest votes — past 2 months' },
] as const

type ChartState = { rows: Array<Record<string, unknown>>, loading: boolean }
const chartData = reactive<Record<string, ChartState>>(
  Object.fromEntries(CHART_QUERIES.map(cq => [cq.id, { rows: [], loading: true }])),
)

async function loadChartData() {
  await Promise.all(
    CHART_QUERIES.map(async ({ id }) => {
      try {
        const payload = await runExploreQuery(id, {})
        chartData[id].rows = payload.results as Array<Record<string, unknown>>
      }
      catch {
        // silently fail — charts are supplementary
      }
      finally {
        chartData[id].loading = false
      }
    }),
  )
}

onMounted(() => {
  loadChartData()
})

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

usePageSeo({
  title: 'Explore',
  description: 'Run bundled exploratory queries and charts over U.S. Congress legislative data.',
})
</script>

<template>
  <UContainer class="space-y-8">
    <UCard>
      <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <p class="text-xs font-medium uppercase tracking-[0.2em] text-primary">Explore catalog</p>
          <h1 class="mt-2 text-2xl font-semibold tracking-tight text-highlighted sm:text-3xl">Run bundled exploratory queries</h1>
          <p class="mt-1 max-w-2xl text-muted">
            A live catalog of every query in the API's explore pack, executed on demand against the dataset.
          </p>
        </div>

        <UCard :ui="{ body: 'p-4 sm:p-4' }" class="shrink-0">
          <div class="text-[0.7rem] uppercase tracking-[0.1em] text-muted">Queries</div>
          <div class="mt-1 text-2xl font-light text-highlighted">{{ queries.length }}</div>
        </UCard>
      </div>
    </UCard>

    <UCard>
      <template #header>
        <div>
          <p class="text-xs uppercase tracking-[0.15em] text-primary">Dataset snapshots</p>
          <h2 class="mt-1 text-lg font-medium text-highlighted">Charts</h2>
        </div>
      </template>
      <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <div v-for="cq in CHART_QUERIES" :key="cq.id">
          <p class="mb-2 text-xs uppercase tracking-[0.1em] text-muted">{{ cq.label }}</p>
          <ExploreChart :query-id="cq.id" :rows="chartData[cq.id].rows" :loading="chartData[cq.id].loading" />
        </div>
      </div>
    </UCard>

    <UCard v-if="queryListError" class="border-error/40">
      <p class="text-error">Couldn’t load explore queries.</p>
      <p class="mt-1 text-sm text-muted">{{ queryListError.message }}</p>
      <UButton class="mt-3" color="neutral" variant="outline" @click="refreshQueries">Try again</UButton>
    </UCard>

    <UCard v-else-if="loadingQueries">
      <p class="text-muted">Loading available exploration views…</p>
    </UCard>

    <div v-else class="grid grid-cols-1 gap-6 lg:grid-cols-[320px_minmax(0,1fr)]">
      <UCard class="self-start">
        <template #header>
          <div>
            <h2 class="text-lg font-medium text-highlighted">Query catalog</h2>
            <p class="mt-0.5 text-sm text-muted">Grouped around the current explore pack themes.</p>
          </div>
        </template>

        <div class="space-y-6">
          <div v-for="group in groupedQueries" :key="group.key">
            <div class="flex items-center justify-between gap-2">
              <h3 class="text-sm font-semibold text-highlighted">{{ group.title }}</h3>
              <span class="text-xs text-muted">{{ group.items.length }}</span>
            </div>
            <p class="mt-1 text-xs text-muted">{{ group.description }}</p>

            <div class="mt-3 flex flex-col gap-2">
              <button
                v-for="query in group.items"
                :key="query.id"
                type="button"
                class="border p-3 text-left transition-colors"
                :class="selectedQueryId === query.id ? 'border-primary bg-elevated' : 'border-default hover:border-primary/60'"
                @click="selectedQueryId = query.id"
              >
                <div class="text-[0.65rem] uppercase tracking-[0.1em] text-dimmed">Query {{ query.number }}</div>
                <div class="mt-0.5 text-sm font-medium text-highlighted">{{ query.title }}</div>
                <div class="mt-1 text-xs text-muted">
                  {{ EXPLORE_QUERY_DESCRIPTIONS[query.id] || 'Explore a different slice of the Congress dataset.' }}
                </div>
              </button>
            </div>
          </div>
        </div>
      </UCard>

      <div v-if="selectedQuery" class="space-y-6">
        <UCard>
          <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
            <div>
              <p class="text-xs uppercase tracking-[0.15em] text-primary">Selected query {{ selectedQuery.number }}</p>
              <h2 class="mt-1 text-xl font-medium text-highlighted">{{ selectedQuery.title }}</h2>
              <p class="mt-1 text-muted">{{ EXPLORE_QUERY_DESCRIPTIONS[selectedQuery.id] || 'Explore a curated query from the API bundle.' }}</p>
              <p v-if="queryHints[selectedQuery.id]" class="mt-2 text-sm text-primary">{{ queryHints[selectedQuery.id] }}</p>
            </div>
            <UButton color="primary" variant="subtle" :loading="loadingResults" :disabled="loadingResults" @click="loadQueryResult">
              {{ loadingResults ? 'Running…' : 'Run query' }}
            </UButton>
          </div>
        </UCard>

        <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <UCard>
            <template #header>
              <div>
                <h3 class="font-medium text-highlighted">Parameters</h3>
                <p class="mt-0.5 text-sm text-muted">{{ selectedQuery.parameters.length ? 'Adjust the request before execution.' : 'This query does not require parameters.' }}</p>
              </div>
            </template>

            <div v-if="selectedQuery.parameters.length" class="flex flex-col gap-4">
              <UFormField v-for="parameter in selectedQuery.parameters" :key="parameter.name" :label="parameter.name">
                <UInput
                  v-model="parameterValues[parameter.name]"
                  :type="parameter.type === 'integer' ? 'number' : 'text'"
                  :min="parameter.min"
                  :max="parameter.max"
                  :placeholder="parameter.default === null ? 'Optional' : String(parameter.default)"
                  class="w-full"
                />
              </UFormField>
            </div>
            <p v-else class="text-muted">No parameters needed for this query.</p>
          </UCard>

          <UCard>
            <template #header>
              <div>
                <h3 class="font-medium text-highlighted">Execution</h3>
                <p class="mt-0.5 text-sm text-muted">The backend returns the SQL and bindings actually used.</p>
              </div>
            </template>

            <div class="space-y-4">
              <div>
                <strong class="text-xs uppercase tracking-[0.1em] text-dimmed">Bindings</strong>
                <pre class="mt-2 overflow-auto border border-default bg-black/40 p-3 text-xs text-muted">{{ JSON.stringify(resultPayload?.bindings ?? [], null, 2) }}</pre>
              </div>
              <div>
                <strong class="text-xs uppercase tracking-[0.1em] text-dimmed">SQL</strong>
                <pre class="mt-2 overflow-auto whitespace-pre-wrap border border-default bg-black/40 p-3 text-xs text-muted">{{ resultPayload?.sql ?? 'No SQL yet.' }}</pre>
              </div>
            </div>
          </UCard>
        </div>

        <UCard>
          <template #header>
            <div class="flex items-center justify-between gap-4">
              <div>
                <h3 class="font-medium text-highlighted">Results</h3>
                <p class="mt-0.5 text-sm text-muted">Rows come directly from the selected explore query.</p>
              </div>
              <UBadge color="neutral" variant="subtle">{{ resultRows.length }} rows</UBadge>
            </div>
          </template>

          <p v-if="resultError" class="text-error">{{ resultError }}</p>
          <p v-else-if="loadingResults" class="text-muted">Running query and loading results…</p>
          <p v-else-if="!resultRows.length" class="text-muted">No rows came back for this parameter set.</p>
          <div v-else class="overflow-auto border border-default">
            <table class="w-full border-collapse text-sm">
              <thead>
                <tr>
                  <th
                    v-for="column in resultColumns"
                    :key="column"
                    class="sticky top-0 border-b border-default bg-elevated px-3 py-2 text-left text-xs uppercase tracking-[0.1em] text-dimmed"
                  >
                    {{ column }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(row, rowIndex) in resultRows" :key="`${selectedQuery.id}-${rowIndex}`">
                  <td v-for="column in resultColumns" :key="`${rowIndex}-${column}`" class="border-b border-default px-3 py-2 align-top">
                    {{ formatValue(row[column]) }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </UCard>
      </div>
    </div>
  </UContainer>
</template>
