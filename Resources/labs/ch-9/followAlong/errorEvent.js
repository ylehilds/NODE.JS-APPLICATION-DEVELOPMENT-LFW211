const { EventEmitter } = require('events')
const ee = new EventEmitter()

process.stdin.resume() // keep process alive

ee.on('error', (err) => {
  console.log('got error:', err.message )
})

ee.emit('error', new Error('oh oh'))

