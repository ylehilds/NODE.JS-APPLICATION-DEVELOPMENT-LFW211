import { pathToFileURL } from 'url'
import { createRequire } from 'module'

const require = createRequire(import.meta.url)

console.log(
  `import 'pino'`,
  '=>',
  pathToFileURL(require.resolve('pino')).toString()
)

console.log(
  `import 'tap'`,
  '=>',
  pathToFileURL(require.resolve('tap')).toString()
)