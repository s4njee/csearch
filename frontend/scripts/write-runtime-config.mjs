import { mkdir, writeFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'

const apiServer = process.env.NUXT_API_SERVER || 'https://api.csearch.org'
const runtimeConfigPath = resolve(process.cwd(), 'public/runtime-config.js')
const metaPath = resolve(process.cwd(), 'public/meta.json')

const runtimeConfig = `window.__CSEARCH_RUNTIME_CONFIG__ = {
  API_SERVER: ${JSON.stringify(apiServer)}
};
`

await mkdir(dirname(runtimeConfigPath), { recursive: true })
await writeFile(runtimeConfigPath, `${runtimeConfig}\n`)
await writeFile(metaPath, JSON.stringify({ updatedAt: new Date().toISOString() }, null, 2) + '\n')
