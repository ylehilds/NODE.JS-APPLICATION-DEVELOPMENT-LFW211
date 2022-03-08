const assert = require('assert')
const { promisify } = require('util')
const timeout = promisify(setTimeout)
const pseudoReq = async (url) => {
  await timeout(300)
  if (url === 'ht‌tp://error.com') throw Error('network error')
  return Buffer.from('some data')
}
assert.doesNotReject(pseudoReq('ht‌tp://example.com'))
assert.rejects(pseudoReq('ht‌tp://error.com'), Error('network error'))