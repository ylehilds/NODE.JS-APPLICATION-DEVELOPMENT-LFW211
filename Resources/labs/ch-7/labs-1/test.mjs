import { createRequire } from 'module'
import assert from 'assert'
const { resolve } = createRequire(import.meta.url)
const { default: add } = await import(resolve('.'))

assert(typeof add === 'function', 'function exported')

assert(add(15, 7) + add(11, 9) === 42, 'correct function exported')

console.log('passed!')