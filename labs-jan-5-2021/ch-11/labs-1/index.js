'use strict'
const assert = require('assert')
const buffer = Buffer.allocUnsafe(1024)

for (const byte of buffer) assert.equal(byte, buffer[0])
console.log('passed!')

