const assert = require('assert')
const pseudoReq = (url, cb) => {
  setTimeout(() => {
    if (url === 'ht‌tp://error.com') cb(Error('network error'))
    else cb(null, Buffer.from('some data'))
  }, 300)
}

pseudoReq('ht‌tp://example.com', (err, data) => {
  assert.ifError(err)
})

pseudoReq('ht‌tp://error.com', (err, data) => {
  assert.deepStrictEqual(err, Error('network error'))
})