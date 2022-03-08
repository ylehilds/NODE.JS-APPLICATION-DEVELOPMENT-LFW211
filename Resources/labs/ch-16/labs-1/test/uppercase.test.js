'use strict'
const uppercase = require('../uppercase')
test('throw when output is not uppercase', async () => {
  expect(uppercase('lehi')).toStrictEqual('LEHI')
})

test('throw when inputs is not string', async () => {
  expect(() => uppercase(5)).toThrowError(
    Error('input must be a string')
  )
})