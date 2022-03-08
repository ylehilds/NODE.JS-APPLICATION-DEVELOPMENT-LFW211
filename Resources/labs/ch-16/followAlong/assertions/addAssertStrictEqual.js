const assert = require('assert')
const add = require('./add')
assert.strictEqual(add(2, 2), 4)

// const assert = require('assert') // same outcome, this way is exposing a strict object
// const add = require('./add')
// assert.strict.equal(add(2, 2), 4)