const { EventEmitter } = require('events')
const ee = new EventEmitter()
ee.on('my-event', () => { console.log('1st') })
ee.on('my-event', () => { console.log('2nd') })
ee.emit('my-event')