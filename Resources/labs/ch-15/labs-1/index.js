'use strict'

const childProc = require('child_process')

function exercise (myEnvVar) {
  // TODO return a child process with
  // a single environment variable set 
  // named MY_ENV_VAR. The MY_ENV_VAR 
  // environment variable's value should 
  // be the value of the myEnvVar parameter 
  // passed to this exercise function
  return childProc.spawnSync(process.argv[0], ['child.js'], {
    env: {MY_ENV_VAR: myEnvVar}
  })
}

module.exports = exercise
