<script setup lang="ts">
import Plotly from 'plotly.js-dist-min'
import type { VoteMember } from '~/types/congress'

const props = defineProps<{
  members: VoteMember[]
}>()

const chartEl = ref<HTMLDivElement | null>(null)

const POSITIONS = [
  { key: 'yea', label: 'Yea' },
  { key: 'nay', label: 'Nay' },
  { key: 'present', label: 'Present' },
  { key: 'notvoting', label: 'Not Voting' },
]

const PARTIES = [
  { key: 'D', label: 'Democrat', color: '#4f8ef7' },
  { key: 'R', label: 'Republican', color: '#e05252' },
  { key: 'I', label: 'Independent', color: '#aab9d2' },
]

function normalizePosition(pos: string): string {
  const p = pos.toLowerCase()
  if (p === 'aye') return 'yea'
  if (p === 'no') return 'nay'
  return p
}

function buildChart() {
  const counts: Record<string, Record<string, number>> = {}
  for (const party of PARTIES) counts[party.key] = {}
  for (const pos of POSITIONS) {
    for (const party of PARTIES) counts[party.key][pos.key] = 0
  }

  for (const member of props.members) {
    const pos = normalizePosition(member.position)
    const party = String(member.party || '').toUpperCase()
    const partyKey = PARTIES.find(p => p.key === party) ? party : 'I'
    if (counts[partyKey][pos] !== undefined) {
      counts[partyKey][pos]++
    }
  }

  const positionLabels = POSITIONS.map(p => p.label)

  const data: Plotly.Data[] = PARTIES.map(party => ({
    type: 'bar',
    name: party.label,
    x: positionLabels,
    y: POSITIONS.map(pos => counts[party.key][pos.key]),
    marker: { color: party.color },
    hovertemplate: `${party.label} %{x}: <b>%{y}</b><extra></extra>`,
  }))

  const layout: Partial<Plotly.Layout> = {
    paper_bgcolor: 'transparent',
    plot_bgcolor: 'transparent',
    font: { color: '#aab9d2', family: 'Inter, "Helvetica Neue", Arial, sans-serif', size: 11 },
    barmode: 'group',
    bargap: 0.2,
    bargroupgap: 0.05,
    margin: { t: 8, r: 16, b: 40, l: 40 },
    xaxis: {
      gridcolor: 'rgba(79,142,247,0.1)',
      tickfont: { size: 11, color: '#aab9d2' },
      color: '#aab9d2',
    },
    yaxis: {
      gridcolor: 'rgba(79,142,247,0.08)',
      tickfont: { size: 10, color: '#aab9d2' },
      color: '#aab9d2',
      rangemode: 'tozero' as const,
    },
    legend: {
      font: { color: '#aab9d2', size: 10 },
      bgcolor: 'transparent',
      orientation: 'h' as const,
      x: 0,
      y: 1.12,
    },
    showlegend: true,
  }

  return { data, layout }
}

async function renderChart() {
  if (!chartEl.value) return
  const { data, layout } = buildChart()
  await Plotly.react(chartEl.value, data, layout, {
    responsive: true,
    displayModeBar: false,
  })
}

watch(() => props.members, async () => {
  await nextTick()
  renderChart()
}, { deep: true })

onMounted(() => renderChart())
onUnmounted(() => { if (chartEl.value) Plotly.purge(chartEl.value) })
</script>

<template>
  <div ref="chartEl" class="vote-breakdown-chart" />
</template>

<style scoped>
.vote-breakdown-chart {
  width: 100%;
  height: 260px;
}
</style>
