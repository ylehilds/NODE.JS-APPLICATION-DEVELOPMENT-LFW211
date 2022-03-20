'use strict'
const { promisify } = require('util')

const print = (err, contents) => {
  if (err) console.error(err)
  else console.log(contents)
}

const opA = (cb) => {
  setTimeout(() => {
    cb(null, 'A')
  }, 500)
}

const opB = (cb) => {
  setTimeout(() => {
    cb(null, 'B')
  }, 250)
}

const opC = (cb) => {
  setTimeout(() => {
    cb(null, 'C')
  }, 125)
}

// solution 1

const pOpA = promisify(opA) // Takes a function following the common error-first callback style, i.e. taking a (err, value) => ... callback as the last argument, and returns a version that returns promises.
const pOpB = promisify(opB) // because all of these promises return ('null', <A/B/C>) returns no errors "null", then the data gets returned automatically and assigns it to pOpA/pOpB/pOpC
const pOpC = promisify(opC)

const operate = async () => {
  print(null, await pOpA())
  print(null, await pOpB())
  print(null, await pOpC())
}

operate()

// --------------------------------------------------------------------------------------------------------------------

// solution 2

// const printHelper = (contents) => print(null, contents)
//
// const pOpA = promisify(opA)
// const pOpB = promisify(opB)
// const pOpC = promisify(opC)
// pOpA()
//   .then(printHelper)
//   .then(() => pOpB())
//   .then(printHelper)
//   .then(() => pOpC())
//   .then(printHelper)
//
