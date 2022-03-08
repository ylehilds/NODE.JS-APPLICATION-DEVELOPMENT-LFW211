'use strict'
const { execSync } = require('child_process')
const output = execSync(
  `"${process.execPath}" -e "console.error('subprocess stdio output')"`
)
console.log(output.toString())