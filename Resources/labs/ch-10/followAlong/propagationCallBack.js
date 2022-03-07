class OddError extends Error {
  constructor (varName = '') {
    super(varName + ' must be even')
    this.code = 'ERR_MUST_BE_EVEN'
  }
  get name () {
    return 'OddError [' + this.code + ']'
  }
}

function codify (err, code) {
  err.code = code
  return err
}

function doTask (amount, cb) {
  if (typeof amount !== 'number') {
    cb(codify(
      new TypeError('amount must be a number'),
      'ERR_AMOUNT_MUST_BE_NUMBER'
    ))
    return
  }
  if (amount <= 0) {
    cb(codify(
      new RangeError('amount must be greater than zero'),
      'ERR_AMOUNT_MUST_EXCEED_ZERO'
    ))
    return
  }
  if (amount % 2) {
    cb(new OddError('amount'))
    return
  }
  cb(Error('some other error'))
  return
  cb(null, amount/2)
}

function run (cb) {
  doTask(4, (err, result) => {
    if (err) {
      if (err.code === 'ERR_AMOUNT_MUST_BE_NUMBER') {
        cb(Error('wrong type'))
      } else if (err.code === 'ERRO_AMOUNT_MUST_EXCEED_ZERO') {
        cb(Error('out of range'))
      } else if (err.code === 'ERR_MUST_BE_EVEN') {
        cb(Error('cannot be odd'))
      } else {
        cb(err)
      }
      return
    }

    console.log('result', result)
  })
}

run((err) => {
  if (err) console.error('Error caught', err)
})