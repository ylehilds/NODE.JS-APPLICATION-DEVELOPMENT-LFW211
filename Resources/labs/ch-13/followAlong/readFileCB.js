'use strict'
const { join } = require('path')
const { readFile, writeFile } = require('fs')
readFile(__filename, {encoding: 'utf8'}, (err, contents) => {
  if (err) {
    console.error(err)
    return
  }
  const out = join(__dirname, 'out.txt')
  writeFile(out, contents.toUpperCase(), (err) => {
    if (err) { console.error(err) }
  })
})