'use strict'
const os = require('os')

console.log('Hostname', os.hostname())
console.log('Home dir', os.homedir())
console.log('Temp dir', os.tmpdir())

console.log('platform', os.platform())
console.log('type', os.type())