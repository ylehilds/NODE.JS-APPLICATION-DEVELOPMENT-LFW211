const store = require('../store')

test('data id has 4 numbers & storeCode is a buffer', () => {
  const storeId = {id: '1234'}
  const storeCode = Buffer.from(storeId.toString())
  store(storeCode, (err, data) => {
    expect(data.id.length).toBe(4)
    expect(err == null).toBeTruthy()
    expect(data != null).toBeTruthy()
    expect(Buffer.isBuffer(storeCode)).toBeTruthy()
  })
})

test('input must be a buffer', () => {
  const storeCode = 'test'
  store(storeCode, (err, data) => {
    expect(err != null).toBeTruthy()
    expect(data == null).toBeTruthy()
  })
})
