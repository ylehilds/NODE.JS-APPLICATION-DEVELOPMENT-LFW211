'use strict'
const { readFile } = require('fs')
readFile(__filename, {encoding: 'utf8'}, (err, contents) => {
  if (err) {
    console.error(err)
    return
  }
  console.log(contents)
})