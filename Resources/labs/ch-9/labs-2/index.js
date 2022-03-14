'use strict'
const { EventEmitter } = require('events')
process.nextTick(console.log, 'passed!')
const ee = new EventEmitter()

ee.on('error', (err) => {
  // handle the error here, by adding a handler it stopped from crashing
  // console.log(err)
})

ee.emit('error', Error('timeout')) // Emitting an 'error' event on an event emitter will cause the event emitter to throw an exception if a listener for the 'error' event has not been registered

