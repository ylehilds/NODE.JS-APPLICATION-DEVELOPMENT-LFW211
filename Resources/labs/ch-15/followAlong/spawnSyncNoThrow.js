'use strict'
const { spawnSync } = require('child_process')
const result = spawnSync(process.execPath, [`-e`, `process.exit(1)`])
console.log(result)