<script setup lang="ts">
import type { NuxtError } from '#app'

const props = defineProps<{ error: NuxtError }>()

const isNotFound = computed(() => props.error?.statusCode === 404)
const heading = computed(() => (isNotFound.value ? 'Page not found' : 'Something went wrong'))
const detail = computed(() =>
  isNotFound.value
    ? 'That page doesn’t exist or may have moved.'
    : props.error?.message || 'An unexpected error occurred.',
)

useSeoMeta({ title: () => heading.value })

function handleClear() {
  clearError({ redirect: '/bills/hr' })
}
</script>

<template>
  <UApp>
    <NuxtLayout>
      <UContainer class="flex min-h-[60vh] flex-col items-center justify-center text-center">
        <p class="text-xs font-medium uppercase tracking-[0.2em] text-primary">
          Error {{ error?.statusCode || 500 }}
        </p>
        <h1 class="mt-3 text-3xl font-semibold tracking-tight text-highlighted sm:text-4xl">
          {{ heading }}
        </h1>
        <p class="mt-3 max-w-md text-muted">{{ detail }}</p>
        <UButton class="mt-8" color="primary" variant="subtle" size="lg" @click="handleClear">
          Back to bills
        </UButton>
      </UContainer>
    </NuxtLayout>
  </UApp>
</template>
