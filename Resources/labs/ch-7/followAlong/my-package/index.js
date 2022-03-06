import { realpath } from 'fs/promises'
import { fileURLToPath } from 'url'
import * as format from './format.js'

const isMain = process.argv[1] && await realpath(fileURLToPath(import.meta.url)) === await realpath(process.argv[1])

if (isMain) {
  const { default: pino } = await import('pino')
  const logger = pino()
  logger.info(format.upper('my-package started'))
  process.stdin.resume()
}

export default (str) => {
  return format.upper(str).split('').reverse().join('')
}