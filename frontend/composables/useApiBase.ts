declare global {
  interface Window {
    __CSEARCH_RUNTIME_CONFIG__?: {
      API_SERVER?: string
    }
  }
}

export function useApiBase() {
  const config = useRuntimeConfig()

  if (import.meta.client) {
    const runtimeApi = window.__CSEARCH_RUNTIME_CONFIG__?.API_SERVER
    if (runtimeApi) {
      return runtimeApi
    }
  }

  return config.public.API_SERVER
}
