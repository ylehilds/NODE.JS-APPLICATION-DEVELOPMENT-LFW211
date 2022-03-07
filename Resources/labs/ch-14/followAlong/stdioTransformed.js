'use strict'
console.log(process.stdin.isTTY ? 'terminal' : 'piped to')

const { Transform } = require('stream')
const createUppercaseStream = () => {
  return new Transform({
    transform (chunk, enc, next) {
      const uppercased = chunk.toString().toUpperCase()
      next(null, uppercased)
    }
  })
}

const uppercase = createUppercaseStream()

process.stdin.pipe(uppercase).pipe(process.stdout)