'use strict'
const os = require('os')

setInterval(() => {
  console.log('system uptime', os.uptime())
  console.log('freemem', os.freemem())
  console.log('totalmem', os.totalmem())
  console.log()
}, 1000)