'use strict'
const { EventEmitter } = require('events')
process.nextTick(console.log, 'passed!')
const ee = new EventEmitter()

ee.on('error', (err) => {
  // handle the error here, by adding a handler it stopped from crashing
  // console.log(err)
})

ee.emit('error', Error('timeout'))
