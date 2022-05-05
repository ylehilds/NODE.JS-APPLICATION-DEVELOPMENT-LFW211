const store = require('../store')

test('input rejection', async () => {
  const storeCode = 'test'
  await expect(store(storeCode))
    .rejects
    .toThrow('input must be a buffer')
})

test('data id needs to be 4 in length and input is a buffer', async () => {
  const storeId = {id: 1234}
  const storeCode = Buffer.from(storeId.toString())
  expect(Buffer.isBuffer(storeCode)).toBeTruthy()
  const myStore = await store(storeCode)
  expect(myStore.id.length).toBe(4)
  expect(myStore.id.length).not.toBe(5)
})