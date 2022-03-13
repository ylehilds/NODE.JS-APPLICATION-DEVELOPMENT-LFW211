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

const pOpA = promisify(opA)
const pOpB = promisify(opB)
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
