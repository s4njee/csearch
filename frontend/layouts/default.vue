<script setup lang="ts">
import type { NavigationMenuItem } from '@nuxt/ui'

const route = useRoute()

// Primary navigation. No "Overview" entry — the landing page is gone and `/`
// redirects to the bills list. `active` is matched by route prefix so detail
// pages (e.g. /bills/hr/119/9387) keep their section highlighted.
const navItems = computed<NavigationMenuItem[]>(() => [
  { label: 'Bills', to: '/bills/hr', active: route.path.startsWith('/bills') },
  { label: 'Votes', to: { path: '/votes', query: { chamber: 'senate' } }, active: route.path.startsWith('/votes') },
  { label: 'Committees', to: '/committees', active: route.path.startsWith('/committees') },
  { label: 'Explore', to: '/explore', active: route.path.startsWith('/explore') },
  { label: 'Representatives', to: '/representatives', active: route.path.startsWith('/representatives') },
])

const { formatDate } = useFormatters()
const { getFreshness } = useCongressApi()

function newestDateish(...values: Array<string | null | undefined>) {
  const parsed = values
    .filter((value): value is string => Boolean(value))
    .map(value => ({ value, time: Date.parse(value) }))
    .filter(item => Number.isFinite(item.time))
    .sort((a, b) => b.time - a.time)

  return parsed[0]?.value ?? null
}

const { data: freshness } = useAsyncData(
  'api-freshness',
  () => getFreshness(),
  { server: false, lazy: true },
)
// Prefer when the refresh pipeline last ran (advances daily even when no new
// bills/votes landed), so the footer reflects "we checked today" rather than
// the date of the newest content. Falls back to content dates when the ops
// schema is unavailable (e.g. local/partial DBs return no last_refreshed_at).
const updatedAt = computed(() =>
  freshness.value?.last_refreshed_at
  ?? newestDateish(
    freshness.value?.last_bill_update_at,
    freshness.value?.last_vote_at,
  ),
)
</script>

<template>
  <div class="min-h-screen flex flex-col">
    <a
      href="#main"
      class="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-[100] focus:bg-elevated focus:px-4 focus:py-2 focus:text-primary focus:ring focus:ring-primary"
    >
      Skip to content
    </a>

    <header class="sticky top-0 z-50 border-b border-default bg-default/80 backdrop-blur">
      <UContainer class="flex flex-wrap items-center justify-between gap-x-6 gap-y-3 py-4">
        <NuxtLink to="/bills/hr" class="flex items-center gap-3" aria-label="CSearch home">
          <span class="grid size-9 place-items-center border border-primary text-xs font-bold uppercase text-primary">
            CS
          </span>
          <span class="flex flex-col leading-tight">
            <strong class="text-xs uppercase tracking-[0.2em] text-highlighted">CSearch</strong>
            <small class="text-[0.7rem] text-muted">Congress API console</small>
          </span>
        </NuxtLink>

        <UNavigationMenu
          :items="navItems"
          variant="link"
          class="-mx-2"
          :ui="{ list: 'flex-wrap' }"
          aria-label="Primary"
        />
      </UContainer>
    </header>

    <main id="main" class="flex-1 py-8 sm:py-10">
      <slot />
    </main>

    <footer class="mt-12 border-t border-default">
      <UContainer class="flex flex-col gap-2 py-6 text-xs text-muted sm:flex-row sm:items-center sm:justify-between">
        <span>CSearch · U.S. Congress data explorer</span>
        <span v-if="updatedAt">Data updated {{ formatDate(updatedAt) }}</span>
      </UContainer>
    </footer>
  </div>
</template>
