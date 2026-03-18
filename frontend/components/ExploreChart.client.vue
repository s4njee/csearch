<script setup lang="ts">
import Plotly from 'plotly.js-dist-min'

const props = defineProps<{
  queryId: string
  rows: Array<Record<string, unknown>>
  loading: boolean
}>()

const chartEl = ref<HTMLDivElement | null>(null)
const router = useRouter()
const isVoteChart = computed(() => props.queryId === 'closest-votes' || props.queryId === 'closest-votes-recent')
const isCommitteeChart = computed(() => props.queryId === 'active-committees' || props.queryId === 'active-committees-recent')

const PARTY_COLOR: Record<string, string> = {
  D: '#4f8ef7',
  R: '#e05252',
}

const BASE_XAXIS = {
  gridcolor: 'rgba(79,142,247,0.1)',
  zerolinecolor: 'rgba(79,142,247,0.2)',
  tickfont: { size: 10, color: '#aab9d2' },
  color: '#aab9d2',
}

const BASE_YAXIS = {
  gridcolor: 'rgba(79,142,247,0.08)',
  tickfont: { size: 10, color: '#aab9d2' },
  color: '#aab9d2',
}

function buildChart(): { data: Plotly.Data[], layout: Partial<Plotly.Layout> } | null {
  const { rows, queryId } = props
  if (!rows.length) return null

  const baseLayout: Partial<Plotly.Layout> = {
    paper_bgcolor: 'transparent',
    plot_bgcolor: 'transparent',
    font: { color: '#aab9d2', family: 'Inter, "Helvetica Neue", Arial, sans-serif', size: 11 },
    xaxis: BASE_XAXIS,
    yaxis: BASE_YAXIS,
  }

  if (queryId === 'top-subject-areas') {
    const top = rows.slice(0, 15).reverse()
    return {
      data: [{
        type: 'bar',
        orientation: 'h',
        x: top.map(r => Number(r.bill_count)),
        y: top.map(r => String(r.subject || '—')),
        marker: { color: '#4f8ef7' },
        hovertemplate: '%{y}: <b>%{x}</b> bills<extra></extra>',
      }],
      layout: {
        ...baseLayout,
        margin: { t: 8, r: 16, b: 32, l: 188 },
        xaxis: { ...BASE_XAXIS, title: { text: 'Bills', font: { size: 10, color: '#aab9d2' } } },
      },
    }
  }

  if (queryId === 'active-committees' || queryId === 'active-committees-recent') {
    const top = rows.slice(0, 15).reverse()
    return {
      data: [{
        type: 'bar',
        orientation: 'h',
        x: top.map(r => Number(r.bill_count)),
        y: top.map(r => {
          const name = String(r.committee_name || '—')
          const truncated = name.length > 28 ? `${name.slice(0, 28)}…` : name
          return `${truncated} [${r.committee_code}]`
        }),
        marker: { color: '#4f8ef7' },
        hovertemplate: '%{y}: <b>%{x}</b> bills<extra></extra>',
      }],
      layout: {
        ...baseLayout,
        margin: { t: 8, r: 40, b: 32, l: 220 },
        xaxis: { ...BASE_XAXIS, title: { text: 'Bills', font: { size: 10, color: '#aab9d2' } } },
      },
    }
  }

  if (queryId === 'closest-votes' || queryId === 'closest-votes-recent') {
    const top = rows.slice(0, 15).reverse()
    const labels = top.map(r => {
      const q = String(r.question || '—')
      const truncated = q.length > 32 ? `${q.slice(0, 32)}…` : q
      return `${truncated} [${r.voteid}]`
    })
    return {
      data: [
        {
          type: 'bar',
          orientation: 'h',
          name: 'Yea',
          x: top.map(r => Number(r.yea_count)),
          y: labels,
          marker: { color: '#4ade80' },
          hovertemplate: 'Yea: <b>%{x}</b><extra></extra>',
        },
        {
          type: 'bar',
          orientation: 'h',
          name: 'Nay',
          x: top.map(r => Number(r.nay_count)),
          y: labels,
          marker: { color: '#e05252' },
          hovertemplate: 'Nay: <b>%{x}</b><extra></extra>',
        },
      ],
      layout: {
        ...baseLayout,
        margin: { t: 24, r: 16, b: 32, l: 240 },
        barmode: 'stack' as const,
        showlegend: true,
        legend: {
          font: { color: '#dde4f0', size: 10 },
          bgcolor: 'transparent',
          orientation: 'h' as const,
          y: 1.1,
          x: 0,
        },
        xaxis: { ...BASE_XAXIS, title: { text: 'Votes', font: { size: 10, color: '#aab9d2' } } },
      },
    }
  }

  if (queryId === 'most-prolific-sponsors') {
    const top = rows.slice(0, 20)
    const labels = top.map(r => {
      const name = String(r.sponsor_name || '—')
      return name.split(',')[0]?.trim() ?? name
    })
    return {
      data: [{
        type: 'bar',
        x: labels,
        y: top.map(r => Number(r.bill_count)),
        marker: {
          color: top.map(r => PARTY_COLOR[String(r.sponsor_party || '')] ?? '#4f8ef7'),
        },
        hovertemplate: '%{x}: <b>%{y}</b> bills<extra></extra>',
      }],
      layout: {
        ...baseLayout,
        margin: { t: 8, r: 16, b: 96, l: 40 },
        xaxis: { ...BASE_XAXIS, tickangle: -40, tickfont: { size: 9, color: '#4f8ef7' } },
        yaxis: { ...BASE_YAXIS, title: { text: 'Bills', font: { size: 10, color: '#aab9d2' } } },
      },
    }
  }

  return null
}

