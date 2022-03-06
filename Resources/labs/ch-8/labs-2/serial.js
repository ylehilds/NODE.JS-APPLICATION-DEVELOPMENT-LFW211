'use strict'
const { promisify } = require('util')

const print = (err, contents) => { 
  if (err) console.error(err)
  else console.log(contents) 
}

const opA = async (cb) => {
  await new Promise((resolve) => setTimeout(resolve, 500))
    cb(null, 'A')
}

const opB = async (cb) => {
  await new Promise((resolve) => setTimeout(resolve, 250))
    cb(null, 'B')
}

const opC = async (cb) => {
  await new Promise((resolve) => setTimeout(resolve, 125))
    cb(null, 'C')
}

async function run () {
  await opA(print)
  await opB(print)
  await opC(print)
}

run()

