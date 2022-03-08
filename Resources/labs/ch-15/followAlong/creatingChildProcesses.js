'use strict'
const { execSync } = require('child_process')
const output = execSync(
  `node -e "console.log('subprocess stdio output')"`
)
console.log(output.toString())