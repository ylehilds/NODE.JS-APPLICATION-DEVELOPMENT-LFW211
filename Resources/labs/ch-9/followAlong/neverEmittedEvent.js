import someEventEmitter from './somewhere.js'
import { once } from 'events'

await once(someEventEmitter, 'my-event')