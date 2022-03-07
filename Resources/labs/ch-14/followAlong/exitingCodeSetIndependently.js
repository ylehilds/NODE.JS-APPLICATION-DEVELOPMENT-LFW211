'use strict'
setInterval(() => {
  console.log('this interval is keeping the process open')
  process.exitCode = 1
}, 500)
setTimeout(() => {
  console.log('exit after this')
  process.exit()
}, 1750)

// then on terminal type: echo $?
// output: should be 1

