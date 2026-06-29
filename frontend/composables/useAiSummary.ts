export function useAiSummary() {
  const config = useRuntimeConfig()

  const summary = ref('')
  const loading = ref(false)
  const error = ref('')

  async function fetchSummary(billtype: string, congress: string, billnumber: string) {
    loading.value = true
    error.value = ''
    summary.value = ''

    try {
      const baseUrl = config.public.AI_SUMMARY_URL as string
      if (!baseUrl) {
        throw new Error('AI summary service is not configured.')
      }

      const data = await $fetch<{ bill: string, summary: string, cached: boolean }>(
        `${baseUrl}/summarize/${billtype}/${congress}/${billnumber}`,
      )

      summary.value = data.summary
    }
    catch (err: any) {
      error.value = err?.data?.error || err?.message || 'Unable to load AI summary.'
    }
    finally {
      loading.value = false
    }
  }

  return { summary, loading, error, fetchSummary }
}
