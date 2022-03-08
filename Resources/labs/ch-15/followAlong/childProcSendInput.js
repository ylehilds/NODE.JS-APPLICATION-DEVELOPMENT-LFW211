'use strict'
const { spawnSync } = require('child_process')

spawnSync(
  process.execPath,
  [
    '-e',
    `console.error('err output'); process.stdin.pipe(process.stdout)`
  ],
  {
    input: 'this input will become output\n',
    stdio: ['pipe', 'inherit', 'ignore']
  }
)