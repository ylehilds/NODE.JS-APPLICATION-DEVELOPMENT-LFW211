'use strict'
const { exec } = require('child_process')

exec(
  `"${process.execPath}" -e "console.log('A'); throw Error('B')"`,
  (err, stdout, stderr) => {
    console.log('err', err)
    console.log('subprocess stdout: ', stdout.toString())
    console.log('subprocess stderr: ', stderr.toString())
  }
)