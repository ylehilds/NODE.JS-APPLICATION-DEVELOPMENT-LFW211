'use strict'
const { promisify } = require('util')
const timeout = promisify(setTimeout)
module.exports = async (url) => {
  await timeout(300)
  if (url === 'ht‌tp://error.com') throw Error('network error')
  return Buffer.from('some data')
}