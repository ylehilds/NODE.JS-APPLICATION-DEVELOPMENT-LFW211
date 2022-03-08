const expect = require('expect')
const add = require('./add')

expect(add(2, 2)).toStrictEqual(4)
expect(add(2, 2)).toBe(4)