async function renderChart() {
  if (!chartEl.value) return
  const chart = buildChart()
  if (!chart) return
  await Plotly.react(chartEl.value, chart.data, chart.layout, {
    responsive: true,
    displayModeBar: false,
  })

  if (isCommitteeChart.value) {
    chartEl.value.on('plotly_click', (data: any) => {
      const label = String(data.points[0]?.y ?? '')
      const match = /\[([^\]]+)\]/.exec(label)
      if (match) router.push(`/committees/${match[1]}`)
    })

    chartEl.value.querySelectorAll('.ytick').forEach((tick) => {
      const el = tick as SVGElement
      el.style.cursor = 'pointer'
      el.addEventListener('click', () => {
        const label = el.querySelector('text')?.textContent ?? ''
        const match = /\[([^\]]+)\]/.exec(label)
        if (match) router.push(`/committees/${match[1]}`)
      })
    })
  }

  if (isVoteChart.value) {
    chartEl.value.on('plotly_click', (data: any) => {
      const label = String(data.points[0]?.y ?? '')
      const match = /\[([^\]]+)\]$/.exec(label)
      if (match) router.push(`/votes/${match[1]}`)
    })

    chartEl.value.querySelectorAll('.ytick').forEach((tick) => {
      const el = tick as SVGElement
      el.style.cursor = 'pointer'
      el.addEventListener('click', () => {
        const label = el.querySelector('text')?.textContent ?? ''
        const match = /\[([^\]]+)\]/.exec(label)
        if (match) router.push(`/votes/${match[1]}`)
      })
    })
  }
}

watch(() => [props.rows, props.loading], async () => {
  if (!props.loading) {
    await nextTick()
    renderChart()
  }
}, { deep: true })

onMounted(() => {
  if (!props.loading) renderChart()
})

onUnmounted(() => {
  if (chartEl.value) Plotly.purge(chartEl.value)
})
</script>

<template>
  <div v-if="loading" class="chart-placeholder">Loading…</div>
  <div v-else-if="!rows.length" class="chart-placeholder">No data</div>
  <div v-else ref="chartEl" class="explore-chart" :class="{ 'explore-chart--clickable': isVoteChart || isCommitteeChart }" />
</template>

<style scoped>
.explore-chart {
  width: 100%;
  height: 310px;
}

.explore-chart--clickable :deep(.nsewdrag),
.explore-chart--clickable :deep(.ytick text) {
  cursor: pointer !important;
}

.chart-placeholder {
  height: 310px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-muted);
  font-size: 0.82rem;
}
</style>
