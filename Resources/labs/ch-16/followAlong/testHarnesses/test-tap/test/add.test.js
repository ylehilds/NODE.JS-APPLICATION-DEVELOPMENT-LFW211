const { test } = require('tap')
const add = require('../add')

test('throw when inputs are not numbers', async ({ throws }) => {
  throws(() => add('5', '5'), Error('inputs must be numbers'))
  throws(() => add(5, '5'), Error('inputs must be numbers'))
  throws(() => add('5', 5), Error('inputs must be numbers'))
  throws(() => add({}, null), Error('inputs must be numbers'))
})

test('adds two numbers', async ({ equal }) => {
  equal(add(5, 5), 10)
  equal(add(-5, 5), 0)
})