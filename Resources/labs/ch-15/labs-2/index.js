'use strict'

const { spawn } = require('child_process')

function exercise (command, args) {
  return spawn(command, args, {
    stdio: [ 'ignore', 'inherit', 'pipe'] // As with the output property in execSync error objects or spawnSync result objects, the stdio array indices correspond to the file descriptors of each STDIO device. So the first element in the stdio array (index 0) is the setting for the child process STDIN, the second element (index 1) is for STDOUT and the third (index 2) is for STDERR.
  })
}

module.exports = exercise