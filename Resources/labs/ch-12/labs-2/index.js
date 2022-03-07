'use strict'
const { Readable, Writable, Transform, PassThrough, pipeline } = require('stream')
const assert = require('assert')
const createWritable = () => {
  const sink = []
  const writable = new Writable({
    write(chunk, enc, cb) {
      sink.push(chunk.toString())
      cb()
    }
  })
  writable.sink = sink
  return writable
}
const readable = Readable.from(['a', 'b', 'c'])
const writable = createWritable()

// TODO: replace the pass through stream 
// with a transform stream that uppercases
// incoming characters

const createTransformStream = () => { // method 1
  return new Transform({
    decodeStrings: false,
    transform (chunk, enc, next) {
      next(null, chunk.toUpperCase())
    }
  })
}

const transform = createTransformStream()

// const transform = new Transform({ // method 1.5
//   decodeStrings: false,
//   transform (chunk, enc, next) {
//     next(null, chunk.toUpperCase());
//   }
// })

// const transform = new Transform({ // method 2
//   decodeStrings: false
// })
// transform._transform = function(chunk, encoding, done) {
//   done(null, chunk.toUpperCase());
// };
pipeline(readable, transform, writable, (err) => {
  assert.ifError(err)
  assert.deepStrictEqual(writable.sink, ['A', 'B', 'C'])
  console.log('passed!')
})