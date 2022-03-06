'use strict'
const assert = require('assert')
const { EventEmitter } = require('events')

const ee = new EventEmitter()
// ee.on('tick', listener) // method 2 using deregister with timer
ee.once('tick', listener) // method 1 simplest

let count = 0
setInterval(() => {
  ee.emit('tick')
}, 100)

// setTimeout(() => {
//   ee.removeListener('tick', listener)
// }, 150) // method 2 using deregister with timer

function listener () {
  count++
  setTimeout(() => {
    assert.equal(count, 1)
    assert.equal(this, ee)
    console.log('passed!')
  }, 250)
}
