'use strict'
console.log('Process Uptime', process.uptime())
setTimeout(() => {
  console.log('Process Uptime', process.uptime())
}, 1000)

// terminal command: node -p process.env