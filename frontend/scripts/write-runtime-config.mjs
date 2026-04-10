import { mkdir, writeFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'

const apiServer = process.env.NUXT_API_SERVER || 'https://api.csearch.org'
const runtimeConfigPath = resolve(process.cwd(), 'public/runtime-config.js')
const runtimeConfig = `window.__CSEARCH_RUNTIME_CONFIG__ = {
  API_SERVER: ${JSON.stringify(apiServer)}
};
`

await mkdir(dirname(runtimeConfigPath), { recursive: true })
await writeFile(runtimeConfigPath, `${runtimeConfig}\n`)
