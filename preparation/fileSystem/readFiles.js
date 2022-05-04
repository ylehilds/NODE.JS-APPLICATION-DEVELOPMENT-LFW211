'use strict'
const fs = require('fs')
const path = require('path')

const files = fs.readdirSync(__dirname)
for (let file of files) {
  try {
    console.log(path.resolve(file))
  } catch (err) {
    console.error(err)
  }
}
