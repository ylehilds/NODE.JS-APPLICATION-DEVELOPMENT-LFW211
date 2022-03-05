'use strict'
const fs = require('fs')
const assert = require('assert')

async function read (file) {
  const content = await fs.promises.readFile(file)
  return content
}


async function check () {
  await assert.rejects(
    read('not-a-valid-filepath'), 
    new Error('failed to read')
  )
  assert.deepEqual(
    await read(__filename),
    fs.readFileSync(__filename)
  )
  console.log('passed!')
}

check()
