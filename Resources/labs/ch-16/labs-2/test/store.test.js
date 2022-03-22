const store = require('../store')

test('throw if value is not a buffer',() => {
  const storeCode = 'Im not a buffer'
  store(storeCode, (err, data) => {
    expect(err != null).toBeTruthy()
    expect(data == null).toBeTruthy()
  })
})

test('data id has 4 numbers & storeCode is a buffer',() => {
  const storeCode = Buffer.from('2775736520737472696374270a6d6f64756c652e6578706f727473203d202876616c75652c20636229203d3e207b0a2020696620284275666665722e69734275666665722876616c756529203d3d3d2066616c736529207b0a202020206362284572726f722827696e707574206d7573742062652061206275666665722729290a2020202072657475726e0a20207d0a202073657454696d656f7574282829203d3e207b0a20202020636f6e7374206964203d204d6174682e72616e646f6d28292e746f537472696e67283336292e73706c697428272e27295b315d2e736c69636528302c2034290a202020206362286e756c6c2c207b206964207d290a20207d2c20333030290a7d0a', 'hex')
  store(storeCode, (err, data) => {
    expect(err == null).toBeTruthy()
    expect(data != null).toBeTruthy()
    expect(Buffer.isBuffer(storeCode)).toBeTruthy()
    expect(data.id.length).toBe(4)
  })
})
