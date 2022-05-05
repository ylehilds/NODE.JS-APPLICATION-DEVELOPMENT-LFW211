'use strict'
const uppercase = require('../uppercase')
test('throw when output is not uppercase', async () => {
  expect(uppercase('lehi')).toBe('LEHI')
})

test('throw when inputs is not string', async () => {
  expect(() => {
    uppercase(5)
  }).toThrow('input must be a string')
})