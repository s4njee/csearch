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
  {
    server: false,
    watch: [zip],
  },
)

const senators = computed<RepresentativeRecord[]>(() => data.value?.senators ?? [])
const houseMembers = computed<RepresentativeRecord[]>(() => {
  const response = data.value as any
  return response?.representatives ?? response?.housemembers ?? []
})

const notFound = computed(() => !pending.value && zip.value && !senators.value.length && !houseMembers.value.length)

const { partyLabel, partyColor } = useFormatters()

usePageSeo({
  title: () => (zip.value ? `Representatives for ${zip.value}` : 'Representatives'),
  description: 'Find your U.S. senators and House representative by ZIP code.',
})
</script>

<template>
  <UContainer class="space-y-8">
    <UCard>
      <div class="space-y-5">
        <div>
          <p class="text-xs font-medium uppercase tracking-[0.2em] text-primary">Representatives</p>
          <h1 class="mt-2 text-2xl font-semibold tracking-tight text-highlighted sm:text-3xl">Who represents you?</h1>
          <p class="mt-1 text-muted">{{ zip ? `Showing results for ZIP ${zip}` : 'Enter a ZIP code to find your congressional representatives.' }}</p>
        </div>

        <form class="flex max-w-md flex-col gap-3 sm:flex-row sm:items-end" action="/representatives" method="get">
          <UFormField label="ZIP code" class="flex-1">
            <UInput
              name="zip"
              inputmode="numeric"
              autocomplete="postal-code"
              pattern="[0-9]{5}"
              maxlength="5"
              placeholder="90210"
              :default-value="zip"
              class="w-full"
            />
          </UFormField>
          <UButton type="submit" color="primary" variant="subtle" size="lg" class="justify-center">Find reps</UButton>
        </form>
      </div>
    </UCard>

    <div v-if="pending" class="grid grid-cols-1 gap-6 lg:grid-cols-2">
      <SkeletonCard v-for="n in 2" :key="n" :rows="2" />
    </div>

    <UAlert
      v-else-if="error"
      color="error"
      variant="subtle"
      icon="i-lucide-circle-alert"
      :description="(error as any)?.data?.error ?? 'Something went wrong. Please try again.'"
    />

    <UCard v-else-if="notFound">
      <p class="text-muted">No representatives found for ZIP {{ zip }}. Try a different ZIP code.</p>
    </UCard>

    <div v-else-if="zip && data" class="grid grid-cols-1 gap-6 lg:grid-cols-2">
      <UCard>
        <template #header>
          <h2 class="text-lg font-medium text-highlighted">Senators</h2>
        </template>
        <p v-if="!senators.length" class="text-muted">No senators found.</p>
        <ul v-else class="flex flex-col gap-3">
          <li v-for="rep in senators" :key="rep.bioguide_id" class="border border-default p-4">
            <NuxtLink :to="`/members/${rep.bioguide_id}`" class="font-medium text-highlighted transition-colors hover:text-primary">{{ rep.name }}</NuxtLink>
            <div class="mt-1 flex items-center gap-3 text-sm">
              <span class="font-medium" :style="{ color: partyColor(rep.party) }">{{ partyLabel(rep.party) }}</span>
              <span class="text-muted">{{ rep.state }}</span>
            </div>
          </li>
        </ul>
      </UCard>

      <UCard>
        <template #header>
          <h2 class="text-lg font-medium text-highlighted">House Members</h2>
        </template>
        <p v-if="!houseMembers.length" class="text-muted">No house members found.</p>
        <ul v-else class="flex flex-col gap-3">
          <li v-for="rep in houseMembers" :key="rep.bioguide_id" class="border border-default p-4">
            <NuxtLink :to="`/members/${rep.bioguide_id}`" class="font-medium text-highlighted transition-colors hover:text-primary">{{ rep.name }}</NuxtLink>
            <div class="mt-1 flex items-center gap-3 text-sm">
              <span class="font-medium" :style="{ color: partyColor(rep.party) }">{{ partyLabel(rep.party) }}</span>
              <span class="text-muted">{{ rep.state }}</span>
            </div>
          </li>
        </ul>
      </UCard>
    </div>

    <UCard v-else>
      <p class="text-muted">District matches will appear here.</p>
    </UCard>
  </UContainer>
</template>
