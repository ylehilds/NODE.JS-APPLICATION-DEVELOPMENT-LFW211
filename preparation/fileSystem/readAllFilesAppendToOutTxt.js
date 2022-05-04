'use strict'
const fs = require('fs')
const path = require('path')

const files = fs.readdirSync(__dirname)
fs.writeFileSync(path.join(__dirname, 'out.txt'), '')
for (let file of files) {
  try {
    console.log(path.resolve(file))
    if (fs.statSync(path.resolve(file)).isFile()) {
      const contents = fs.readFileSync(path.resolve(file))
      fs.writeFileSync(path.join(__dirname, 'out.txt'), contents, {flag: "a"})
    }
  } catch (err) {
    console.error(err)
  }
}
