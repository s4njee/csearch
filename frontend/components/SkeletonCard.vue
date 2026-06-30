<script setup lang="ts">
// Generic loading placeholder mirroring the result-card layout (meta line,
// title, summary, detail grid). Used in place of plain "Loading…" text.
withDefaults(defineProps<{ rows?: number }>(), { rows: 4 })
</script>

<template>
  <UCard>
    <div class="space-y-4">
      <div class="space-y-2">
        <USkeleton class="h-3 w-1/3" />
        <USkeleton class="h-6 w-3/4" />
      </div>
      <div class="space-y-2">
        <USkeleton class="h-4 w-full" />
        <USkeleton class="h-4 w-5/6" />
      </div>
      <div class="grid grid-cols-2 gap-x-6 gap-y-3">
        <div v-for="n in rows" :key="n" class="space-y-1">
          <USkeleton class="h-3 w-1/2" />
          <USkeleton class="h-4 w-2/3" />
        </div>
      </div>
    </div>
  </UCard>
</template>
