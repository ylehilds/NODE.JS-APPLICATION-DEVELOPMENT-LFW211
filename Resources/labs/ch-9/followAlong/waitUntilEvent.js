import { once, EventEmitter } from 'events'
import { setTimeout } from 'timers'

const uneventful = new EventEmitter()

const ac = new AbortController()
const { signal } = ac

// setTimeout(() => {},500).then(() => ac.abort())

const delay = t => new Promise(resolve => setTimeout(resolve, t))
delay(1).then(() => ac.abort())

try {
  run()
  console.log('pinged!')
} catch (err) {
  // ignore abort errors:
  if (err.code !== 'ABORT_ERR') throw err
  console.log('canceled')
}
async function run() {
  await once(uneventful, 'ping', { signal })
}

