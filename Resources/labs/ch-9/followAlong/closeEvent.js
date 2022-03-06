const { EventEmitter } = require('events')

const ee = new EventEmitter()
ee.on('close', () => { console.log('close event fired!') })
ee.emit('close')